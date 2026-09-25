//
//  ShazamKitChannel.swift
//  Runner
//
//  Native iOS-Gegenstück zu Android `shazam_channel`: Musikerkennung via ShazamKit (Mikrofon).
//  Ohne diese Datei liefert Flutter auf iOS keinen MethodChannel-Handler — Erkennung scheitert
//  immer, auch wenn `permission_handler` das Mikrofon meldet.
//

import AVFoundation
import Flutter
import Foundation
import os
import ShazamKit

private let shazamKitOsLog = Logger(subsystem: "com.vibesbox.dj", category: "ShazamKit")

// MARK: - EventChannel helpers

private final class RmsStreamHandler: NSObject, FlutterStreamHandler {
  weak var owner: ShazamKitChannel?

  init(owner: ShazamKitChannel) {
    self.owner = owner
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    owner?.rmsEventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    owner?.rmsEventSink = nil
    return nil
  }
}

private final class AutoAdjustStreamHandler: NSObject, FlutterStreamHandler {
  weak var owner: ShazamKitChannel?

  init(owner: ShazamKitChannel) {
    self.owner = owner
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    owner?.autoAdjustEventSink = events
    DispatchQueue.main.async {
      events(["status": "connected"])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    owner?.autoAdjustEventSink = nil
    return nil
  }
}

// MARK: - ShazamKit bridge

final class ShazamKitChannel: NSObject, SHSessionDelegate {
  static let shared = ShazamKitChannel()

  private let rmsNormalizationDivisor: Double = 2500.0
  private let scanDurationSeconds: TimeInterval = 8.0

  private let stateLock = NSLock()
  private var recognitionGeneration: UInt64 = 0

  private var audioEngine: AVAudioEngine?
  private var shSession: SHSession?
  private var pendingFlutterResult: FlutterResult?
  private var scanTimeoutWorkItem: DispatchWorkItem?
  private var matchFound = false

  var rmsEventSink: FlutterEventSink?
  var autoAdjustEventSink: FlutterEventSink?

  private var rmsHandler: RmsStreamHandler?
  private var autoAdjustHandler: AutoAdjustStreamHandler?

  private var micSensitivity: Double = 1.0
  private var manualThreshold: Double = 0.3
  private var recognitionThreshold: Double = 0.3
  private var smartThresholdEnabled: Bool = false

  private var lastRmsSentAt: CFAbsoluteTime = 0

  private override init() {
    super.init()
  }

  func register(binaryMessenger messenger: FlutterBinaryMessenger) {
    let method = FlutterMethodChannel(name: "shazam_channel", binaryMessenger: messenger)
    method.setMethodCallHandler { [weak self] call, result in
      self?.handleMethodCall(call, result: result)
    }

    rmsHandler = RmsStreamHandler(owner: self)
    FlutterEventChannel(name: "dj_og_app/rms_stream", binaryMessenger: messenger).setStreamHandler(
      rmsHandler)

    autoAdjustHandler = AutoAdjustStreamHandler(owner: self)
    FlutterEventChannel(name: "com.vibesbox.dj/auto_adjust", binaryMessenger: messenger)
      .setStreamHandler(autoAdjustHandler)
  }

  // MARK: Method channel

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "recognize":
      if let args = call.arguments as? [String: Any] {
        if let s = args["mic_sensitivity"] as? NSNumber {
          let v = s.doubleValue
          if v >= 0.5 && v <= 2.0 { micSensitivity = v }
        }
        if let st = args["smart_threshold_enabled"] as? Bool {
          smartThresholdEnabled = st
        }
        if let t = args["recognition_threshold"] as? NSNumber {
          let v = t.doubleValue
          if v >= 0.0 && v <= 1.0 {
            manualThreshold = v
            if !smartThresholdEnabled { recognitionThreshold = v }
          }
        }
      }
      DispatchQueue.main.async { [weak self] in
        self?.startRecognize(flutterResult: result)
      }

    case "setMicSensitivity":
      if let args = call.arguments as? [String: Any],
        let s = args["sensitivity"] as? NSNumber
      {
        let v = s.doubleValue
        if v >= 0.5 && v <= 2.0 { micSensitivity = v }
      }
      result(true)

    case "setSmartThresholdEnabled":
      if let args = call.arguments as? [String: Any],
        let enabled = args["enabled"] as? Bool
      {
        smartThresholdEnabled = enabled
        if !enabled { recognitionThreshold = manualThreshold }
      }
      result(nil)

    case "startScanning":
      // Android: Foreground Service. Auf iOS nicht nötig — immer „gestartet“.
      result(true)

    case "stopScanning", "stopCurrentScan":
      DispatchQueue.main.async { [weak self] in
        self?.stopRecognizeInternal(sendEmptyResult: false)
      }
      result(true)

