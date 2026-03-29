import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'upload_screen.dart';
import 'review_queue_screen.dart';
import 'ngo_home_screen.dart';

class NgoDashboard extends StatefulWidget {
  final String ngoId;
  const NgoDashboard({super.key, required this.ngoId});

  @override
  State<NgoDashboard> createState() => _NgoDashboardState();
}

class _NgoDashboardState extends State<NgoDashboard> {
  int _currentIndex = 0;
  late final List<Widget> _children;

  @override
  void initState() {
    super.initState();
    _children = [
      NgoHomeScreen(ngoId: widget.ngoId),
      UploadScreen(ngoId: widget.ngoId),
      ReviewQueueScreen(ngoId: widget.ngoId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _children[_currentIndex],
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('problem_cards')
            .where('ngoId', isEqualTo: widget.ngoId)
            .where('status', isEqualTo: 'pending_review')
            .snapshots(),
        builder: (context, snapshot) {
          final pendingCount = snapshot.data?.docs.length ?? 0;

          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: Colors.blueAccent,
            unselectedItemColor: Colors.black45,
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
              const BottomNavigationBarItem(icon: Icon(Icons.cloud_upload), label: 'Ingestion'),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text('$pendingCount', style: const TextStyle(fontSize: 10)),
                  child: const Icon(Icons.fact_check),
                ),
                label: 'Review',
              ),
            ],
          );
        },
      ),
    );
  }
}
