import 'package:ble_firebase_app/services/peer_discovery.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/peer_data.dart';
import '../studentApi.dart';

class PeerDiscoveryScreen extends StatefulWidget {
  @override
  _PeerDiscoveryScreenState createState() => _PeerDiscoveryScreenState();
}

class _PeerDiscoveryScreenState extends State<PeerDiscoveryScreen> {

  Map<String, dynamic> studentList={};
  @override
  void initState() {
    super.initState();
    fetchRoaster();
    // Ensure the service is properly initialized when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {

      final service = Provider.of<PeerDiscoveryService>(context, listen: false);
      debugPrint(
          '🖥️ Screen initialized - Service status: ${service.connectionStatus}');
    });
  }

  Future<void> fetchRoaster() async {
    studentList=await Studentapi.fetchClassRoster();
    print("studentList:${studentList}");
    setState(() {});
  }

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
                  _buildHeader(service,studentList),
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
                    child: Column(children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildControls(context, service,studentList),
                              //_buildStatusIndicators(service),
                              //_buildThresholdIndicator(service),
                              Container(
                                height: 200, // Fixed height to prevent overflow
                                child: _buildDiscoveredPeers(service),
                              )
                            ],
                          ),
                        ),
                      ),
                      Container(
                        height: 120, // Fixed height for upload history
                        child: _buildUploadHistory(service),
                      ),
                    ]),
                  ))
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(PeerDiscoveryService service,Map<String,dynamic> studentList) {
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
            child: Icon(
               Icons.perm_contact_cal_outlined,
              color: Colors.black,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Student Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'ID: ${studentList['students'][0]['student_id']}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black26,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'Name: ${studentList['students'][0]['name']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black38,
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, PeerDiscoveryService service,Map<String, dynamic> studentList) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Main Discovery Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: service.isBluetoothEnabled
                  ? (service.isActive
                      ? () async {
                          debugPrint('🛑 User stopping discovery...');

                          await service.stopDiscovery();
                        }
                      : () async {
                          debugPrint('🚀 User starting discovery...');
                          await service.startDiscovery(studentList['students'][0]['name'],studentList['students'][0]['student_id']);
                        })
                  : null,
              label: Text(
                service.isActive ? 'Attendence Marked' : 'Mark Attendence',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: service.isActive ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: service.isBluetoothEnabled ? 3 : 0,
              ),
            ),
          ),

          const SizedBox(height: 16),
          // Additional action buttons
          // Row(
          //   children: [
          //     Expanded(
          //       child: OutlinedButton.icon(
          //         onPressed: service.discoveredPeers.isNotEmpty
          //             ? () async {
          //                 debugPrint('🔄 User forcing upload...');
          //                 await service.forceUpload();
          //               }
          //             : null,
          //         icon: const Icon(Icons.cloud_upload, size: 18),
          //         label: const Text('Force Upload'),
          //         style: OutlinedButton.styleFrom(
          //           padding: const EdgeInsets.symmetric(vertical: 12),
          //           shape: RoundedRectangleBorder(
          //             borderRadius: BorderRadius.circular(8),
          //           ),
          //         ),
          //       ),
          //     ),
          //     const SizedBox(width: 12),
          //     Expanded(
          //       child: OutlinedButton.icon(
          //         onPressed: service.discoveredPeers.isNotEmpty
          //             ? () {
          //                 debugPrint('🗑️ User clearing discovered peers...');
          //                 service.clearDiscoveredAppUsers();
          //               }
          //             : null,
          //         icon: const Icon(Icons.clear_all, size: 18),
          //         label: const Text('Clear All'),
          //         style: OutlinedButton.styleFrom(
          //           padding: const EdgeInsets.symmetric(vertical: 12),
          //           shape: RoundedRectangleBorder(
          //             borderRadius: BorderRadius.circular(8),
          //           ),
          //         ),
          //       ),
          //     ),
          //   ],
          // ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatusChip(
                'Bluetooth',
                service.isBluetoothEnabled ? 'ON' : 'OFF',
                service.isBluetoothEnabled ? Colors.green : Colors.red,
                Icons.bluetooth,
              ),
              const SizedBox(width: 8),
              _buildStatusChip(
                'Discovery',
                service.isActive ? 'ACTIVE' : 'STOPPED',
                service.isActive ? Colors.blue : Colors.grey,
                service.isActive ? Icons.sync : Icons.stop,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatusChip(
                'Firebase',
                _getFirebaseStatusText(service.firebaseStatus),
                _getFirebaseStatusColor(service.firebaseStatus),
                Icons.cloud,
              ),
              const SizedBox(width: 8),
              _buildStatusChip(
                'Connection',
                _getConnectionStatusText(service.connectionStatus),
                _getConnectionStatusColor(service.connectionStatus),
                Icons.signal_cellular_alt,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
      String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdIndicator(PeerDiscoveryService service) {
    final currentCount = service.appUserCount;
    final threshold = PeerDiscoveryService.PEER_THRESHOLD;
    final progress = currentCount / threshold;

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: currentCount >= threshold ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: currentCount >= threshold
              ? Colors.green[200]!
              : Colors.orange[200]!,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upload Threshold',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '$currentCount / $threshold',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: currentCount >= threshold
                      ? Colors.green[700]
                      : Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              currentCount >= threshold ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentCount >= threshold
                ? '🎉 Ready to upload to Firebase!'
                : 'Need ${threshold - currentCount} more peer${threshold - currentCount == 1 ? '' : 's'} to upload',
            style: TextStyle(
              fontSize: 12,
              color: currentCount >= threshold
                  ? Colors.green[700]
                  : Colors.orange[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveredPeers(PeerDiscoveryService service) {
    final peers = service.discoveredPeers;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Other Students',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${peers.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: peers.isEmpty
                ? _buildEmptyPeersState(service)
                : ListView.builder(
                    itemCount: peers.length,
                    itemBuilder: (context, index) {
                      final peer = peers[index];
                      return _buildPeerCard(peer, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPeersState(PeerDiscoveryService service) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            service.isActive ? Icons.search : Icons.bluetooth_searching,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            service.isActive
                ? 'Searching for students...'
                : 'No Students here yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          if (service.isActive) ...[
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeerCard(PeerData peer, int index) {
    final timeAgo = _getTimeAgo(peer.discoveredAt);
    final signalStrength = _getSignalStrength(peer.rssi);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peer.deviceName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${peer.deviceId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'Discovered $timeAgo',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadHistory(PeerDiscoveryService service) {
    final history = service.uploadHistory.take(3).toList();

    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Recent Uploads',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              Text(
                '${service.uploadHistory.length} total',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...history
              .map((session) => _buildUploadHistoryItem(session))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildUploadHistoryItem(DiscoverySession session) {
    final timeAgo = _getTimeAgo(session.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_done, size: 16, color: Colors.green[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${session.peerCount} peers uploaded',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Text(
            session.sessionId.substring(0, 8),
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _getFirebaseStatusText(String status) {
    switch (status) {
      case 'ready':
        return 'READY';
      case 'uploading':
        return 'UPLOADING';
      case 'success':
        return 'SUCCESS';
      case 'error':
        return 'ERROR';
      default:
        return status.toUpperCase();
    }
  }

  Color _getFirebaseStatusColor(String status) {
    switch (status) {
      case 'ready':
        return Colors.blue;
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

  String _getConnectionStatusText(String status) {
    switch (status) {
      case 'ready':
        return 'READY';
      case 'discovering':
        return 'DISCOVERING';
      case 'bluetooth_off':
        return 'BT OFF';
      case 'permission_denied':
        return 'NO PERMISSION';
      case 'discovery_error':
        return 'ERROR';
      default:
        return status.toUpperCase();
    }
  }

  Color _getConnectionStatusColor(String status) {
    switch (status) {
      case 'ready':
        return Colors.green;
      case 'discovering':
        return Colors.blue;
      case 'bluetooth_off':
        return Colors.orange;
      case 'permission_denied':
        return Colors.red;
      case 'discovery_error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Map<String, dynamic> _getSignalStrength(int rssi) {
    if (rssi >= -50) {
      return {'icon': Icons.signal_cellular_4_bar, 'color': Colors.green};
    } else if (rssi >= -70) {
      return {'icon': Icons.signal_cellular_0_bar, 'color': Colors.orange};
    } else if (rssi >= -85) {
      return {'icon': Icons.signal_cellular_0_bar, 'color': Colors.orange};
    } else {
      return {'icon': Icons.signal_cellular_0_bar, 'color': Colors.red};
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, HH:mm').format(dateTime);
    }
  }
}
