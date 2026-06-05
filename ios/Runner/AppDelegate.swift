import Flutter
import UIKit
import GoogleMaps
#if DEBUG
import FirebaseCore
#endif

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
#if DEBUG
    // Vor FirebaseApp.configure() (Flutter-Plugins): verbose Logs → App-Check-Debug-Secret erscheint in Xcode-/Gerätekonsole.
    FirebaseConfiguration.shared.setLoggerLevel(.debug)
#endif
    // Google Maps API Key initialisieren
    GMSServices.provideAPIKey("AIzaSyC2ayswzUpQH_iEJDcASifUvb3GW8x6YAU")
    GeneratedPluginRegistrant.register(with: self)
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      ShazamKitChannel.shared.register(binaryMessenger: controller.engine.binaryMessenger)
    }
    return ok
  }
}