    case "updateRecognitionNotification", "updateNotificationContent",
      "updateNotificationVisibility":
      result(true)

    case "consumePendingNavigationTarget":
      result(nil as String?)

    case "clearPendingNavigationTarget":
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Recognition (SHSession + AVAudioEngine)

  private func startRecognize(flutterResult: @escaping FlutterResult) {
    stateLock.lock()
    recognitionGeneration += 1
    let gen = recognitionGeneration
    stopRecognizeInternal(sendEmptyResult: false)
    pendingFlutterResult = flutterResult
    matchFound = false
    stateLock.unlock()

    // Mikrofon: Dialog nur bei .undetermined — bei .denied zeigt iOS keinen Dialog mehr.
    // NSMicrophoneUsageDescription muss in Runner/Info.plist (App-Target) stehen.
    let session = AVAudioSession.sharedInstance()
    switch session.recordPermission {
    case .denied:
      DispatchQueue.main.async { [weak self] in
        self?.finishRecognize(
          generation: gen,
          payload: [
            "title": "",
            "artist": "",
            "error": "PERMISSION_DENIED",
            "error_message":
              "Mikrofon-Berechtigung verweigert. Bitte unter Einstellungen → VibesBox → Mikrofon aktivieren.",
          ],
          clearSession: false,
        )
      }
    case .granted:
      DispatchQueue.main.async { [weak self] in
        self?.beginAudioEngineScan(generation: gen)
      }
    case .undetermined:
      session.requestRecordPermission { [weak self] granted in
        guard let self else { return }
        DispatchQueue.main.async {
          if !granted {
            self.finishRecognize(
              generation: gen,
              payload: [
                "title": "",
                "artist": "",
                "error": "PERMISSION_DENIED",
                "error_message":
                  "Mikrofon-Berechtigung verweigert. Bitte unter Einstellungen → VibesBox → Mikrofon aktivieren.",
              ],
              clearSession: false,
            )
            return
          }
          self.beginAudioEngineScan(generation: gen)
        }
      }
    @unknown default:
      session.requestRecordPermission { [weak self] granted in
        guard let self else { return }
        DispatchQueue.main.async {
          if granted {
            self.beginAudioEngineScan(generation: gen)
          } else {
            self.finishRecognize(
              generation: gen,
              payload: [
                "title": "",
                "artist": "",
                "error": "PERMISSION_DENIED",
                "error_message":
                  "Mikrofon-Berechtigung verweigert. Bitte unter Einstellungen → VibesBox → Mikrofon aktivieren.",
              ],
              clearSession: false,
            )
          }
        }
      }
    }
  }

  private func beginAudioEngineScan(generation: UInt64) {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
      try session.setActive(true, options: [])

      let engine = AVAudioEngine()
      let sh = SHSession()
      sh.delegate = self

      let input = engine.inputNode
      let hwFormat = input.outputFormat(forBus: 0)
      let bufferSize: AVAudioFrameCount = 2048

      input.installTap(onBus: 0, bufferSize: bufferSize, format: hwFormat) {
        [weak self, sh, generation] buffer, audioTime in
        guard let self else { return }
        self.stateLock.lock()
        let stillActive = self.recognitionGeneration == generation && !self.matchFound
        self.stateLock.unlock()
        guard stillActive else { return }

        let rms = self.rmsFromPCMBuffer(buffer)
        // Float-/Int16-PCM liefert hier RMS in ~0…1 (nicht wie Androids Short-RMS 0…32767).
        // Gleiche Formel wie Android: (shortSkaliert * sensitivity / 2500), damit die Pegelleiste reagiert.
        let int16Comparable = rms * 32768.0
        let normalized = (int16Comparable * self.micSensitivity / self.rmsNormalizationDivisor)
          .clamped(to: 0...1)
        self.sendRmsThrottled(normalized)

        do {
          try sh.matchStreamingBuffer(buffer, at: audioTime)
        } catch {
          // Ignorieren — Timeout beendet den Scan.
        }
      }

      engine.prepare()
      try engine.start()

      audioEngine = engine
      shSession = sh

      let work = DispatchWorkItem { [weak self, generation] in
        self?.finishRecognize(
          generation: generation,
          payload: ["title": "", "artist": ""],
          clearSession: true,
        )
      }
      scanTimeoutWorkItem = work
      DispatchQueue.main.asyncAfter(deadline: .now() + scanDurationSeconds, execute: work)
    } catch {
      finishRecognize(
        generation: generation,
        payload: ["title": "", "artist": ""],
        clearSession: false,
      )
    }
  }

