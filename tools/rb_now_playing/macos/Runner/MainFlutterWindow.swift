import ApplicationServices
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let fileDrag = RekordboxFileDragController()
  private let tidal = TidalSessionController()
  private let libraryPath = LibraryPathPicker()
  private var windowChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.title = "VibesBox Sync"
    applyCompactChrome()

    RegisterGeneratedPlugins(registry: flutterViewController)
    fileDrag.attach(to: flutterViewController)
    tidal.attach(to: flutterViewController)
    libraryPath.attach(to: flutterViewController)
    let chrome = FlutterMethodChannel(
      name: "vibesbox_sync/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    chrome.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setAlwaysOnTop" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let on = (call.arguments as? Bool) ?? false
      self?.level = on ? .floating : .normal
      result(true)
    }
    windowChannel = chrome

    super.awakeFromNib()

    styleMask.insert(.fullSizeContentView)
    titlebarAppearsTransparent = true
    titleVisibility = .hidden
    if #available(macOS 11.0, *) {
      titlebarSeparatorStyle = .none
    }
    isMovableByWindowBackground = true
    isOpaque = false
    backgroundColor = NSColor(srgbRed: 0, green: 11.0 / 255.0, blue: 39.0 / 255.0, alpha: 1)
    if let content = contentView {
      content.wantsLayer = true
      content.layer?.cornerRadius = 16
      content.layer?.masksToBounds = true
    }
    setFrameAutosaveName("")
    isRestorable = false
    applyCompactChrome()
  }

  func applyCompactChrome() {
    minSize = NSSize(width: 280, height: 420)
    setContentSize(NSSize(width: 315, height: 500))
  }
}

/// Rekordbox/JUCE antwortet auf Drops mit `NSDragOperationGeneric`.
/// Nur `.copy` anzubieten ergibt Schnittmenge 0 — visuell zieht man,
/// der Player lädt nicht. Finder bietet `.every`, das tun wir auch.
///
/// Pulse DJ nutzt SwiftUI `.onDrag { NSItemProvider(contentsOf: fileURL) }`.
/// `beginDraggingSession` braucht ein **mouseDown**-Event, kein Dragged.
/// Das Pasteboard in `willBeginAt` anfassen zerstört die NSURL-Items.
final class RekordboxFileDragController: NSObject, NSDraggingSource {
  private weak var sourceView: NSView?
  private var hoverPath = ""
  private var hoverTitle = ""
  private var hoverArtist = ""
  private var hoverSoftware = "rekordbox"
  private var origin = NSPoint.zero
  private var started = false
  private var monitor: Any?
  private var mouseDownEvent: NSEvent?
  private var pressSerial = 0
  private var armSerial = 0

