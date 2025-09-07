import UIKit
import Flutter
import CoreBluetooth

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    var blePeripheralManager: BLEPeripheralManager?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        let bleChannel = FlutterMethodChannel(name: "com.example.ble_firebase_app/peripheral", binaryMessenger: controller.binaryMessenger)

        bleChannel.setMethodCallHandler { (call, result) in
            if call.method == "startAdvertising" {
                self.blePeripheralManager = BLEPeripheralManager()
                result("Advertising started")
            } else if call.method == "stopAdvertising" {
                self.blePeripheralManager?.stopAdvertising()
                result("Advertising stopped")
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
