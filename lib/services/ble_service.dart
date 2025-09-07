import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/bleModel.dart';

class BleProvider with ChangeNotifier {
  final FlutterBluePlus _flutterBlue = FlutterBluePlus();

  // Keep list of discovered devices
  final List<BleDevice> _devices = [];
  List<BleDevice> get devices => _devices;

  bool _scanning = false;
  bool get scanning => _scanning;

  /// Start scanning
  Future<void> startScan() async {
    _devices.clear();
    _scanning = true;
    notifyListeners();

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        final deviceId = r.device.id.id; // Android -> MAC, iOS -> UUID
        String deviceName = "";
        if(r.device.name.isNotEmpty){
          deviceName=r.device.name;
        }
        // Avoid duplicates
        if (_devices.indexWhere((d) => d.id == deviceId) == -1) {
          _devices.add(
            BleDevice(id: deviceId, name: deviceName, rssi: r.rssi),
          );
          notifyListeners();
        }
      }
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 5),
    );

    _scanning = false;
    notifyListeners();
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _scanning = false;
    notifyListeners();
  }
}