  func attach(to controller: FlutterViewController) {
    sourceView = controller.view
    let channel = FlutterMethodChannel(
      name: "vibesbox_sync/file_drag",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "arm":
        var path = ""
        var title = ""
        var artist = ""
        if let s = call.arguments as? String {
          path = s
        } else if let m = call.arguments as? [String: Any] {
          path = (m["path"] as? String) ?? ""
          title = (m["title"] as? String) ?? ""
          artist = (m["artist"] as? String) ?? ""
          self?.hoverSoftware = (m["software"] as? String) ?? "rekordbox"
        } else {
          result(false)
          return
        }
        result(self?.arm(path: path, title: title, artist: artist) ?? false)
      case "cancel":
        self?.disarm()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    if monitor == nil {
      monitor = NSEvent.addLocalMonitorForEvents(
        matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
      ) { [weak self] event in
        self?.handle(event)
        return event
      }
    }
  }

  @discardableResult
  private func arm(path: String, title: String, artist: String) -> Bool {
    hoverTitle = title
    hoverArtist = artist
    if hoverSoftware.isEmpty { hoverSoftware = "rekordbox" }
    if path.lowercased().hasPrefix("tidal:tracks:") {
      RekordboxCollectionLoad.promptAccessibilityIfNeeded()
      hoverPath = path
      armSerial = pressSerial
      origin = NSEvent.mouseLocation
      started = false
      maybeStartDrag()
      return true
    }
    guard FileManager.default.isReadableFile(atPath: path) else {
      NSLog("VibesBox Sync drag: Datei nicht lesbar: \(path)")
      return false
    }
    hoverPath = path
    armSerial = pressSerial
    origin = NSEvent.mouseLocation
    started = false
    maybeStartDrag()
    return true
  }

  private func disarm() {
    if started { return }
    if NSEvent.pressedMouseButtons & 1 == 1 { return }
    hoverPath = ""
    hoverTitle = ""
    hoverArtist = ""
    hoverSoftware = "rekordbox"
    mouseDownEvent = nil
  }

  private func handle(_ event: NSEvent) {
    if event.type == .leftMouseDown {
      pressSerial += 1
      mouseDownEvent = event
      if !started {
        hoverPath = ""
        armSerial = 0
      }
      return
    }
    if event.type == .leftMouseUp {
      if !started {
        hoverPath = ""
        hoverTitle = ""
        hoverArtist = ""
        hoverSoftware = "rekordbox"
        mouseDownEvent = nil
      }
      return
    }
    guard !started, !hoverPath.isEmpty, armSerial == pressSerial else { return }
    let now = NSEvent.mouseLocation
    let dx = now.x - origin.x
    let dy = now.y - origin.y
    if (dx * dx + dy * dy) < 64 { return }
    started = true
    let ok: Bool
    if hoverPath.lowercased().hasPrefix("tidal:tracks:") {
      ok = beginTidalDrag(location: hoverPath, title: hoverTitle, artist: hoverArtist)
    } else {
      ok = beginDrag(path: hoverPath)
    }
    if !ok { started = false }
  }

  private func maybeStartDrag() {
    guard !started, !hoverPath.isEmpty, armSerial == pressSerial else { return }
    guard NSEvent.pressedMouseButtons & 1 == 1 else { return }
    let now = NSEvent.mouseLocation
    let dx = now.x - origin.x
    let dy = now.y - origin.y
    if (dx * dx + dy * dy) < 64 { return }
    started = true
    let ok: Bool
    if hoverPath.lowercased().hasPrefix("tidal:tracks:") {
      ok = beginTidalDrag(location: hoverPath, title: hoverTitle, artist: hoverArtist)
    } else {
      ok = beginDrag(path: hoverPath)
    }
    if !ok { started = false }
  }

  /// Keine Datei ziehen — sonst landet der Drop in der Trackliste
  /// (m3u8-Import) und nicht auf dem Player.
  @discardableResult
  private func beginTidalDrag(location: String, title: String, artist _: String) -> Bool {
    guard let view = sourceView, let window = view.window else { return false }
    let mouseDown = mouseDownEvent ?? NSEvent.mouseEvent(
      with: .leftMouseDown,
      location: window.mouseLocationOutsideOfEventStream,
      modifierFlags: NSEvent.modifierFlags,
      timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: window.windowNumber,
      context: nil,
      eventNumber: 0,
      clickCount: 1,
      pressure: 1
    )
    guard let mouseDown else { return false }

    let loc = view.convert(mouseDown.locationInWindow, from: nil)
    let icon = NSWorkspace.shared.icon(forFileType: "public.mp3")
    icon.size = NSSize(width: 32, height: 32)
    let frame = NSRect(x: loc.x - 16, y: loc.y - 16, width: 32, height: 32)

    if let up = NSEvent.mouseEvent(
      with: .leftMouseUp,
      location: mouseDown.locationInWindow,
      modifierFlags: mouseDown.modifierFlags,
      timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: window.windowNumber,
      context: nil,
      eventNumber: mouseDown.eventNumber,
      clickCount: 1,
      pressure: 0
    ) {
      window.sendEvent(up)
    }

    let writer = GhostTidalWriter(location: location, title: title)
    let item = NSDraggingItem(pasteboardWriter: writer)
    item.setDraggingFrame(frame, contents: icon)
    view.beginDraggingSession(with: [item], event: mouseDown, source: self)
    NSLog("VibesBox Sync drag: tidal ghost \(location)")
    return true
  }

  @discardableResult
  private func beginDrag(path: String) -> Bool {
    guard let view = sourceView, let window = view.window else { return false }
    let fileURL = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
    guard fileURL.isFileURL, FileManager.default.isReadableFile(atPath: fileURL.path) else {
      return false
    }
    let mouseDown = mouseDownEvent ?? NSEvent.mouseEvent(
      with: .leftMouseDown,
      location: window.mouseLocationOutsideOfEventStream,
      modifierFlags: NSEvent.modifierFlags,
      timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: window.windowNumber,
      context: nil,
      eventNumber: 0,
      clickCount: 1,
      pressure: 1
    )
    guard let mouseDown else { return false }

    let loc = view.convert(mouseDown.locationInWindow, from: nil)
    let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
    icon.size = NSSize(width: 32, height: 32)
    let frame = NSRect(x: loc.x - 16, y: loc.y - 16, width: 32, height: 32)

    // Flutter muss den Pointer loslassen, sonst frisst die View den Drag.
    if let up = NSEvent.mouseEvent(
      with: .leftMouseUp,
      location: mouseDown.locationInWindow,
      modifierFlags: mouseDown.modifierFlags,
      timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: window.windowNumber,
      context: nil,
      eventNumber: mouseDown.eventNumber,
      clickCount: 1,
      pressure: 0
    ) {
      window.sendEvent(up)
    }

    // Nur Originalpfad — keine Cache-Kopie. Rekordbox analysiert die
    // Drop-Datei (Beat/SQLCipher); eine gelöschte Kopie korrupt den Heap.
    let writer = PulseDJFileWriter(original: fileURL)
    let item = NSDraggingItem(pasteboardWriter: writer)
    item.setDraggingFrame(frame, contents: icon)
    view.beginDraggingSession(with: [item], event: mouseDown, source: self)
    NSLog("VibesBox Sync drag: start \(fileURL.path)")
    return true
  }

  func draggingSession(
    _ session: NSDraggingSession,
    sourceOperationMaskFor context: NSDraggingContext
  ) -> NSDragOperation {
    .every
  }

  func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
    true
  }

