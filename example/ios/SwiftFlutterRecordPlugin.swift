import Flutter
import UIKit

public class SwiftFlutterRecordPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_record", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterRecordPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? NSDictionary<String, Any>
    result("iOS " + UIDevice.current.systemVersion)
  }
}
