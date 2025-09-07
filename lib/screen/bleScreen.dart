import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bleProvider = Provider.of<BleProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Nearby Devices")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: bleProvider.devices.length,
              itemBuilder: (context, index) {
                final device = bleProvider.devices[index];
                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(device.name),
                  subtitle: Text("ID: ${device.id}\nRSSI: ${device.rssi}"),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: bleProvider.scanning
          ? null
          : () => bleProvider.startScan(),child: Icon(CupertinoIcons.antenna_radiowaves_left_right,color: Colors.cyan,),),
    );
  }
}
