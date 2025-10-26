import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "com.pkceauth.ios/auth"
  private var methodChannel: FlutterMethodChannel?
  private static var pendingUrl: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
      methodChannel = channel

      channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "getInitialUrl":
          result(AppDelegate.pendingUrl)
          // Clear after reading to avoid stale reuse
          AppDelegate.pendingUrl = nil
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    // Handle custom URL scheme redirect: com.pkceauth.ios:/callback?code=...
    if url.scheme == "com.pkceauth.ios" {
      let absolute = url.absoluteString
      // Store as pending in case Flutter isn't ready yet
      AppDelegate.pendingUrl = absolute
      // Try to push to Flutter immediately if channel is ready
      methodChannel?.invokeMethod("onAuthRedirect", arguments: absolute)
      return true
    }
    return false
  }
}
