import 'package:ble_firebase_app/screen/peer_discovery.dart';
import 'package:ble_firebase_app/services/peer_discovery.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PeerDiscoveryService(),
      child: MaterialApp(
        title: 'Peer Discovery',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: PeerDiscoveryScreen(),
      ),
    );
  }
}
