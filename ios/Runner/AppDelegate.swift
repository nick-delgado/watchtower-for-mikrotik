import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LocalNetwork") {
      registerLocalNetworkChannel(messenger: registrar.messenger())
    }
  }

  // Counterpart of LocalNetworkPermission in Dart.
  private func registerLocalNetworkChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "sh.nickd.watchtower/local_network", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "request":
        // iOS asks for local network access by itself on the first
        // connection and offers no API to check the answer.
        result(true)
      case "openSettings":
        // The app's page in Settings has the Local Network switch.
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
