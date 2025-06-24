import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ble_firebase_app/models/peer_data.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

class PeerDiscoveryService extends ChangeNotifier {
  static const String SERVICE_UUID = "12345678-1234-5678-9abc-123456789abc";
  static const String CHARACTERISTIC_UUID =
      "87654321-4321-8765-cba9-987654321cba";
  static const int MANUFACTURER_ID = 0xFFFF;
  static const int PEER_THRESHOLD = 5;

  final DatabaseReference _database;
  final String _deviceId;
  final String _deviceName;

  bool _isScanning = false;
  bool _isBroadcasting = false;
  bool _isBluetoothEnabled = false;
  String _connectionStatus = 'disconnected';
  String _firebaseStatus = 'ready';

  final Map<String, PeerData> _discoveredPeers = {};
  final List<DiscoverySession> _uploadHistory = [];

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _bluetoothStateSubscription;
  Timer? _uploadTimer;
  Timer? _advertisingTimer;

  PeerDiscoveryService()
      : _database = FirebaseDatabase.instance.ref(),
        _deviceId = const Uuid().v4().substring(0, 8),
        _deviceName = 'PeerDevice_${const Uuid().v4().substring(0, 4)}' {
    _initializeBluetooth();
    _checkPermissions();
  }

  // Getters
  String get deviceId => _deviceId;
  String get deviceName => _deviceName;
  bool get isScanning => _isScanning;
  bool get isBroadcasting => _isBroadcasting;
  bool get isBluetoothEnabled => _isBluetoothEnabled;
  String get connectionStatus => _connectionStatus;
  String get firebaseStatus => _firebaseStatus;
  List<PeerData> get discoveredPeers => _discoveredPeers.values.toList();
  List<DiscoverySession> get uploadHistory => _uploadHistory;
  int get peerCount => _discoveredPeers.length;

  Future<void> _initializeBluetooth() async {
    try {
      bool isAvailable = await FlutterBluePlus.isSupported;
      if (!isAvailable) {
        _connectionStatus = 'bluetooth_unavailable';
        notifyListeners();
        return;
      }

      _bluetoothStateSubscription =
          FlutterBluePlus.adapterState.listen((state) {
        _isBluetoothEnabled = state == BluetoothAdapterState.on;
        _connectionStatus = _isBluetoothEnabled ? 'ready' : 'bluetooth_off';
        if (!_isBluetoothEnabled) {
          _stopScanning();
          _stopBroadcasting();
        }
        notifyListeners();
      });

      final state = await FlutterBluePlus.adapterState.first;
      _isBluetoothEnabled = state == BluetoothAdapterState.on;
      _connectionStatus = _isBluetoothEnabled ? 'ready' : 'bluetooth_off';
      notifyListeners();
    } catch (e) {
      debugPrint('Bluetooth init error: $e');
      _connectionStatus = 'bluetooth_error';
      notifyListeners();
    }
  }

