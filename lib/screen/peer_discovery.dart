import 'package:ble_firebase_app/services/peer_discovery.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/peer_data.dart';

class PeerDiscoveryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<PeerDiscoveryService>(
        builder: (context, service, child) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE3F2FD), Color(0xFF1976D2)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(service),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildControls(context, service),
                          _buildStatusIndicators(service),
                          _buildThresholdIndicator(service),
                          Expanded(child: _buildDiscoveredPeers(service)),
                          _buildUploadHistory(service),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(PeerDiscoveryService service) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bluetooth, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Peer Discovery',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'ID: ${service.deviceId.substring(0, 8)}...',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, PeerDiscoveryService service) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: service.isBluetoothEnabled
                  ? (service.isScanning
                      ? service.stopScanning
                      : service.startScanning)
                  : null,
              icon: Icon(service.isScanning ? Icons.stop : Icons.search),
              label: Text(service.isScanning ? 'Stop Scan' : 'Start Scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: service.isScanning ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: service.isBluetoothEnabled
                  ? (service.isBroadcasting
                      ? service.stopBroadcasting
                      : service.startBroadcasting)
                  : null,
              icon: Icon(
                  service.isBroadcasting ? Icons.stop_circle : Icons.radio),
              label:
                  Text(service.isBroadcasting ? 'Stop Broadcast' : 'Broadcast'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    service.isBroadcasting ? Colors.orange : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicators(PeerDiscoveryService service) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('BLE Status:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              Text(
                service.connectionStatus,
                style: TextStyle(
                  color: _getStatusColor(service.connectionStatus),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Firebase:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              Text(
                service.firebaseStatus,
                style: TextStyle(
                  color: _getFirebaseStatusColor(service.firebaseStatus),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdIndicator(PeerDiscoveryService service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: service.peerCount / PeerDiscoveryService.PEER_THRESHOLD,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              service.peerCount >= PeerDiscoveryService.PEER_THRESHOLD
                  ? Colors.green
                  : Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Discovered ${service.peerCount}/${PeerDiscoveryService.PEER_THRESHOLD} peers',
            style: TextStyle(
              color: service.peerCount >= PeerDiscoveryService.PEER_THRESHOLD
                  ? Colors.green
                  : Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveredPeers(PeerDiscoveryService service) {
    return Container(
      margin: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Discovered Peers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${service.peerCount}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: service.discoveredPeers.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bluetooth_searching,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No peers discovered yet',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start scanning to find nearby devices',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: service.discoveredPeers.length,
                    itemBuilder: (context, index) {
                      final peer = service.discoveredPeers[index];
                      return _buildPeerCard(peer);
                    },
                  ),
          ),
          if (service.peerCount >= PeerDiscoveryService.PEER_THRESHOLD)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Threshold reached - Uploading to Firebase',
                      style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeerCard(PeerData peer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peer.deviceId.length > 8
                      ? '${peer.deviceId.substring(0, 8)}...'
                      : peer.deviceId,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontWeight: FontWeight.w500),
                ),
                if (peer.deviceName != 'Unknown')
                  Text(
                    peer.deviceName,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${peer.rssi} dBm',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                _formatTime(peer.discoveredAt),
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadHistory(PeerDiscoveryService service) {
    if (service.uploadHistory.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 120,
      margin: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: service.uploadHistory.length,
              itemBuilder: (context, index) {
                final session = service.uploadHistory[index];
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session',
                        style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                      ),
                      Text(
                        session.sessionId.substring(0, 8),
                        style: const TextStyle(
                            fontSize: 10, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session.peerCount} peers',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatTime(session.timestamp),
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scanning':
        return Colors.blue;
      case 'connected':
        return Colors.green;
      case 'bluetooth_off':
        return Colors.red;
      case 'permission_denied':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getFirebaseStatusColor(String status) {
    switch (status) {
      case 'uploading':
        return Colors.orange;
      case 'success':
        return Colors.green;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
