import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
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
  StreamSubscription<QuerySnapshot>? _proofNotificationSubscription;
  final Set<String> _shownNotificationIds = <String>{};
  int _lastPendingProofCount = 0;

  @override
  void initState() {
    super.initState();
    _children = [
      NgoHomeScreen(ngoId: widget.ngoId),
      UploadScreen(ngoId: widget.ngoId),
      ReviewQueueScreen(ngoId: widget.ngoId),
      NgoImpactDashboardScreen(ngoId: widget.ngoId),
    ];
    _listenForProofNotifications();
  }

  @override
  void dispose() {
    _proofNotificationSubscription?.cancel();
    super.dispose();
  }

  void _listenForProofNotifications() {
    _proofNotificationSubscription = FirebaseFirestore.instance
        .collection('ngo_notifications')
        .where('ngoId', isEqualTo: widget.ngoId)
        .where('type', isEqualTo: 'proof_submitted')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          final docs = snapshot.docs;
          final count = docs.length;
          final hasNewNotification = docs.any(
            (doc) => !_shownNotificationIds.contains(doc.id),
          );

          for (final doc in docs) {
            _shownNotificationIds.add(doc.id);
          }

          if (count > 0 &&
              hasNewNotification &&
              count >= _lastPendingProofCount) {
            _showPendingApprovalsBanner(count);
          }

          _lastPendingProofCount = count;
        });
  }

  void _showPendingApprovalsBanner(int count) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(
          count == 1
              ? '1 task is waiting for proof approval.'
              : '$count tasks are waiting for proof approval.',
        ),
        leading: const Icon(Icons.fact_check_outlined),
        actions: [
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: const Text('DISMISS'),
          ),
        ],
      ),
    );

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    });
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
                  label: Text(
                    '$pendingCount',
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.rate_review_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text(
                    '$pendingCount',
                    style: const TextStyle(fontSize: 10),
                  ),
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
