import AVFoundation
import Flutter
import UIKit
import UserNotifications
import FirebaseMessaging
import GoogleMaps
#if DEBUG
import FirebaseCore
#endif

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var wishSoundPlayer: AVAudioPlayer?

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
    // Vor super: APNs-Token früh holen (FCM Hintergrund/Sperrbildschirm).
    application.registerForRemoteNotifications()
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      ShazamKitChannel.shared.register(binaryMessenger: controller.engine.binaryMessenger)
      registerNotificationSoundChannel(binaryMessenger: controller.engine.binaryMessenger)
    }
    return ok
  }

  /// Lokale Notifications im Vordergrund als Banner anzeigen (sonst nur Ton über [playWishNotificationSound]).
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  private func registerNotificationSoundChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "dj_og_app/notification_sound",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "playWishSound":
        self?.playWishNotificationSound()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Direkt abspielen — zuverlässiger als Notification-Sound, wenn AVAudioSession auf .record (Shazam) steht.
  private func playWishNotificationSound() {
    guard let url = Bundle.main.url(forResource: "notification", withExtension: "caf") else {
      return
    }
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      do {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true, options: [])
        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        self.wishSoundPlayer = player
        player.play()
      } catch {
        // Ton optional — Notification-Banner kann trotzdem erscheinen.
      }
    }
  }
}