  private func stopRecognizeInternal(sendEmptyResult: Bool) {
    scanTimeoutWorkItem?.cancel()
    scanTimeoutWorkItem = nil

    if let engine = audioEngine {
      engine.inputNode.removeTap(onBus: 0)
      engine.stop()
    }
    audioEngine = nil
    shSession?.delegate = nil
    shSession = nil

    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

    if sendEmptyResult {
      stateLock.lock()
      let fr = pendingFlutterResult
      pendingFlutterResult = nil
      stateLock.unlock()
      fr?(["title": "", "artist": ""])
    }
  }

  private func finishRecognize(
    generation: UInt64,
    payload: [String: Any],
    clearSession: Bool,
  ) {
    stateLock.lock()
    guard recognitionGeneration == generation else {
      stateLock.unlock()
      return
    }
    scanTimeoutWorkItem?.cancel()
    scanTimeoutWorkItem = nil
    let fr = pendingFlutterResult
    pendingFlutterResult = nil
    stateLock.unlock()

    if clearSession {
      stopRecognizeInternal(sendEmptyResult: false)
    }

    fr?(payload)
  }

  private func completeMatch(generation: UInt64, title: String, artist: String) {
    stateLock.lock()
    guard recognitionGeneration == generation, !matchFound else {
      stateLock.unlock()
      return
    }
    matchFound = true
    stateLock.unlock()

    scanTimeoutWorkItem?.cancel()
    scanTimeoutWorkItem = nil

    if let engine = audioEngine {
      engine.inputNode.removeTap(onBus: 0)
      engine.stop()
    }
    audioEngine = nil
    shSession?.delegate = nil
    shSession = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

    stateLock.lock()
    let fr = pendingFlutterResult
    pendingFlutterResult = nil
    stateLock.unlock()

    fr?(["title": title, "artist": artist])
  }

  // MARK: SHSessionDelegate

  func session(_ session: SHSession, didFind match: SHMatch) {
    let item = match.mediaItems.first
    let title = item?.title ?? ""
    let artist = item?.artist ?? ""
    stateLock.lock()
    let gen = recognitionGeneration
    stateLock.unlock()
    DispatchQueue.main.async { [weak self] in
      self?.completeMatch(generation: gen, title: title, artist: artist)
    }
  }

  func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
    // Während Streaming häufige Zwischenergebnisse — kein Abschluss hier; Timeout liefert leeres Ergebnis.
    guard let error else { return }
    let ns = error as NSError
    if ns.domain == "com.apple.ShazamKit" {
      shazamKitOsLog.error(
        "didNotFindMatch ShazamKit err=\(ns.localizedDescription, privacy: .public) code=\(ns.code)"
      )
    }
    // 202 = u. a. fehlende ShazamKit-Capability / nicht freigeschaltete App-ID.
    guard ns.domain == "com.apple.ShazamKit", ns.code == 202 else { return }
    stateLock.lock()
    let gen = recognitionGeneration
    stateLock.unlock()
    DispatchQueue.main.async { [weak self] in
      self?.finishRecognize(
        generation: gen,
        payload: [
          "title": "",
          "artist": "",
          "error": "INVALID_SIGNATURE",
          "error_message":
            "ShazamKit ist für diese App-ID nicht freigeschaltet (Apple Developer → App Services → ShazamKit).",
        ],
        clearSession: true,
      )
    }
  }

  // MARK: RMS

  private func sendRmsThrottled(_ value: Double) {
    let now = CFAbsoluteTimeGetCurrent()
    // ~8 Updates/s (statt 20) — weniger UI-Last auf Flutter-Seite.
    if now - lastRmsSentAt < 0.12 { return }
    lastRmsSentAt = now
    guard let sink = rmsEventSink else { return }
    DispatchQueue.main.async {
      sink(value)
    }
  }

  private func rmsFromPCMBuffer(_ buffer: AVAudioPCMBuffer) -> Double {
    let frames = Int(buffer.frameLength)
    if frames == 0 { return 0 }
    let channels = Int(buffer.format.channelCount)

    if let floatData = buffer.floatChannelData {
      var sum: Double = 0
      let ch0 = floatData[0]
      for i in 0..<frames {
        let s = Double(ch0[i])
        sum += s * s
      }
      return sqrt(sum / Double(frames * max(channels, 1)))
    }
    if let int16 = buffer.int16ChannelData {
      var sum: Double = 0
      let ch0 = int16[0]
      for i in 0..<frames {
        let s = Double(ch0[i]) / 32768.0
        sum += s * s
      }
      return sqrt(sum / Double(frames * max(channels, 1)))
    }
    return 0
  }
}

private extension Comparable {
  func clamped(to limits: ClosedRange<Self>) -> Self {
    min(max(self, limits.lowerBound), limits.upperBound)
  }
}
