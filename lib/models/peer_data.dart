class PeerData {
  final String deviceId;
  final String deviceName;
  final DateTime discoveredAt;
  final int rssi;

  PeerData({
    required this.deviceId,
    required this.deviceName,
    required this.discoveredAt,
    required this.rssi,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'discoveredAt': discoveredAt.toIso8601String(),
      'rssi': rssi,
    };
  }

  factory PeerData.fromJson(Map<String, dynamic> json) {
    return PeerData(
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      discoveredAt: DateTime.parse(json['discoveredAt']),
      rssi: json['rssi'],
    );
  }
}

class DiscoverySession {
  final String sessionId;
  final String deviceId;
  final DateTime timestamp;
  final List<PeerData> peersDiscovered;
  final int peerCount;

  DiscoverySession({
    required this.sessionId,
    required this.deviceId,
    required this.timestamp,
    required this.peersDiscovered,
    required this.peerCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'deviceId': deviceId,
      'timestamp': timestamp.toIso8601String(),
      'peersDiscovered': peersDiscovered.map((p) => p.toJson()).toList(),
      'peerCount': peerCount,
    };
  }

  factory DiscoverySession.fromJson(Map<String, dynamic> json) {
    return DiscoverySession(
      sessionId: json['sessionId'],
      deviceId: json['deviceId'],
      timestamp: DateTime.parse(json['timestamp']),
      peersDiscovered: (json['peersDiscovered'] as List)
          .map((p) => PeerData.fromJson(p))
          .toList(),
      peerCount: json['peerCount'],
    );
  }
}
