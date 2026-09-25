import Cocoa
import FlutterMacOS

/// Liest während eines Ziehens die System-Drag-Pasteboard
/// (Finder, Rekordbox, unser Tool) und schickt den Dump an Flutter.
final class DragSpy {
  private var sink: FlutterEventSink?
  private var monitorLocal: Any?
  private var monitorGlobal: Any?
  private var lastChange = -1
  private var lastText = ""

  func attach(to controller: FlutterViewController) {
    let channel = FlutterEventChannel(
      name: "vibesbox_sync/drag_spy",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setStreamHandler(SpyStream(owner: self))
    start()
  }

  fileprivate func setSink(_ sink: FlutterEventSink?) {
    self.sink = sink
    if sink != nil, !lastText.isEmpty {
      sink?(lastText)
    }
  }

  private func start() {
    if monitorLocal != nil { return }
    let handler: (NSEvent) -> Void = { [weak self] _ in
      self?.poll()
    }
    monitorLocal = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDragged, .leftMouseUp]
    ) { event in
      handler(event)
      return event
    }
    monitorGlobal = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDragged, .leftMouseUp]
    ) { event in
      handler(event)
    }
  }

  func capture(_ pb: NSPasteboard, label: String) {
    emit(Self.dump(pb, label: label))
  }

  private func poll() {
    let pb = NSPasteboard(name: .drag)
    let change = pb.changeCount
    guard change != lastChange else { return }
    lastChange = change
    let types = pb.types ?? []
    if types.isEmpty { return }
    emit(Self.dump(pb, label: "Maus"))
  }

  private func emit(_ text: String) {
    lastText = text
    if let sink {
      DispatchQueue.main.async { sink(text) }
    }
    let home = FileManager.default.homeDirectoryForCurrentUser
    let dir = home.appendingPathComponent("Library/Application Support/VibesBoxRbTool")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("drag_spy.txt")
    try? text.write(to: file, atomically: true, encoding: .utf8)
    let log = dir.appendingPathComponent("drag_spy_log.txt")
    let stamp = ISO8601DateFormatter().string(from: Date())
    let chunk = "\n==== \(stamp) ====\n\(text)\n"
    if let handle = try? FileHandle(forWritingTo: log) {
      handle.seekToEndOfFile()
      handle.write(Data(chunk.utf8))
      handle.closeFile()
    } else {
      try? chunk.write(to: log, atomically: true, encoding: .utf8)
    }
  }

  private static func dump(_ pb: NSPasteboard, label: String) -> String {
    var lines = ["[\(label)]"]
    let types = pb.types ?? []
    if types.isEmpty {
      lines.append("(leer)")
      return lines.joined(separator: "\n")
    }
    lines.append("Typen (\(types.count)):")
    for type in types {
      lines.append("  • \(type.rawValue)")
    }

    if let names = pb.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String],
       !names.isEmpty {
      lines.append("NSFilenames:")
      names.prefix(8).forEach { lines.append("  \($0)") }
    }

    let urls = pb.readObjects(forClasses: [NSURL.self], options: [
      .urlReadingFileURLsOnly: true,
    ]) as? [URL] ?? []
    if !urls.isEmpty {
      lines.append("NSURL:")
      urls.prefix(8).forEach { lines.append("  \($0.path)") }
    }

    let fileURL = pb.string(forType: .fileURL)
    if let fileURL, !fileURL.isEmpty {
      lines.append("file-url-string: \(clip(fileURL))")
    }

    let promised = pb.propertyList(
      forType: NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url")
    )
    if let promised {
      lines.append("promised-file-url: \(clip("\(promised)"))")
    }
    let promiseExt = pb.propertyList(
      forType: NSPasteboard.PasteboardType("NSFilesPromisePboardType")
    )
    if let promiseExt {
      lines.append("NSFilesPromise: \(clip("\(promiseExt)"))")
    }
    let itunes = pb.propertyList(
      forType: NSPasteboard.PasteboardType("CorePasteboardFlavorType 0x6974756E")
    )
    if let itunes {
      lines.append("iTunes: \(clip("\(itunes)"))")
    }

    if let text = pb.string(forType: .string), !text.isEmpty {
      lines.append("string: \(clip(text))")
    }

    for type in types.prefix(12) {
      if type == .string || type == .fileURL { continue }
      if let data = pb.data(forType: type), !data.isEmpty {
        let preview = String(data: data.prefix(180), encoding: .utf8)
          ?? String(data: data.prefix(180), encoding: .utf16)
          ?? "(\(data.count) Bytes binär)"
        lines.append("data[\(shortType(type.rawValue))]: \(clip(preview))")
      }
    }
    return lines.joined(separator: "\n")
  }

  private static func clip(_ s: String) -> String {
    let one = s.replacingOccurrences(of: "\n", with: "\\n")
    if one.count <= 240 { return one }
    return String(one.prefix(240)) + "…"
  }

  private static func shortType(_ raw: String) -> String {
    if let last = raw.split(separator: ".").last { return String(last) }
    return raw
  }
}

private final class SpyStream: NSObject, FlutterStreamHandler {
  weak var owner: DragSpy?
  init(owner: DragSpy) { self.owner = owner }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    owner?.setSink(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    owner?.setSink(nil)
    return nil
  }
}