  Future<bool> _checkPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
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
          _connectionStatus = 'permission_denied';
          notifyListeners();
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Permission error: $e');
      _connectionStatus = 'permission_error';
      notifyListeners();
      return false;
    }
  }

  Future<void> startScanning() async {
    if (_isScanning || !_isBluetoothEnabled || !await _checkPermissions())
      return;

    try {
      _isScanning = true;
      _connectionStatus = 'scanning';
      notifyListeners();

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        androidUsesFineLocation: false,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) => _processScanResults(results),
        onError: (e) => _handleScanError(e),
      );

      Timer(const Duration(seconds: 30), () => _stopScanning());
    } catch (e) {
      _handleScanError(e);
    }
  }

  Future<void> stopScanning() async {
    await _stopScanning();
  }

  void _processScanResults(List<ScanResult> results) {
    for (final result in results) {
      try {
        final peerId = _extractPeerId(result);
        if (peerId == null || peerId == _deviceId) continue;

        final peerData = PeerData(
          deviceId: peerId,
          deviceName: result.device.platformName.isNotEmpty
              ? result.device.platformName
              : (result.advertisementData.advName.isNotEmpty
                  ? result.advertisementData.advName
                  : 'Unknown'),
          discoveredAt: DateTime.now(),
          rssi: result.rssi,
        );

        if (!_discoveredPeers.containsKey(peerId)) {
          _discoveredPeers[peerId] = peerData;

          if (_discoveredPeers.length >= PEER_THRESHOLD &&
              _firebaseStatus == 'ready') {
            _scheduleUpload();
          }

          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error processing device: $e');
      }
    }
  }

  String? _extractPeerId(ScanResult result) {
    try {
      // Check manufacturer data
      if (result.advertisementData.manufacturerData
          .containsKey(MANUFACTURER_ID)) {
        final data =
            result.advertisementData.manufacturerData[MANUFACTURER_ID]!;
        if (data.isNotEmpty) {
          try {
            return utf8.decode(data).trim();
          } catch (e) {
            debugPrint('Error decoding manufacturer data: $e');
          }
        }
      }

      // Check service data
      final serviceGuid = Guid(SERVICE_UUID);
      if (result.advertisementData.serviceData.containsKey(serviceGuid)) {
        final data = result.advertisementData.serviceData[serviceGuid]!;
        if (data.isNotEmpty) {
          try {
            return utf8.decode(data).trim();
          } catch (e) {
            debugPrint('Error decoding service data: $e');
          }
        }
      }

      // Fallback: use device remote ID if no custom data found
      return result.device.remoteId.toString();
    } catch (e) {
      debugPrint('Error extracting peer ID: $e');
      return null;
    }
  }

  void _handleScanError(dynamic error) {
    debugPrint('Scan error: $error');
    _stopScanning();
    _connectionStatus = 'scan_error';
    notifyListeners();
  }

  Future<void> startBroadcasting() async {
    if (_isBroadcasting || !_isBluetoothEnabled || !await _checkPermissions())
      return;

    try {
      _isBroadcasting = true;
      notifyListeners();

      final mData = Uint8List.fromList(utf8.encode(_deviceId.padRight(8)));
      await _startAdvertising(mData);

      _advertisingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (_isBroadcasting) _startAdvertising(mData);
      });
    } catch (e) {
      debugPrint('Start broadcasting error: $e');
      _stopBroadcasting();
    }
  }

  Future<void> stopBroadcasting() async {
    await _stopBroadcasting();
  }

  Future<void> _startAdvertising(Uint8List mData) async {
    try {
      // Note: Flutter Blue Plus doesn't have built-in advertising support
      // You'll need to use a different approach for BLE advertising
      // Option 1: Use flutter_ble_peripheral plugin
      // Option 2: Use platform-specific code
      // Option 3: Simulate advertising by frequently updating scan data

      debugPrint(
          'Warning: BLE advertising not directly supported by Flutter Blue Plus');
      debugPrint(
          'Consider using flutter_ble_peripheral plugin for advertising functionality');

      // Temporary workaround - you might want to implement alternative advertising
      // using a different plugin or platform channels
    } catch (e) {
      debugPrint('Advertising error: $e');
      if (_isBroadcasting) {
        await Future.delayed(const Duration(seconds: 1));
        await _startAdvertising(mData);
      }
    }
  }

  Future<void> _stopScanning() async {
    if (!_isScanning) return;

    try {
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanning = false;
      _connectionStatus = _isBluetoothEnabled ? 'ready' : 'bluetooth_off';
      notifyListeners();
    } catch (e) {
      debugPrint('Stop scanning error: $e');
    }
  }

  Future<void> _stopBroadcasting() async {
    if (!_isBroadcasting) return;

    try {
      _advertisingTimer?.cancel();
      _advertisingTimer = null;

      // Note: No stopAdvertising method needed since we're not actually advertising
      // If using flutter_ble_peripheral, you would call its stop method here

      _isBroadcasting = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Stop broadcasting error: $e');
    }
  }

  void _scheduleUpload() {
    _uploadTimer?.cancel();
    _uploadTimer = Timer(const Duration(seconds: 2), () {
      uploadToFirebase();
    });
  }

  Future<void> uploadToFirebase() async {
    // SIMULATE FAKE PEERS FOR TESTING (Only on single device)/////////
    if (_discoveredPeers.length < 2) {
      _discoveredPeers['testpeer1'] = PeerData(
        deviceId: 'testpeer1',
        deviceName: 'FakeDevice1',
        discoveredAt: DateTime.now(),
        rssi: -60,
      );
      _discoveredPeers['testpeer2'] = PeerData(
        deviceId: 'testpeer2',
        deviceName: 'FakeDevice2',
        discoveredAt: DateTime.now(),
        rssi: -70,
      );
    }
///////////
    if (_discoveredPeers.length < PEER_THRESHOLD || _firebaseStatus != 'ready')
      return;

    try {
      _firebaseStatus = 'uploading';
      notifyListeners();

      final session = DiscoverySession(
        sessionId: const Uuid().v4(),
        deviceId: _deviceId,
        timestamp: DateTime.now(),
        peersDiscovered: _discoveredPeers.values.toList(),
        peerCount: _discoveredPeers.length,
      );

      final updates = <String, dynamic>{
        'discovery_sessions/${session.sessionId}': session.toJson(),
        'devices/$_deviceId': {
          'last_seen': ServerValue.timestamp,
          'peers': _discoveredPeers.map((k, v) => MapEntry(k, v.toJson())),
        },
      };

      await _database.update(updates);

      _uploadHistory.insert(0, session);
      if (_uploadHistory.length > 50) _uploadHistory.removeLast();

      _firebaseStatus = 'success';
      _discoveredPeers.clear();
      notifyListeners();

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _firebaseStatus = 'ready';
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Firebase upload error: $e');
      _firebaseStatus = 'error';
      notifyListeners();

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _firebaseStatus = 'ready';
          notifyListeners();
        }
      });
    }
  }

  bool get mounted => hasListeners;

  @override
  void dispose() {
    _stopScanning();
    _stopBroadcasting();
    _uploadTimer?.cancel();
    _advertisingTimer?.cancel();
    _bluetoothStateSubscription?.cancel();
    super.dispose();
  }
}