  func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
    let pb = session.draggingPasteboard
    let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [NSURL] ?? []
    let files = urls.filter(\.isFileURL).compactMap(\.path)
    let types = pb.types?.map(\.rawValue).joined(separator: ",") ?? "-"
    NSLog("VibesBox Sync drag: NSURL \(files.count) types=\(types) \(files.first ?? "-")")
  }

  func draggingSession(
    _ session: NSDraggingSession,
    endedAt screenPoint: NSPoint,
    operation: NSDragOperation
  ) {
    let wasTidal = hoverPath.lowercased().hasPrefix("tidal:tracks:")
    let title = hoverTitle
    let artist = hoverArtist
    let location = hoverPath
    let software = hoverSoftware
    NSLog("VibesBox Sync drag: Ende operation=\(operation.rawValue) tidal=\(wasTidal) software=\(software)")
    started = false
    hoverPath = ""
    hoverTitle = ""
    hoverArtist = ""
    hoverSoftware = "rekordbox"
    mouseDownEvent = nil
    if wasTidal, !title.isEmpty {
      RekordboxCollectionLoad.loadDropped(
        title: title,
        artist: artist,
        location: location,
        dropPoint: screenPoint,
        software: software
      )
    }
  }
}

/// Pulse DJ: acht Pasteboard-Typen. `public.url` / `url ` sind der
/// Originalpfad, den Rekordbox lädt. File-url/NSFilenames bei Pulse
/// zeigen auf eine SwiftUI-Cache-Kopie — die darf Rekordbox nicht
/// analysieren, sonst stürzt die Beat-Analyse ab, wenn die Kopie weg ist.
/// Hier deshalb **überall** der Originalpfad.
private final class PulseDJFileWriter: NSObject, NSPasteboardWriting {
  let original: URL

  init(original: URL) {
    self.original = original
    super.init()
  }

  func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
    [
      .fileURL,
      NSPasteboard.PasteboardType("CorePasteboardFlavorType 0x6675726C"),
      NSPasteboard.PasteboardType("NSFilenamesPboardType"),
      NSPasteboard.PasteboardType("Apple URL pasteboard type"),
      .URL,
      NSPasteboard.PasteboardType("CorePasteboardFlavorType 0x75726C20"),
    ]
  }

  func writingOptions(
    forType type: NSPasteboard.PasteboardType,
    pasteboard: NSPasteboard
  ) -> NSPasteboard.WritingOptions {
    []
  }

  func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
    let url = original.absoluteString
    switch type.rawValue {
    case "public.file-url":
      return url
    case "CorePasteboardFlavorType 0x6675726C":
      return url.data(using: .utf8)
    case "NSFilenamesPboardType":
      return [original.path]
    case "Apple URL pasteboard type":
      return [url]
    case "public.url":
      return url
    case "CorePasteboardFlavorType 0x75726C20":
      return url.data(using: .utf8)
    default:
      return nil
    }
  }
}

