import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {

    // Derives app group from the main bundle ID — works for both flavors:
    //   com.maintify.app     → group.com.maintify.app
    //   com.maintify.app.dev → group.com.maintify.app.dev
    private var appGroupId: String {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.maintify.app"
        return "group.\(bundleId)"
    }

    private let widgetDataKey = "widgetData"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // ── Widget MethodChannel ──────────────────────────────────────────────
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        let widgetChannel = FlutterMethodChannel(
            name: "com.maintify.app/widget",
            binaryMessenger: controller.binaryMessenger
        )

        widgetChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "updateWidgetData":
                self.handleUpdateWidgetData(call.arguments, result: result)
            case "clearWidgetData":
                self.handleClearWidgetData(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - Widget data handlers

    private func handleUpdateWidgetData(_ arguments: Any?, result: FlutterResult) {
        guard
            let args = arguments as? [String: Any],
            let defaults = UserDefaults(suiteName: appGroupId)
        else {
            result(FlutterError(code: "UNAVAILABLE",
                                message: "App Group unavailable: \(appGroupId)",
                                details: nil))
            return
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: args)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                result(FlutterError(code: "ENCODE_ERROR",
                                    message: "Could not encode widget data",
                                    details: nil))
                return
            }
            defaults.set(jsonString, forKey: widgetDataKey)
            defaults.synchronize()
            reloadWidget()
            result(nil)
        } catch {
            result(FlutterError(code: "ENCODE_ERROR",
                                message: error.localizedDescription,
                                details: nil))
        }
    }

    private func handleClearWidgetData(result: FlutterResult) {
        if let defaults = UserDefaults(suiteName: appGroupId) {
            defaults.removeObject(forKey: widgetDataKey)
            defaults.synchronize()
        }
        reloadWidget()
        result(nil)
    }

    private func reloadWidget() {
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Deep-link URL handling

    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // Pass maintify:// URLs to the Flutter plugin system.
        // The app already routes to the correct screen via SplashScreen auth check.
        return super.application(app, open: url, options: options)
    }
}
