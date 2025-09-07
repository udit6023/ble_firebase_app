import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/peer_data.dart';
import '../services/peer_discovery.dart';
import '../studentApi.dart';

class AttendanceScreen extends StatefulWidget {
  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {

  // 📚 Define subjects dynamically

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<PeerDiscoveryService>().fetchRoster();
      context.read<PeerDiscoveryService>().intializePeerMap();
    });
    //initialize maps for each subject
  }

  Future<void> startAttendance(String course,PeerDiscoveryService service,) async {
    print("course id:${course}");
      service.strtAttendence=true;
      service.peerCounts[course]=1;
    await service.startDiscovery(service.studentList['students'][0]['name'],service.studentList['students'][0]['student_id']);
    // Mock peer names
      service.strtAttendence=false;
  }

  Widget buildCourseCard(PeerDiscoveryService service,{
    required String courseId,
    required String title,
    required String time,}){
    // final peerList = peers[courseId] ?? [];
    final isStarted = service.peerCounts[courseId]! > 0;
    List<PeerData> samplePeers = service.discoveredPeers;
    print("samplePeers:${service.peerCounts}");
    return Card(
      margin: EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text("Time: $time"),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              child: Text("Attendance Open (05:00)",
                  style: TextStyle(color: Colors.green.shade800, fontSize: 14)),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: (!service.strtAttendence)?
                  () async{
               startAttendance(courseId,service);
              }:null,
              style: ElevatedButton.styleFrom(
                backgroundColor:Colors.blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                minimumSize: Size(double.infinity, 48),
              ),
              child: Text("Start Attendance",style: TextStyle(color: Colors.white),),
            ),
            if (samplePeers.isNotEmpty && isStarted) ...[
              SizedBox(height: 20),
              Center(
                  child: Text(
                      "Finding classmates nearby: ${service.peerCounts[courseId]}/5 verified")),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children:[
         ..._buildAvatar(samplePeers),
    ]
                // List.generate(0, (i) {
                //   if (i < samplePeers.length) {
                //     return _buildAvatar(samplePeers[i]);
                //   } else {
                //     return _buildAvatar(null);
                //   }
                // }),
              ),
              SizedBox(height: 10),
              Center(
                child: Text(
                  samplePeers.length < 5
                      ? "Scanning classroom beacon..."
                      : "Beacon Detected",
                  style: TextStyle(
                      color:
                      samplePeers.length < 5 ? Colors.black54 : Colors.green,
                      fontWeight:FontWeight.normal),
                ),
              ),
              if(samplePeers.length==5)
               Center(
                child: Text(
                   "Attendence Marked ✅",
                  style: TextStyle(
                      color:
                      samplePeers.length < 5 ? Colors.black54 : Colors.green,
                      fontWeight: samplePeers.length < 5
                          ? FontWeight.normal
                          : FontWeight.bold),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  List<Container> _buildAvatar(List<PeerData?> text) {
    print("tessstt:${text}");
    return List.generate(text.length, (i){
     return Container(
        margin: EdgeInsets.symmetric(horizontal: 6),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: (text!=null)?Text(
          text[i]!.deviceName,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ):Container(),
      );
    });

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
      AppBar(title: Text("Mark Attendance",style: TextStyle(fontSize: 18),), backgroundColor: Colors.blue),
      body: Consumer<PeerDiscoveryService>(
        builder: (context, service, child) {

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: service.subjects.length,
            itemBuilder: (context, index) {
              final subject = service.subjects[index];
              return buildCourseCard(
                service,
                courseId: subject["id"]!,
                title: subject["title"]!,
                time: subject["time"]!,
              );
            },
          );
        },
      ),
    );
  }
}