/// Gemini/Pulse: Rekordbox liest den Text `tidal://track/<id>` (Einzahl).
/// `tidal://tracks/<id>` (Mehrzahl) hat Rekordbox bereits ignoriert.
/// Keine Datei-URL.
private final class GhostTidalWriter: NSObject, NSPasteboardWriting {
  let location: String
  let tidalURL: String
  let title: String

  init(location: String, title: String) {
    self.location = location
    let id: String
    if location.contains("://") {
      id = location.split(separator: "/").last.map(String.init) ?? ""
    } else {
      id = location.split(separator: ":").last.map(String.init) ?? ""
    }
    tidalURL = "tidal://track/\(id)"
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    self.title = trimmed.isEmpty ? "Tidal" : trimmed
    super.init()
  }

  func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
    [
      .URL,
      NSPasteboard.PasteboardType("Apple URL pasteboard type"),
      NSPasteboard.PasteboardType("CorePasteboardFlavorType 0x75726C20"),
      .string,
      NSPasteboard.PasteboardType("com.vibesbox.sync.tidal-load"),
    ]
  }

  func writingOptions(
    forType type: NSPasteboard.PasteboardType,
    pasteboard: NSPasteboard
  ) -> NSPasteboard.WritingOptions {
    []
  }

  func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
    switch type.rawValue {
    case "public.url", "public.utf8-plain-text":
      return tidalURL
    case "Apple URL pasteboard type":
      return [tidalURL, title]
    case "CorePasteboardFlavorType 0x75726C20":
      return tidalURL.data(using: .utf8)
    case "com.vibesbox.sync.tidal-load":
      return tidalURL
    default:
      return nil
    }
  }
}

/// Tidal-Streams sind kein Finder-Drop. Rekordbox: Tidal-Katalog im Baum,
/// Suche, dann Load aufs Deck — der Song muss nicht in der Collection liegen.
enum RekordboxCollectionLoad {
  static func promptAccessibilityIfNeeded() {
    let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
  }

