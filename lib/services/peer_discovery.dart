import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:ble_firebase_app/models/peer_data.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

class PeerDiscoveryService extends ChangeNotifier {
  static const String SERVICE_UUID = "a1b2c3d4-e5f6-7890-abcd-1234567890ab";
  static const String CHARACTERISTIC_UUID =
      "a1b2c3d5-e5f6-7890-abcd-1234567890ab";

  static const String APP_NAME_PREFIX = "PeerApp";
  static const int PEER_THRESHOLD = 2;

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
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();

  PeerDiscoveryService()
      : _database = FirebaseDatabase.instance.ref(),
        _deviceId = const Uuid().v4().substring(0, 8),
        _deviceName =
            '${APP_NAME_PREFIX}_${const Uuid().v4().substring(0, 8)}' {
    _initializeBluetooth();
    _checkPermissions();
  }

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

      // ALTERNATIVE APPROACH: Scan for all devices, filter by name pattern
      await FlutterBluePlus.startScan(
        // Remove service filtering since we can't advertise the service UUID
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
        final peerInfo = _extractPeerInfo(result);
        if (peerInfo == null || peerInfo['deviceId'] == _deviceId) continue;

        final peerId = peerInfo['deviceId'] as String;
        final peerName = peerInfo['deviceName'] as String;

        final peerData = PeerData(
          deviceId: peerId,
          deviceName: peerName,
          discoveredAt: DateTime.now(),
          rssi: result.rssi,
        );

        if (!_discoveredPeers.containsKey(peerId)) {
          _discoveredPeers[peerId] = peerData;

          debugPrint('✅ Discovered app user: $peerId ($peerName)');

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

  Map<String, String>? _extractPeerInfo(ScanResult result) {
    try {
      String deviceName = result.device.platformName.isNotEmpty
          ? result.device.platformName
          : result.advertisementData.advName;

      if (deviceName.startsWith('${APP_NAME_PREFIX}_')) {
        final parts = deviceName.split('_');
        if (parts.length >= 2) {
          return {
            'deviceId': parts[1],
            'deviceName': deviceName,
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error extracting peer info: $e');
      return null;
    }
  }

  String? _extractIdFromManufacturerData(ScanResult result) {
    try {
      for (final entry in result.advertisementData.manufacturerData.entries) {
        final data = entry.value;
        if (data.isNotEmpty) {
          final decodedData = utf8.decode(data).trim();

          if (decodedData.length >= 6 && decodedData.length <= 12) {
            return decodedData;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error extracting from manufacturer data: $e');
      return null;
    }
  }

  void _handleScanError(dynamic error) {
    debugPrint('Scan error: $error');
    _stopScanning();
    _connectionStatus = 'scan_error';
    notifyListeners();
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

  Future<void> startBroadcasting() async {
    if (_isBroadcasting || !_isBluetoothEnabled || !await _checkPermissions())
      return;

    try {
      _isBroadcasting = true;
      notifyListeners();

      final advertiseData = AdvertiseData(
        includeDeviceName: true,
        localName: _deviceName,
        manufacturerData: utf8.encode(_deviceId),
      );

      await _blePeripheral.start(advertiseData: advertiseData);

      debugPrint('🔊 Broadcasting as: $_deviceName');
    } catch (e) {
      debugPrint('Start broadcasting error: $e');
      _stopBroadcasting();
    }
  }

  Future<void> stopBroadcasting() async {
    await _stopBroadcasting();
  }

  Future<void> _stopBroadcasting() async {
    if (!_isBroadcasting) return;

    try {
      await _blePeripheral.stop();
      _advertisingTimer?.cancel();
      _advertisingTimer = null;
      _isBroadcasting = false;
      debugPrint('🔇 Stopped broadcasting');
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

      debugPrint('📤 Uploading session with ${session.peerCount} app users');

      final updates = <String, dynamic>{
        'discovery_sessions/${session.sessionId}': session.toJson(),
        'devices/$_deviceId': {
          'device_name': _deviceName,
          'last_seen': ServerValue.timestamp,
          'app_version': '1.0.0', // Add app version tracking
          'peers': _discoveredPeers.map((k, v) => MapEntry(k, v.toJson())),
        },
        // Also track the peer relationships
        'peer_connections/${_deviceId}': {
          'timestamp': ServerValue.timestamp,
          'connected_peers': _discoveredPeers.keys.toList(),
        }
      };

      await _database.update(updates);

      _uploadHistory.insert(0, session);
      if (_uploadHistory.length > 50) _uploadHistory.removeLast();

      _firebaseStatus = 'success';

      // Clear discovered peers after successful upload
      _discoveredPeers.clear();

      debugPrint('✅ Successfully uploaded peer data to Firebase');
      notifyListeners();

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _firebaseStatus = 'ready';
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('❌ Firebase upload error: $e');
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

  // Helper method to manually trigger upload (for testing)
  Future<void> forceUpload() async {
    if (_discoveredPeers.isNotEmpty) {
      await uploadToFirebase();
    }
  }

  // Method to clear discovered peers
  void clearDiscoveredPeers() {
    _discoveredPeers.clear();
    notifyListeners();
  }

  // Get statistics
  Map<String, dynamic> getStatistics() {
    return {
      'total_sessions': _uploadHistory.length,
      'current_peers': _discoveredPeers.length,
      'device_id': _deviceId,
      'device_name': _deviceName,
      'is_scanning': _isScanning,
      'is_broadcasting': _isBroadcasting,
      'bluetooth_enabled': _isBluetoothEnabled,
    };
  }

  bool get mounted => hasListeners;

  @override
  void dispose() {
    debugPrint('🔄 Disposing PeerDiscoveryService');
    _stopScanning();
    _stopBroadcasting();
    _uploadTimer?.cancel();
    _advertisingTimer?.cancel();
    _bluetoothStateSubscription?.cancel();
    super.dispose();
  }
}
