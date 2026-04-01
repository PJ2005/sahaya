import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'upload_screen.dart';
import 'review_queue_screen.dart';
import 'ngo_home_screen.dart';
import 'ngo_impact_dashboard_screen.dart';

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
      NgoImpactDashboardScreen(ngoId: widget.ngoId),
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
            .where('status', whereIn: ['pending_review', 'extraction_failed'])
            .snapshots(),
        builder: (context, snapshot) {
          final pendingCount = snapshot.data?.docs.length ?? 0;

          return NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            height: 72,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Dashboard',
              ),
              const NavigationDestination(
                icon: Icon(Icons.add_circle_outline_rounded),
                selectedIcon: Icon(Icons.add_circle_rounded),
                label: 'Upload',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text('$pendingCount', style: const TextStyle(fontSize: 10)),
                  child: const Icon(Icons.rate_review_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text('$pendingCount', style: const TextStyle(fontSize: 10)),
                  child: const Icon(Icons.rate_review_rounded),
                ),
                label: 'Review',
              ),
              const NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded),
                label: 'Impact',
              ),
            ],
          );
        },
      ),
    );
  }
}
