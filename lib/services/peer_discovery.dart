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
  // 🔑 UNIQUE IDENTIFIERS - Simplified for reliability
  static const String SERVICE_UUID = "12345678-1234-5678-9abc-123456789012";
  static const String CHARACTERISTIC_UUID =
      "12345678-1234-5678-9abc-123456789013";
  static const String APP_SIGNATURE = "PEERAPP2024";
  static const String APP_NAME_PREFIX = "PeerApp";
  static const int PEER_THRESHOLD = 2;
  static const int MANUFACTURER_ID =
      0x004C; // Apple's manufacturer ID (more reliable)

  // 📱 DEVICE INFO
  final DatabaseReference _database;
  final String _deviceId;
  final String _deviceName;

  // 🔄 STATE MANAGEMENT - BOTH SCANNING AND BROADCASTING
  bool _isActive = false; // Combined state for both operations
  bool _isBluetoothEnabled = false;
  String _connectionStatus = 'disconnected';
  String _firebaseStatus = 'ready';

  // 📊 DATA STORAGE - ONLY APP USERS
  final Map<String, PeerData> _discoveredAppUsers = {};
  final List<DiscoverySession> _uploadHistory = [];

  // 🎛️ SUBSCRIPTIONS & TIMERS
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _bluetoothStateSubscription;
  Timer? _uploadTimer;
  Timer? _discoveryTimer;
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();

  // 🚀 CONSTRUCTOR
  PeerDiscoveryService()
      : _database = FirebaseDatabase.instance.ref(),
        _deviceId = const Uuid().v4().substring(0, 8),
        _deviceName =
            '${APP_NAME_PREFIX}_${const Uuid().v4().substring(0, 8)}' {
    _initializeBluetooth();
    _checkPermissions();
  }

  // 📖 GETTERS
  String get deviceId => _deviceId;
  String get deviceName => _deviceName;
  bool get isActive => _isActive; // Both scanning and broadcasting
  bool get isScanning => _isActive; // For backward compatibility
  bool get isBroadcasting => _isActive; // For backward compatibility
  bool get isBluetoothEnabled => _isBluetoothEnabled;
  String get connectionStatus => _connectionStatus;
  String get firebaseStatus => _firebaseStatus;
  List<PeerData> get discoveredPeers => _discoveredAppUsers.values.toList();
  List<String> get appUserIds => _discoveredAppUsers.keys.toList();
  int get appUserCount => _discoveredAppUsers.length;
  List<DiscoverySession> get uploadHistory => _uploadHistory;

  // 🔵 BLUETOOTH INITIALIZATION
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
          _stopDiscovery();
        }

        debugPrint('🔵 Bluetooth state: ${_isBluetoothEnabled ? 'ON' : 'OFF'}');
        notifyListeners();
      });

      final state = await FlutterBluePlus.adapterState.first;
      _isBluetoothEnabled = state == BluetoothAdapterState.on;
      _connectionStatus = _isBluetoothEnabled ? 'ready' : 'bluetooth_off';

      debugPrint(
          '🔵 Bluetooth initialized: ${_isBluetoothEnabled ? 'Ready' : 'Not Ready'}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Bluetooth init error: $e');
      _connectionStatus = 'bluetooth_error';
      notifyListeners();
    }
  }

  // 🔐 PERMISSION HANDLING
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
          debugPrint('❌ Permissions denied: $statuses');
          _connectionStatus = 'permission_denied';
          notifyListeners();
          return false;
        }
      }

      debugPrint('✅ All permissions granted');
      return true;
    } catch (e) {
      debugPrint('❌ Permission error: $e');
      _connectionStatus = 'permission_error';
      notifyListeners();
      return false;
    }
  }

  // 🚀 START PEER DISCOVERY (BOTH BROADCAST AND SCAN)
  Future<void> startDiscovery() async {
    if (_isActive || !_isBluetoothEnabled) {
      debugPrint(
          '⚠️ Cannot start discovery: isActive=$_isActive, bluetoothEnabled=$_isBluetoothEnabled');
      return;
    }

    if (!await _checkPermissions()) {
      debugPrint('❌ Permissions not granted');
      return;
    }

    try {
      _isActive = true;
      _connectionStatus = 'discovering';
      notifyListeners();

      debugPrint('🚀 STARTING PEER DISCOVERY MODE');
      debugPrint('   📡 Broadcasting: Making device discoverable');
      debugPrint('   🔍 Scanning: Looking for other app users');
      debugPrint('   My Device ID: $_deviceId');
      debugPrint('   My Device Name: $_deviceName');

      // Clear previous discoveries
      _discoveredAppUsers.clear();

      // Start both broadcasting and scanning simultaneously
      await _startBroadcasting();
      await _startScanning();

      // Start continuous discovery with periodic refresh
      _startDiscoveryTimer();
    } catch (e) {
      debugPrint('❌ Start discovery error: $e');
      _handleDiscoveryError(e);
    }
  }

  // 📡 START BROADCASTING
  Future<void> _startBroadcasting() async {
    try {
      // Create manufacturer data with app signature and device ID
      final manufacturerDataString = '$APP_SIGNATURE$_deviceId';
      final manufacturerDataBytes = utf8.encode(manufacturerDataString);

      final advertiseData = AdvertiseData(
        includeDeviceName: true,
        localName: _deviceName,
        manufacturerData: manufacturerDataBytes,
        manufacturerId: MANUFACTURER_ID,
        serviceUuid: SERVICE_UUID,
      );

      await _blePeripheral.start(advertiseData: advertiseData);

      debugPrint('📡 BROADCASTING STARTED:');
      debugPrint('   ✅ Device Name: $_deviceName');
      debugPrint('   ✅ Device ID: $_deviceId');
      debugPrint('   ✅ Service UUID: $SERVICE_UUID');
      debugPrint('   ✅ Other app users can now discover this device!');
    } catch (e) {
      debugPrint('❌ Start broadcasting error: $e');
      throw e;
    }
  }

  // 🔍 START SCANNING
  Future<void> _startScanning() async {
    try {
      debugPrint('🔍 SCANNING STARTED:');
      debugPrint('   Looking for Service: $SERVICE_UUID');

      // Start scanning with service filter
      await FlutterBluePlus.startScan(
        withServices: [Guid(SERVICE_UUID)],
        timeout: const Duration(seconds: 30),
        androidUsesFineLocation: false,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          if (results.isNotEmpty) {
            debugPrint('📡 Scan results: ${results.length} devices found');
            _processScanResults(results);
          }
        },
        onError: (e) {
          debugPrint('❌ Scan error: $e');
          _handleDiscoveryError(e);
        },
      );
    } catch (e) {
      debugPrint('❌ Start scanning error: $e');
      throw e;
    }
  }

  // ⏰ DISCOVERY TIMER - PERIODIC REFRESH
  void _startDiscoveryTimer() {
    _discoveryTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isActive && _isBluetoothEnabled) {
        debugPrint('🔄 Refreshing discovery...');
        _refreshDiscovery();
      }
    });
  }

  Future<void> _refreshDiscovery() async {
    try {
      // Restart scanning to find new devices
      await FlutterBluePlus.stopScan();
      await Future.delayed(const Duration(seconds: 1));

      if (_isActive) {
        await FlutterBluePlus.startScan(
          withServices: [Guid(SERVICE_UUID)],
          timeout: const Duration(seconds: 30),
          androidUsesFineLocation: false,
        );
      }
    } catch (e) {
      debugPrint('❌ Refresh discovery error: $e');
    }
  }

  // 📡 PROCESS SCAN RESULTS - ONLY APP USERS
  void _processScanResults(List<ScanResult> results) {
    for (final result in results) {
      // Skip if no service UUIDs (shouldn't happen with filtered scan)
      if (result.advertisementData.serviceUuids.isEmpty) continue;

      // Check if it has our service UUID
      bool hasOurService = result.advertisementData.serviceUuids.any((uuid) =>
          uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase());

      if (!hasOurService) continue;

      // Extract device info
      String? appDeviceId = _extractDeviceId(result);
      if (appDeviceId == null) continue;

      // Skip self-detection
      if (appDeviceId == _deviceId) {
        debugPrint('⚠️ Skipping self-detection');
        continue;
      }

      // Create peer data
      final peerData = PeerData(
        deviceId: appDeviceId,
        deviceName: _getDeviceName(result, appDeviceId),
        discoveredAt: DateTime.now(),
        rssi: result.rssi,
      );

      // Add to discovered users
      if (!_discoveredAppUsers.containsKey(appDeviceId)) {
        _discoveredAppUsers[appDeviceId] = peerData;

        debugPrint('🎉 NEW APP USER DISCOVERED:');
        debugPrint('   ✅ Device ID: $appDeviceId');
        debugPrint('   ✅ Device Name: ${peerData.deviceName}');
        debugPrint('   ✅ RSSI: ${result.rssi} dBm');
        debugPrint('   ✅ Total App Users: ${_discoveredAppUsers.length}');

        // Check threshold
        if (_discoveredAppUsers.length >= PEER_THRESHOLD) {
          debugPrint('📤 Threshold reached! Scheduling upload...');
          _scheduleUpload();
        }

        notifyListeners();
      } else {
        // Update existing user
        _discoveredAppUsers[appDeviceId] = peerData;
        debugPrint('🔄 Updated app user: $appDeviceId (RSSI: ${result.rssi})');
      }
    }
  }

  // 🔧 EXTRACT DEVICE ID - MULTIPLE METHODS
  String? _extractDeviceId(ScanResult result) {
    // Method 1: From manufacturer data
    String? deviceId = _extractFromManufacturerData(result);
    if (deviceId != null) return deviceId;

    // Method 2: From device name
    deviceId = _extractFromDeviceName(result);
    if (deviceId != null) return deviceId;

    // Method 3: From advertisement name
    deviceId = _extractFromAdvertisementName(result);
    if (deviceId != null) return deviceId;

    debugPrint('❌ Could not extract device ID from result');
    return null;
  }

  String? _extractFromManufacturerData(ScanResult result) {
    try {
      for (final entry in result.advertisementData.manufacturerData.entries) {
        if (entry.key == MANUFACTURER_ID) {
          final data = entry.value;
          if (data.length >= APP_SIGNATURE.length + 8) {
            final decodedData = utf8.decode(data);
            if (decodedData.startsWith(APP_SIGNATURE)) {
              final deviceId = decodedData.substring(
                  APP_SIGNATURE.length, APP_SIGNATURE.length + 8);
              if (_isValidDeviceId(deviceId)) {
                debugPrint('✅ Device ID from manufacturer data: $deviceId');
                return deviceId;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error extracting from manufacturer data: $e');
    }
    return null;
  }

  String? _extractFromDeviceName(ScanResult result) {
    try {
      String deviceName = result.device.platformName;
      if (deviceName.isNotEmpty &&
          deviceName.startsWith('${APP_NAME_PREFIX}_')) {
        final parts = deviceName.split('_');
        if (parts.length >= 2 && _isValidDeviceId(parts[1])) {
          debugPrint('✅ Device ID from device name: ${parts[1]}');
          return parts[1];
        }
      }
    } catch (e) {
      debugPrint('❌ Error extracting from device name: $e');
    }
    return null;
  }

  String? _extractFromAdvertisementName(ScanResult result) {
    try {
      String advName = result.advertisementData.advName;
      if (advName.isNotEmpty && advName.startsWith('${APP_NAME_PREFIX}_')) {
        final parts = advName.split('_');
        if (parts.length >= 2 && _isValidDeviceId(parts[1])) {
          debugPrint('✅ Device ID from advertisement name: ${parts[1]}');
          return parts[1];
        }
      }
    } catch (e) {
      debugPrint('❌ Error extracting from advertisement name: $e');
    }
    return null;
  }

  String _getDeviceName(ScanResult result, String deviceId) {
    // Try platform name first
    if (result.device.platformName.isNotEmpty) {
      return result.device.platformName;
    }

    // Try advertisement name
    if (result.advertisementData.advName.isNotEmpty) {
      return result.advertisementData.advName;
    }

    // Generate name from device ID
    return '${APP_NAME_PREFIX}_$deviceId';
  }

  bool _isValidDeviceId(String deviceId) {
    return deviceId.length == 8 &&
        RegExp(r'^[a-zA-Z0-9]{8}$').hasMatch(deviceId);
  }

  // 🛑 STOP DISCOVERY (BOTH BROADCAST AND SCAN)
  Future<void> stopDiscovery() async {
    await _stopDiscovery();
  }

  Future<void> _stopDiscovery() async {
    if (!_isActive) return;

    try {
      _isActive = false;
      _discoveryTimer?.cancel();
      _discoveryTimer = null;

      // Stop scanning
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;

      // Stop broadcasting
      await _blePeripheral.stop();

      _connectionStatus = _isBluetoothEnabled ? 'ready' : 'bluetooth_off';

      debugPrint('🛑 STOPPED PEER DISCOVERY');
      debugPrint('   📡 Broadcasting: Stopped');
      debugPrint('   🔍 Scanning: Stopped');
      debugPrint('   Found ${_discoveredAppUsers.length} app users');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Stop discovery error: $e');
    }
  }

  void _handleDiscoveryError(dynamic error) {
    debugPrint('❌ Discovery error: $error');
    _stopDiscovery();
    _connectionStatus = 'discovery_error';
    notifyListeners();
  }

  // LEGACY METHODS FOR BACKWARD COMPATIBILITY
  Future<void> startScanning() async => await startDiscovery();
  Future<void> stopScanning() async => await stopDiscovery();
  Future<void> startBroadcasting() async => await startDiscovery();
  Future<void> stopBroadcasting() async => await stopDiscovery();

  // ⏰ SCHEDULE UPLOAD
  void _scheduleUpload() {
    _uploadTimer?.cancel();
    _uploadTimer = Timer(const Duration(seconds: 2), () {
      uploadToFirebase();
    });
  }

  // 📤 UPLOAD TO FIREBASE
  Future<void> uploadToFirebase() async {
    if (_discoveredAppUsers.length < PEER_THRESHOLD ||
        _firebaseStatus != 'ready') {
      debugPrint(
          '⚠️ Upload skipped - need ${PEER_THRESHOLD} users, have ${_discoveredAppUsers.length}');
      return;
    }

    try {
      _firebaseStatus = 'uploading';
      notifyListeners();

      final session = DiscoverySession(
        sessionId: const Uuid().v4(),
        deviceId: _deviceId,
        timestamp: DateTime.now(),
        peersDiscovered: _discoveredAppUsers.values.toList(),
        peerCount: _discoveredAppUsers.length,
      );

      debugPrint('📤 UPLOADING TO FIREBASE:');
      debugPrint('   ✅ Session ID: ${session.sessionId}');
      debugPrint('   ✅ My Device ID: $_deviceId');
      debugPrint('   ✅ App Users Found: ${session.peerCount}');

      for (final user in _discoveredAppUsers.values) {
        debugPrint('   ✅ User: ${user.deviceId} (${user.deviceName})');
      }

      final updates = <String, dynamic>{
        'discovery_sessions/${session.sessionId}': session.toJson(),
        'devices/$_deviceId': {
          'device_name': _deviceName,
          'last_seen': ServerValue.timestamp,
          'total_sessions': _uploadHistory.length + 1,
          'discovered_users':
              _discoveredAppUsers.map((k, v) => MapEntry(k, v.toJson())),
        },
      };

      await _database.update(updates);

      _uploadHistory.insert(0, session);
      if (_uploadHistory.length > 50) _uploadHistory.removeLast();

      _discoveredAppUsers.clear();
      _firebaseStatus = 'success';

      debugPrint('✅ FIREBASE UPLOAD SUCCESSFUL!');
      notifyListeners();

      // Reset status after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _firebaseStatus = 'ready';
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('❌ FIREBASE UPLOAD FAILED: $e');
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

  // 🔄 FORCE UPLOAD
  Future<void> forceUpload() async {
    if (_discoveredAppUsers.isNotEmpty) {
      debugPrint(
          '🔄 Force uploading ${_discoveredAppUsers.length} app users...');
      await uploadToFirebase();
    } else {
      debugPrint('⚠️ No app users to upload');
    }
  }

  // 🗑️ CLEAR DISCOVERED USERS
  void clearDiscoveredAppUsers() {
    final count = _discoveredAppUsers.length;
    _discoveredAppUsers.clear();
    debugPrint('🗑️ Cleared $count app users');
    notifyListeners();
  }

  // 📊 GET STATISTICS
  Map<String, dynamic> getStatistics() {
    return {
      'device_id': _deviceId,
      'device_name': _deviceName,
      'total_sessions': _uploadHistory.length,
      'app_users_found': _discoveredAppUsers.length,
      'is_active': _isActive,
      'is_scanning': _isActive, // Both are same now
      'is_broadcasting': _isActive, // Both are same now
      'bluetooth_enabled': _isBluetoothEnabled,
      'connection_status': _connectionStatus,
      'firebase_status': _firebaseStatus,
    };
  }

  // 🔄 MOUNTED CHECK
  bool get mounted => hasListeners;

  // 🧹 DISPOSE
  @override
  void dispose() {
    debugPrint('🔄 Disposing PeerDiscoveryService');
    _stopDiscovery();
    _uploadTimer?.cancel();
    _discoveryTimer?.cancel();
    _bluetoothStateSubscription?.cancel();
    super.dispose();
  }
}
