import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps SDK for iOS 用APIキー（スポット機能の地図表示に必須）。
    // YOUR_GOOGLE_MAPS_API_KEY を実際のAPIキーに置き換えてください。
    GMSServices.provideAPIKey("AIzaSyBzWLPd3H3G-q3cpMKeDCtWlM3yXgxrtXc")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
