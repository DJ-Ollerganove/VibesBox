import Cocoa
import Foundation

/// Leichter lokaler Prozess-Watcher: startet die UI, wenn eine integrierte
/// DJ-Software läuft. Keep in sync mit windows/runner/dj_watchdog.cpp und
/// lib/dj_process_match.dart.
enum DjWatchdog {
  static let launchAgentLabel = "com.vibesbox.sync.djwatch"
  private static let pollInterval: TimeInterval = 2.5
  private static var timer: Timer?
  private static var watchdogMode = false

  static var isWatchArgumentPresent: Bool {
    ProcessInfo.processInfo.arguments.contains { arg in
      let lower = arg.lowercased()
      return lower == "--dj-watch" || lower == "-dj-watch"
    }
  }

  static var isWatchdogMode: Bool { watchdogMode || isWatchArgumentPresent }

  /// Aufruf früh (AppDelegate / awakeFromNib): Accessory-App ohne Dock-Icon.
  static func enterWatchdogModeIfNeeded() {
    guard isWatchArgumentPresent else { return }
    guard !watchdogMode else { return }
    watchdogMode = true
    NSApp.setActivationPolicy(.accessory)
  }

  static func startPollingIfNeeded() {
    guard isWatchArgumentPresent else { return }
    enterWatchdogModeIfNeeded()
    for window in NSApp.windows {
      window.orderOut(nil)
    }
    startPolling()
  }

  static func startPolling() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { _ in
      tick()
    }
    RunLoop.main.add(timer!, forMode: .common)
    tick()
  }

  static func stopPolling() {
    timer?.invalidate()
    timer = nil
  }

  private static func tick() {
    if !isAutostartEnabled() {
      if watchdogMode {
        NSApp.terminate(nil)
      } else {
        stopPolling()
      }
      return
    }
    guard anyIntegratedDjRunning() else { return }
    guard !isUiAlreadyRunning() else { return }
    launchUi()
  }

  static func anyIntegratedDjRunning() -> Bool {
    NSWorkspace.shared.runningApplications.contains { app in
      isIntegratedDjName(app.localizedName ?? "")
        || isIntegratedDjName(app.bundleIdentifier ?? "")
    }
  }

  /// Keep in sync with lib/dj_process_match.dart
  static func isIntegratedDjName(_ raw: String) -> Bool {
    let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if lower.isEmpty { return false }
    if lower.contains("vibesbox") { return false }
    if lower.contains("rekordbox") && !lower.contains("agent") { return true }
    if lower.contains("serato") { return true }
    if lower.contains("mixxx") { return true }
    if lower.contains("traktor") { return true }
    if lower.contains("virtualdj") || lower.contains("virtual dj") || lower.contains("atomix") {
      return true
    }
    if lower.contains("djay") { return true }
    if lower.contains("enginedj") || lower.contains("engine dj") || lower.contains("engine prime") {
      return true
    }
    if lower == "engine" || lower == "engine.exe" { return true }
    return false
  }

  private static func isUiAlreadyRunning() -> Bool {
    let selfPid = ProcessInfo.processInfo.processIdentifier
    let selfBundle = Bundle.main.bundleIdentifier
    return NSWorkspace.shared.runningApplications.contains { app in
      if app.processIdentifier == selfPid { return false }
      if let bid = app.bundleIdentifier, let selfBundle, bid == selfBundle {
        // Watchdog = .accessory; UI = .regular.
        return app.activationPolicy == .regular
      }
      let name = (app.localizedName ?? "").lowercased()
      return name.contains("vibesbox sync") || name.contains("vibesboxsync")
    }
  }

  private static func launchUi() {
    let url = Bundle.main.bundleURL
    let config = NSWorkspace.OpenConfiguration()
    config.activates = true
    config.createsNewApplicationInstance = true
    // Ohne --dj-watch → normale UI.
    config.arguments = []
    NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in }
  }

  // MARK: - LaunchAgent

  static func launchAgentPlistURL() -> URL {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return home
      .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
      .appendingPathComponent("\(launchAgentLabel).plist")
  }

  static func isAutostartEnabled() -> Bool {
    FileManager.default.fileExists(atPath: launchAgentPlistURL().path)
  }

  @discardableResult
  static func setAutostartEnabled(_ enabled: Bool) -> Bool {
    if enabled {
      return installLaunchAgent()
    }
    return uninstallLaunchAgent()
  }

  private static func appExecutablePath() -> String? {
    Bundle.main.executableURL?.path
  }

  private static func installLaunchAgent() -> Bool {
    guard let exe = appExecutablePath() else { return false }
    let agents = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    try? FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)

    let plist: [String: Any] = [
      "Label": launchAgentLabel,
      "ProgramArguments": [exe, "--dj-watch"],
      "RunAtLoad": true,
      "KeepAlive": false,
      "ProcessType": "Background",
    ]
    let url = launchAgentPlistURL()
    do {
      let data = try PropertyListSerialization.data(
        fromPropertyList: plist, format: .xml, options: 0)
      try data.write(to: url, options: .atomic)
    } catch {
      return false
    }

    // Alten Agent entladen, dann laden (best effort).
    _ = runLaunchctl(["unload", url.path])
    _ = runLaunchctl(["load", url.path])

    // Sofort Watcher in dieser Session starten, falls noch keiner läuft.
    if !watchdogMode && timer == nil {
      // Separaten Watcher-Prozess starten (gleicher Bundle + Flag).
      launchWatchdogProcess()
    }
    return true
  }

  private static func uninstallLaunchAgent() -> Bool {
    let url = launchAgentPlistURL()
    _ = runLaunchctl(["unload", url.path])
    try? FileManager.default.removeItem(at: url)
    stopPolling()
    return true
  }

  private static func launchWatchdogProcess() {
    guard let exe = appExecutablePath() else { return }
    let task = Process()
    task.executableURL = URL(fileURLWithPath: exe)
    task.arguments = ["--dj-watch"]
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    do {
      try task.run()
    } catch {
      // Ignore — LaunchAgent übernimmt beim nächsten Login.
    }
  }

  @discardableResult
  private static func runLaunchctl(_ args: [String]) -> Int32 {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    task.arguments = args
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    do {
      try task.run()
      task.waitUntilExit()
      return task.terminationStatus
    } catch {
      return -1
    }
  }
}
