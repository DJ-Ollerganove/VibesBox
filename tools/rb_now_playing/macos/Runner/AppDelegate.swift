import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationWillFinishLaunching(_ notification: Notification) {
    DjWatchdog.enterWatchdogModeIfNeeded()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // Watchdog ohne Fenster soll weiterlaufen.
    return !DjWatchdog.isWatchdogMode
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return false
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if DjWatchdog.isWatchdogMode {
      DjWatchdog.startPollingIfNeeded()
      return
    }
    super.applicationDidFinishLaunching(notification)
    for window in NSApp.windows {
      (window as? MainFlutterWindow)?.applyCompactChrome()
    }
  }
}
