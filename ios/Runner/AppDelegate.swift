import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications のため UNUserNotificationCenter のデリゲートを設定する。
    // 未設定だと「フォアグラウンド通知の表示」「タップ콜백(onDidReceiveNotificationResponse)」
    // 「cold start の通知起動検知(getNotificationAppLaunchDetails)」がいずれも機能しない。
    // FlutterAppDelegate は UNUserNotificationCenterDelegate を実装しており、
    // 各콜백を登録済みプラグイン（flutter_local_notifications）へ転送する。
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
