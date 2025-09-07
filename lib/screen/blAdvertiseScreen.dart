import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BleScreen extends StatefulWidget {
  @override
  _BleScreenState createState() => _BleScreenState();
}

class _BleScreenState extends State<BleScreen> {
  final MethodChannel advertiseChannel = MethodChannel('ble_advertise');
  final MethodChannel scanChannel = MethodChannel('ble_scan');
  final EventChannel scanEventChannel = EventChannel("com.example.ble_firebase_app/ble_scan_updates");
  static const MethodChannel _channel = MethodChannel('com.example.ble_firebase_app/peripheral');
  List<Map<String, dynamic>> scannedDevices = [];
  static StreamSubscription? scanSubscription;

  @override
  void initState(){
    super.initState();
    scanSubscription=scanEventChannel.receiveBroadcastStream().listen((dynamic event) {
      print("scanned data we got:${event}");
      if (event is Map) {
        final device = {
          'name': event['name'] ?? 'Unknown',
          'address': event['address'] ?? 'Unknown'
        };
        setState(() {
          // avoid duplicates
          if (!scannedDevices.any((d) => d['address'] == device['address'])) {
            scannedDevices.add(device);
          }
        });
      }
    });
    // Listen for scan results from native side
  }
  void getScannedData(){
    print("got inside here");
   scanSubscription=scanEventChannel.receiveBroadcastStream().listen((dynamic event) {
      print("scanned data we got:${event}");
      if (event is Map) {
        final device = {
          'name': event['name'] ?? 'Unknown',
          'address': event['address'] ?? 'Unknown'
        };
        setState(() {
          // avoid duplicates
          if (!scannedDevices.any((d) => d['address'] == device['address'])) {
            scannedDevices.add(device);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("BLE Advertise & Scan")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Advertising Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if(Platform.isAndroid) {
                        advertiseChannel.invokeMethod('startAdvertising');
                      }else{
                        _channel.invokeMethod('startAdvertising');
                      }
      },
                    child: Text("Start Advertising"),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (){
                      if(Platform.isAndroid) {
                        advertiseChannel.invokeMethod('stopAdvertising');
                      }else{
                        _channel.invokeMethod('stopAdvertising');
                      }
    setState(() {
      scannedDevices.clear();
    });
    } ,
                    child: Text("Stop Advertising"),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            // Scanning Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
         scanChannel.invokeMethod('startScanning');
         getScannedData();
         },child: Text("Start Scanning"),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
    scanChannel.invokeMethod('stopScanning');
    setState(() {
    scannedDevices.clear();
    scanSubscription?.cancel();
    scanSubscription=null;
    });
    } ,
                    child: Text("Stop Scanning"),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              "Scanned Devices",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Divider(),
            // List of scanned devices
            Expanded(
              child: scannedDevices.isEmpty
                  ? Center(child: Text("No devices found yet"))
                  : ListView.builder(
                itemCount: scannedDevices.length,
                itemBuilder: (context, index) {
                  final device = scannedDevices[index];
                  return ListTile(
                    leading: Icon(Icons.bluetooth),
                    title: Text(device['name']!),
                    subtitle: Text(device['address']!),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // floatingActionButton: FloatingActionButton(onPressed: (){
      //   getScannedData();
      // },child: Icon(CupertinoIcons.antenna_radiowaves_left_right),),
    );
  }
}