  static func loadDropped(
    title: String,
    artist: String,
    location: String,
    dropPoint: NSPoint,
    software: String = "rekordbox"
  ) {
    if isOverOurWindow(dropPoint) {
      NSLog("VibesBox Sync tidal: Drop über Sync-Fenster, kein Load")
      return
    }
    let app = runningDj(software)
    let overApp = isOverDj(dropPoint, software: software)
    guard overApp || app?.isActive == true else {
      NSLog("VibesBox Sync tidal: Drop nicht über \(software)")
      return
    }
    let titleQ = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let artistQ = artist.trimmingCharacters(in: .whitespacesAndNewlines)
    let query = artistQ.isEmpty ? titleQ : "\(titleQ) \(artistQ)"
    guard !titleQ.isEmpty else {
      NSLog("VibesBox Sync tidal: kein Titel für Suche \(location)")
      return
    }
    promptAccessibilityIfNeeded()
    guard AXIsProcessTrusted() else {
      NSLog("VibesBox Sync tidal: Bedienungshilfen fehlen")
      return
    }

    let drop = NSEvent.mouseLocation
    let deck = deckForDrop(drop, software: software)
    let pid = app?.processIdentifier
    let isRekordbox = software == "rekordbox"
    let snap = isRekordbox ? (pid.map { captureFolder($0) } ?? FolderSnap()) : FolderSnap()
    NSLog("VibesBox Sync tidal: Load „\(query)“ \(software) Deck \(deck) folder=\(snap.title ?? "-")")

    app?.activate(options: [.activateIgnoringOtherApps])
    postClicks(cocoaToQuartz(drop), count: 1, pid: pid)

    let savedPaste = NSPasteboard.general.string(forType: .string)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(query, forType: .string)

    if isRekordbox, let pid {
      // Nicht Strg+F: das ist die Collection. Tidal-Katalog im Baum öffnen.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
        let opened = clickTidalSource(pid: pid)
        NSLog("VibesBox Sync tidal: Tidal-Quelle \(opened)")
        DispatchQueue.main.asyncAfter(deadline: .now() + (opened ? 0.55 : 0.12)) {
          _ = clickSearchField(pid: pid)
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            key(0x00, flags: .maskCommand, pid: pid)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
              key(0x09, flags: .maskCommand, pid: pid)
              DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
                let row = trackRowBelowSearch(pid: pid)
                if let row {
                  NSLog("VibesBox Sync tidal: Katalog-Zeile \(row), Deck \(deck)")
                  postClicks(row, count: 1, pid: pid)
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    key(deck == 1 ? 0x7B : 0x7C, flags: .maskShift, pid: pid)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                      restoreFolder(pid: pid, snap: snap)
                      restorePaste(savedPaste)
                    }
                  }
                } else {
                  NSLog("VibesBox Sync tidal: keine Treffer-Position")
                  restoreFolder(pid: pid, snap: snap)
                  restorePaste(savedPaste)
                }
              }
            }
          }
        }
      }
      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
      key(0x03, flags: .maskCommand)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
        key(0x00, flags: .maskCommand)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
          key(0x09, flags: .maskCommand)
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            key(0x24, flags: [], pid: pid)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
              restorePaste(savedPaste)
            }
          }
        }
      }
    }
  }

  private static func restorePaste(_ savedPaste: String?) {
    NSPasteboard.general.clearContents()
    if let savedPaste {
      NSPasteboard.general.setString(savedPaste, forType: .string)
    }
  }

  private static func runningDj(_ software: String) -> NSRunningApplication? {
    NSWorkspace.shared.runningApplications.first { app in
      djNameMatches(app.localizedName ?? "", software: software)
        || djNameMatches(app.bundleIdentifier ?? "", software: software)
    }
  }

  private static func djNameMatches(_ raw: String, software: String) -> Bool {
    let lower = raw.lowercased()
    switch software {
    case "serato":
      return lower.contains("serato")
    case "virtualdj":
      return lower.contains("virtualdj") || lower.contains("virtual dj") || lower.contains("atomix")
    case "traktor":
      return lower.contains("traktor")
    case "mixxx":
      return lower.contains("mixxx")
    case "enginedj":
      return lower.contains("enginedj") || lower.contains("engine dj")
        || (lower.contains("engine") && !lower.contains("webkit"))
    default:
      return lower.contains("rekordbox") && !lower.contains("agent")
    }
  }

  /// 2-Deck horizontal: rechte Hälfte des DJ-Fensters = Deck 2.
  /// Nur das größte Fenster, keine Union — sonst wandert die Mitte nach rechts
  /// und Drops auf Deck 2 gelten noch als Deck 1.
  private static func deckForDrop(_ point: NSPoint, software: String = "rekordbox") -> Int {
    if let bounds = cocoaBounds(software: software) {
      NSLog("VibesBox Sync tidal: deck-check x=\(Int(point.x)) mid=\(Int(bounds.midX)) bounds=\(bounds)")
      return point.x < bounds.midX ? 1 : 2
    }
    let screen = NSScreen.main?.frame ?? .zero
    return point.x < screen.midX ? 1 : 2
  }

  private static func isOverOurWindow(_ point: NSPoint) -> Bool {
    NSApp.windows.contains { $0.isVisible && $0.frame.contains(point) }
  }

  private static func isOverDj(_ point: NSPoint, software: String) -> Bool {
    cocoaBounds(software: software)?.contains(point) == true
  }

  private static func cocoaBounds(software: String) -> CGRect? {
    let list = CGWindowListCopyWindowInfo(
      [.optionOnScreenOnly, .excludeDesktopElements],
      kCGNullWindowID
    ) as? [[String: Any]] ?? []
    var best: CGRect?
    var bestArea: CGFloat = 0
    for info in list {
      let owner = (info[kCGWindowOwnerName as String] as? String) ?? ""
      guard djNameMatches(owner, software: software) else { continue }
      let layer = info[kCGWindowLayer as String] as? Int ?? 0
      guard layer == 0 else { continue }
      guard let raw = info[kCGWindowBounds as String] as? [String: CGFloat],
            let x = raw["X"], let y = raw["Y"],
            let w = raw["Width"], let h = raw["Height"],
            w > 200, h > 200
      else { continue }
      let cocoa = quartzToCocoa(CGRect(x: x, y: y, width: w, height: h))
      let area = cocoa.width * cocoa.height
      if area > bestArea {
        bestArea = area
        best = cocoa
      }
    }
    return best
  }

  private static func quartzToCocoa(_ rect: CGRect) -> CGRect {
    let height = NSScreen.screens.map(\.frame.maxY).max() ?? NSScreen.main?.frame.height ?? 0
    return CGRect(
      x: rect.origin.x,
      y: height - rect.origin.y - rect.height,
      width: rect.width,
      height: rect.height
    )
  }

  private static func rekordboxCocoaBounds() -> CGRect? {
    cocoaBounds(software: "rekordbox")
  }

  private static func firstTrackClickPoint(software: String = "rekordbox") -> CGPoint? {
    guard let b = cocoaBounds(software: software) else { return nil }
    let x = b.minX + b.width * 0.42
    let y = b.minY + b.height * 0.14
    return CGPoint(x: x, y: y)
  }

  private struct FolderSnap {
    var title: String?
    var treeClick: CGPoint?
  }

  /// Merkt den linken Baum-Ordner, bevor Strg+F in die Sammlung springt.
  private static func captureFolder(_ pid: pid_t) -> FolderSnap {
    var snap = FolderSnap(title: treeShortcutPlaylist())
    let app = AXUIElementCreateApplication(pid)
    var remaining = 800
    func walk(_ el: AXUIElement, depth: Int) {
      if remaining <= 0 || depth > 14 { return }
      remaining -= 1
      let selected = (axAttr(el, kAXSelectedAttribute as String) as? NSNumber)?.boolValue == true
      let focused = (axAttr(el, kAXFocusedAttribute as String) as? NSNumber)?.boolValue == true
      if (selected || focused), let frame = axFrame(el), isInTreePanel(frame) {
        snap.treeClick = CGPoint(x: frame.midX, y: frame.midY)
        let title = ((axAttr(el, kAXTitleAttribute as String) as? String)
          ?? (axAttr(el, kAXValueAttribute as String) as? String)
          ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if title.count > 1, title.count < 80 {
          snap.title = title
        }
      }
      for child in axChildren(el) {
        walk(child, depth: depth + 1)
      }
    }
    walk(app, depth: 0)
    return snap
  }

  private static func isInTreePanel(_ frame: CGRect) -> Bool {
    guard let b = rekordboxCocoaBounds() else { return frame.minX < 420 }
    let topLeft = cocoaToQuartz(CGPoint(x: b.minX, y: b.maxY))
    let treeW = min(360, max(220, b.width * 0.28))
    return frame.midX >= topLeft.x - 10 && frame.midX <= topLeft.x + treeW && frame.height < 80
  }

  /// Ordner im Baum anklicken, dann Suche leeren — ohne Strg+F (sonst Sammlung).
  private static func restoreFolder(pid: pid_t, snap: FolderSnap) {
    clickSavedFolder(pid: pid, snap: snap)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
      clearSearchBar(pid: pid)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
        clickSavedFolder(pid: pid, snap: snap)
      }
    }
  }

  private static func clickSavedFolder(pid: pid_t, snap: FolderSnap) {
    if let p = snap.treeClick {
      NSLog("VibesBox Sync tidal: Ordner-Klick \(p) \(snap.title ?? "")")
      postClicks(p, count: 1, pid: pid)
      return
    }
    let names = [snap.title, treeShortcutPlaylist()].compactMap { $0 }
    for name in names where !name.isEmpty {
      if clickBrowserTitle(pid: pid, title: name) { return }
    }
  }

  private static func focusedIsSearchField(_ pid: pid_t) -> Bool {
    let app = AXUIElementCreateApplication(pid)
    guard let focused = axAttr(app, kAXFocusedUIElementAttribute as String) else { return false }
    let el = focused as! AXUIElement
    guard let frame = axFrame(el) else { return false }
    return frame.height > 4 && frame.height < 90 && frame.width > 60
  }

  private static func clearSearchBar(pid: pid_t) {
    func wipe() {
      key(0x00, flags: .maskCommand, pid: pid)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        key(0x33, flags: [], pid: pid)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
          key(0x35, flags: [], pid: pid)
        }
      }
    }
    if focusedIsSearchField(pid) {
      wipe()
      return
    }
    guard let b = rekordboxCocoaBounds() else { return }
    let cocoa = CGPoint(x: b.minX + min(430, b.width * 0.40), y: b.minY + b.height * 0.30)
    postClicks(cocoaToQuartz(cocoa), count: 1, pid: pid)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
      guard focusedIsSearchField(pid) else { return }
      wipe()
    }
  }

  private static func clickTidalSource(pid: pid_t) -> Bool {
    let app = AXUIElementCreateApplication(pid)
    var exact: CGPoint?
    var fuzzy: CGPoint?
    var remaining = 700
    func walk(_ el: AXUIElement, depth: Int) {
      if remaining <= 0 || depth > 14 { return }
      remaining -= 1
      let text = ((axAttr(el, kAXTitleAttribute as String) as? String)
        ?? (axAttr(el, kAXValueAttribute as String) as? String)
        ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      let lower = text.lowercased()
      if let frame = axFrame(el), frame.width > 8, frame.height > 8, isInTreePanel(frame) {
        if lower == "tidal" || lower == "tidál" {
          exact = CGPoint(x: frame.midX, y: frame.midY)
        } else if fuzzy == nil, lower.contains("tidal"), text.count < 18 {
          fuzzy = CGPoint(x: frame.midX, y: frame.midY)
        }
      }
      for child in axChildren(el) {
        walk(child, depth: depth + 1)
      }
    }
    walk(app, depth: 0)
    if let p = exact ?? fuzzy {
      NSLog("VibesBox Sync tidal: Tidal-Knoten @ \(p)")
      postClicks(p, count: 1, pid: pid)
      return true
    }
    return clickBrowserTitle(pid: pid, title: "TIDAL")
  }

  private static func clickSearchField(pid: pid_t) -> Bool {
    let app = AXUIElementCreateApplication(pid)
    var best: (point: CGPoint, y: CGFloat)?
    var remaining = 500
    func walk(_ el: AXUIElement, depth: Int) {
      if remaining <= 0 || depth > 14 { return }
      remaining -= 1
      let role = ((axAttr(el, kAXRoleAttribute as String) as? String) ?? "").lowercased()
      if (role.contains("textfield") || role.contains("search") || role.contains("combobox")),
         let frame = axFrame(el),
         frame.width > 80,
         frame.height > 8,
         frame.height < 52 {
        if best == nil || frame.minY < best!.y {
          best = (CGPoint(x: frame.midX, y: frame.midY), frame.minY)
        }
      }
      for child in axChildren(el) {
        walk(child, depth: depth + 1)
      }
    }
    walk(app, depth: 0)
    if let hit = best {
      NSLog("VibesBox Sync tidal: Suchfeld @ \(hit.point)")
      postClicks(hit.point, count: 1, pid: pid)
      return true
    }
    guard let b = rekordboxCocoaBounds() else { return false }
    let cocoa = CGPoint(x: b.minX + b.width * 0.48, y: b.maxY - 36)
    postClicks(cocoaToQuartz(cocoa), count: 1, pid: pid)
    return true
  }

  private static func clickBrowserTitle(pid: pid_t, title: String) -> Bool {
    let want = title.lowercased()
    let app = AXUIElementCreateApplication(pid)
    var remaining = 500
    func walk(_ el: AXUIElement, depth: Int) -> Bool {
      if remaining <= 0 || depth > 12 { return false }
      remaining -= 1
      let text = ((axAttr(el, kAXTitleAttribute as String) as? String)
        ?? (axAttr(el, kAXValueAttribute as String) as? String)
        ?? "").lowercased()
      if (text == want || text.contains(want)), let frame = axFrame(el), frame.width > 8, frame.height > 8 {
        let p = CGPoint(x: frame.midX, y: frame.midY)
        NSLog("VibesBox Sync tidal: Playlist zurück \(title) @ \(p)")
        postClicks(p, count: 1, pid: pid)
        return true
      }
      for child in axChildren(el) {
        if walk(child, depth: depth + 1) { return true }
      }
      return false
    }
    return walk(app, depth: 0)
  }

  /// Erste Playlist-Taste in den Rekordbox-Baum-Shortcuts (z. B. Jugendclub).
  private static func treeShortcutPlaylist() -> String? {
    let url = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(
        "Library/Application Support/Pioneer/rekordbox6/browseSetting.xml"
      )
    guard let xml = try? String(contentsOf: url, encoding: .utf8),
          let start = xml.range(of: "<TREESHORTCUT>"),
          let end = xml.range(of: "</TREESHORTCUT>")
    else { return nil }
    let block = xml[start.lowerBound..<end.upperBound]
    let pattern = #"name="([^"]+)""#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let ns = block as NSString
    let range = NSRange(location: 0, length: ns.length)
    for match in regex.matches(in: String(block), range: range) {
      let name = ns.substring(with: match.range(at: 1))
      let lower = name.lowercased()
      if name.count > 1,
         lower != "tidal",
         lower != "sammlung",
         !lower.contains("geräte"),
         !lower.contains("gerate") {
        return name
      }
    }
    return nil
  }

  private static func axChildren(_ el: AXUIElement) -> [AXUIElement] {
    axAttr(el, kAXChildrenAttribute as String) as? [AXUIElement] ?? []
  }

  /// Erste Trackzeile unter dem Suchfeld (Quartz-Koordinaten).
  private static func trackRowBelowSearch(pid: pid_t?) -> CGPoint? {
    guard let pid else { return nil }
    let app = AXUIElementCreateApplication(pid)
    guard let focused = axAttr(app, kAXFocusedUIElementAttribute as String) else {
      NSLog("VibesBox Sync tidal: kein Fokus-Element")
      return nil
    }
    let el = focused as! AXUIElement
    let role = (axAttr(el, kAXRoleAttribute as String) as? String) ?? "?"
    guard let frame = axFrame(el) else { return nil }
    NSLog("VibesBox Sync tidal: Fokus \(role) \(frame)")
    guard frame.height > 4, frame.height < 90, frame.width > 60 else { return nil }
    return CGPoint(
      x: frame.minX + min(180, max(80, frame.width * 0.35)),
      y: frame.maxY + 44
    )
  }

  private static func axAttr(_ el: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    let err = AXUIElementCopyAttributeValue(el, name as CFString, &value)
    return err == .success ? value : nil
  }

  private static func axFrame(_ el: AXUIElement) -> CGRect? {
    guard let posVal = axAttr(el, kAXPositionAttribute as String),
          CFGetTypeID(posVal) == AXValueGetTypeID()
    else { return nil }
    var origin = CGPoint.zero
    AXValueGetValue(posVal as! AXValue, .cgPoint, &origin)
    var size = CGSize(width: 240, height: 24)
    if let sizeVal = axAttr(el, kAXSizeAttribute as String),
       CFGetTypeID(sizeVal) == AXValueGetTypeID() {
      AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
    }
    return CGRect(origin: origin, size: size)
  }

  private static func cocoaToQuartz(_ p: CGPoint) -> CGPoint {
    let height = NSScreen.screens.map(\.frame.maxY).max() ?? 0
    return CGPoint(x: p.x, y: height - p.y)
  }

  private static func postClicks(_ quartz: CGPoint, count: Int64, pid _: pid_t? = nil) {
    let src = CGEventSource(stateID: .hidSystemState)
    if let move = CGEvent(
      mouseEventSource: src,
      mouseType: .mouseMoved,
      mouseCursorPosition: quartz,
      mouseButton: .left
    ) {
      move.post(tap: .cghidEventTap)
    }
    for n: Int64 in 1...count {
      if let down = CGEvent(
        mouseEventSource: src,
        mouseType: .leftMouseDown,
        mouseCursorPosition: quartz,
        mouseButton: .left
      ) {
        down.setIntegerValueField(.mouseEventClickState, value: n)
        down.post(tap: .cghidEventTap)
      }
      if let up = CGEvent(
        mouseEventSource: src,
        mouseType: .leftMouseUp,
        mouseCursorPosition: quartz,
        mouseButton: .left
      ) {
        up.setIntegerValueField(.mouseEventClickState, value: n)
        up.post(tap: .cghidEventTap)
      }
    }
  }

  private static func key(_ code: CGKeyCode, flags: CGEventFlags, pid: pid_t? = nil) {
    let src = CGEventSource(stateID: .hidSystemState)
    if let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true) {
      down.flags = flags
      if let pid { down.postToPid(pid) }
      down.post(tap: .cghidEventTap)
    }
    if let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false) {
      up.flags = flags
      if let pid { up.postToPid(pid) }
      up.post(tap: .cghidEventTap)
    }
  }
}

final class LibraryPathPicker {
  func attach(to controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "vibesbox_sync/library_path",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "pick" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any] ?? [:]
      let start = (args["start"] as? String) ?? ""
      DispatchQueue.main.async {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = "Datei oder Ordner der Bibliothek wählen"
        panel.prompt = "Auswählen"
        if !start.isEmpty {
          let url = URL(fileURLWithPath: start)
          var isDir: ObjCBool = false
          if FileManager.default.fileExists(atPath: start, isDirectory: &isDir) {
            panel.directoryURL = isDir.boolValue ? url : url.deletingLastPathComponent()
          } else {
            panel.directoryURL = url.deletingLastPathComponent()
          }
        }
        if panel.runModal() == .OK, let path = panel.url?.path {
          result(path)
        } else {
          result(nil)
        }
      }
    }
  }
}
