import 'dart:io';

import 'package:ble_firebase_app/screen/attendenceScreen.dart';
import 'package:ble_firebase_app/screen/blAdvertiseScreen.dart';
import 'package:ble_firebase_app/screen/bleScreen.dart';
import 'package:ble_firebase_app/screen/peer_discovery.dart';
import 'package:ble_firebase_app/services/ble_service.dart';
import 'package:ble_firebase_app/services/peer_discovery.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    checkPermissions();
  }

  void checkPermissions() async {
    //await requestLocationPermission();
    await requestBluetoothConnectPermission();
  }


  Future<void> requestBluetoothConnectPermission() async {
    if (Platform.isAndroid) {
      // ✅ Android 12+ requires fine-grained Bluetooth permissions
      final statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final allGranted =
      statuses.values.every((s) => s.isGranted || s.isLimited);

      if (!allGranted) {
        debugPrint('❌ Android permissions denied: $statuses');
      } else {
        debugPrint('✅ All Android permissions granted');
      }
    } else if (Platform.isIOS) {
      // ✅ On iOS, CoreBluetooth triggers system prompts automatically.
      // You just declare them in Info.plist and optionally check status here.
      final statuses = await [
        Permission.bluetooth,
        Permission.locationWhenInUse,
      ].request();

      final allGranted =
      statuses.values.every((s) => s.isGranted || s.isLimited);

      if (!allGranted) {
        debugPrint('❌ iOS permissions denied: $statuses');
      } else {
        debugPrint('✅ iOS permissions granted (system prompts handled by CoreBluetooth)');
      }
    }
  }


  Future<void> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      // networkManager.ws.updateSensorStatus(location: true);
      // networkManager.ws.updatePermissions(location: true);
    } else {
      // networkManager.ws.updateSensorStatus(location: false);
      // networkManager.ws.updatePermissions(location: false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PeerDiscoveryService('',''),
      child: MaterialApp(
        title: 'Peer Discovery',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: BleScreen(),
      ),
    );
  }
}
