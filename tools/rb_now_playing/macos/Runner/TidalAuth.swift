import Cocoa
import FlutterMacOS
import WebKit

/// Einmaliges Tidal-Login im Tool (WebView).
/// WKWebView darf im Script-Callback nicht zerstört werden — das hat
/// den Absturz nach dem Login ausgelöst (objc_release / AutoreleasePool).
final class TidalSessionController: NSObject, WKNavigationDelegate, NSWindowDelegate {
  private weak var messenger: FlutterBinaryMessenger?
  private var loginWindow: NSWindow?
  private var webView: WKWebView?
  private var scriptProxy: ScriptProxy?
  private var loginResult: FlutterResult?
  private var closing = false
  private var token: String?
  private let storeURL: URL = {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let dir = home
      .appendingPathComponent("Library/Application Support/VibesBoxRbTool")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("tidal_auth.json")
  }()

  func attach(to controller: FlutterViewController) {
    messenger = controller.engine.binaryMessenger
    token = Self.readToken(from: storeURL)
    let channel = FlutterMethodChannel(
      name: "vibesbox_sync/tidal",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "gone", message: "Tidal-Session weg", details: nil))
        return
      }
      switch call.method {
      case "status":
        result(["loggedIn": self.token?.isEmpty == false])
      case "login":
        self.beginLogin(result)
      case "logout":
        self.logout()
        result(["loggedIn": false])
      case "search":
        let args = call.arguments as? [String: Any] ?? [:]
        let title = (args["title"] as? String) ?? ""
        let artist = (args["artist"] as? String) ?? ""
        self.search(title: title, artist: artist, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func beginLogin(_ result: @escaping FlutterResult) {
    if loginResult != nil || loginWindow != nil {
      result(["loggedIn": token?.isEmpty == false])
      return
    }
    loginResult = result
    DispatchQueue.main.async { [weak self] in
      self?.showLoginWindow()
    }
  }

  private func showLoginWindow() {
    closing = false
    let proxy = ScriptProxy()
    proxy.owner = self
    scriptProxy = proxy

    let config = WKWebViewConfiguration()
    config.websiteDataStore = .default()
    config.userContentController.addUserScript(
      WKUserScript(source: Self.hookSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    )
    config.userContentController.add(proxy, name: "tidalAuth")

    let web = WKWebView(frame: .zero, configuration: config)
    web.navigationDelegate = self
    web.customUserAgent =
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    webView = web

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 720, height: 780),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.isReleasedWhenClosed = false
    window.title = "Tidal anmelden — VibesBox Sync"
    window.contentView = web
    window.delegate = self
    window.center()
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    loginWindow = window

    if let url = URL(string: "https://listen.tidal.com/login") {
      web.load(URLRequest(url: url))
    }
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    scheduleClose(fromUser: true)
    return false
  }

  func onScriptToken(_ raw: String) {
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard value.count > 20 else { return }
    save(token: value)
    scheduleClose(fromUser: false)
  }

  private func scheduleClose(fromUser: Bool) {
    if closing { return }
    closing = true
    DispatchQueue.main.async { [weak self] in
      self?.tearDownLogin(complete: true)
    }
  }

  private func tearDownLogin(complete: Bool) {
    let pending = complete ? loginResult : nil
    loginResult = nil

    if let web = webView {
      web.stopLoading()
      web.navigationDelegate = nil
      web.configuration.userContentController.removeScriptMessageHandler(forName: "tidalAuth")
      web.configuration.userContentController.removeAllUserScripts()
    }
    scriptProxy?.owner = nil
    scriptProxy = nil
    webView = nil

    if let window = loginWindow {
      window.delegate = nil
      window.contentView = nil
      window.orderOut(nil)
    }
    loginWindow = nil
    closing = false

    pending?(["loggedIn": token?.isEmpty == false])
  }

  private func logout() {
    clearStoredToken()
    // WKWebsiteDataStore darf nur auf dem Main-Thread angefasst werden.
    // Vom URLSession-Callback (401) aus crasht WebKit sonst mit SIGTRAP.
    let wipe = { Self.clearTidalWebsiteData() }
    if Thread.isMainThread {
      wipe()
    } else {
      DispatchQueue.main.async(execute: wipe)
    }
  }

  private func clearStoredToken() {
    token = nil
    try? FileManager.default.removeItem(at: storeURL)
  }

  private static func clearTidalWebsiteData() {
    WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
      let tidal = records.filter {
        $0.displayName.lowercased().contains("tidal")
      }
      WKWebsiteDataStore.default().removeData(
        ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
        for: tidal,
        completionHandler: {}
      )
    }
  }

  private func save(token: String) {
    self.token = token
    let payload: [String: String] = [
      "accessToken": token,
      "capturedAt": ISO8601DateFormatter().string(from: Date()),
    ]
    if let data = try? JSONSerialization.data(withJSONObject: payload) {
      try? data.write(to: storeURL, options: .atomic)
    }
  }

  private func search(title: String, artist: String, result: @escaping FlutterResult) {
    guard let token, !token.isEmpty else {
      result(["tracks": []])
      return
    }
    let query = [title, artist].filter { !$0.isEmpty }.joined(separator: " ")
    let country = Locale.current.regionCode ?? "DE"
    var comps = URLComponents(string: "https://api.tidal.com/v1/search")
    comps?.queryItems = [
      URLQueryItem(name: "query", value: query),
      URLQueryItem(name: "limit", value: "8"),
      URLQueryItem(name: "offset", value: "0"),
      URLQueryItem(name: "types", value: "TRACKS"),
      URLQueryItem(name: "countryCode", value: country),
    ]
    guard let url = comps?.url else {
      result(["tracks": []])
      return
    }
    var req = URLRequest(url: url)
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    URLSession.shared.dataTask(with: req) { [weak self] data, response, _ in
      let code = (response as? HTTPURLResponse)?.statusCode ?? 0
      if code == 401 || code == 403 {
        self?.clearStoredToken()
        DispatchQueue.main.async { result(["tracks": [], "loggedIn": false]) }
        return
      }
      let tracks = Self.parseTracks(data)
      DispatchQueue.main.async { result(["tracks": tracks, "loggedIn": true]) }
    }.resume()
  }

  private static func parseTracks(_ data: Data?) -> [[String: String]] {
    guard let data,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return [] }
    let items: [[String: Any]]
    if let tracks = json["tracks"] as? [String: Any],
       let raw = tracks["items"] as? [[String: Any]] {
      items = raw
    } else if let raw = json["items"] as? [[String: Any]] {
      items = raw
    } else {
      return []
    }
    return items.compactMap { item in
      let id: String
      if let n = item["id"] as? NSNumber {
        id = n.stringValue
      } else {
        id = "\(item["id"] ?? "")"
      }
      if id.isEmpty || id == "0" { return nil }
      let title = "\(item["title"] ?? "")"
      var artist = ""
      if let a = item["artist"] as? [String: Any] {
        artist = "\(a["name"] ?? "")"
      } else if let artists = item["artists"] as? [[String: Any]],
                let first = artists.first {
        artist = "\(first["name"] ?? "")"
      }
      return ["id": id, "t": title, "a": artist]
    }
  }

  private static func readToken(from url: URL) -> String? {
    guard let data = try? Data(contentsOf: url),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    let token = (json["accessToken"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    return (token?.isEmpty == false) ? token : nil
  }

  private static let hookSource = """
  (function() {
    if (window.__vbTidalHook) return;
    window.__vbTidalHook = true;
    function report(v) {
      try {
        if (!v) return;
        var s = String(v);
        if (!/^Bearer\\s+/i.test(s)) return;
        var t = s.replace(/^Bearer\\s+/i, '');
        if (t.length > 20 && window.webkit && window.webkit.messageHandlers.tidalAuth) {
          window.webkit.messageHandlers.tidalAuth.postMessage(t);
        }
      } catch (e) {}
    }
    var origSet = XMLHttpRequest.prototype.setRequestHeader;
    XMLHttpRequest.prototype.setRequestHeader = function(k, v) {
      if (String(k).toLowerCase() === 'authorization') report(v);
      return origSet.apply(this, arguments);
    };
    var origFetch = window.fetch;
    window.fetch = function(input, init) {
      try {
        var h = init && init.headers;
        if (h) {
          if (typeof Headers !== 'undefined' && h instanceof Headers) {
            report(h.get('Authorization') || h.get('authorization'));
          } else if (Array.isArray(h)) {
            h.forEach(function(pair) {
              if (pair && String(pair[0]).toLowerCase() === 'authorization') report(pair[1]);
            });
          } else {
            Object.keys(h).forEach(function(k) {
              if (k.toLowerCase() === 'authorization') report(h[k]);
            });
          }
        }
      } catch (e) {}
      return origFetch.apply(this, arguments);
    };
  })();
  """
}

private final class ScriptProxy: NSObject, WKScriptMessageHandler {
  weak var owner: TidalSessionController?

  func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    guard message.name == "tidalAuth" else { return }
    owner?.onScriptToken("\(message.body)")
  }
}
