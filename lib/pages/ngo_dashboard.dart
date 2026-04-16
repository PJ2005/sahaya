import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'upload_screen.dart';
import 'review_queue_screen.dart';
import 'ngo_home_screen.dart';
import 'ngo_impact_dashboard_screen.dart';
import 'ngo_heatmap_screen.dart';
import 'proof_review_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../components/logout_dialog.dart';
import '../theme/sahaya_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/translator.dart';
import 'ngo_volunteer_monitor_screen.dart';
import 'ngo_chat_hub_screen.dart';
import 'ngo_notifications_screen.dart';


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
  Timer? _proofBannerTimer;
  final Set<String> _shownNotificationIds = <String>{};
  int _lastPendingProofCount = 0;

  bool _isUnreadProofNotification(Map<String, dynamic> data) {
    return data['type'] == 'proof_submitted' && data['read'] == false;
  }

  bool _isReviewQueueCard(Map<String, dynamic> data) {
    final status = data['status'];
    return status == 'pending_review' || status == 'extraction_failed';
  }

  @override
  void initState() {
    super.initState();
    _children = [
      NgoHomeScreen(ngoId: widget.ngoId),
      UploadScreen(ngoId: widget.ngoId),
      ReviewQueueScreen(ngoId: widget.ngoId),
      NgoImpactDashboardScreen(ngoId: widget.ngoId),
      NgoHeatmapScreen(ngoId: widget.ngoId),
    ];
    _listenForProofNotifications();
  }

  @override
  void dispose() {
    _proofNotificationSubscription?.cancel();
    _proofBannerTimer?.cancel();
    super.dispose();
  }

  void _listenForProofNotifications() {
    _proofNotificationSubscription = FirebaseFirestore.instance
        .collection('ngo_notifications')
        .where('ngoId', isEqualTo: widget.ngoId)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          final docs = snapshot.docs.where((doc) {
            final data = doc.data();
            return _isUnreadProofNotification(data);
          }).toList();
          final count = docs.length;

          // Count genuinely new IDs we haven't shown before
          int newCount = 0;
          for (final doc in docs) {
            if (_shownNotificationIds.add(doc.id)) {
              newCount++;
            }
          }

          // Only show banner if there are genuinely new notifications
          if (newCount > 0 && count > 0) {
            _showPendingApprovalsBanner(count);
          }

          // Hide banner when all notifications are handled
          if (count == 0 && _lastPendingProofCount > 0) {
            ScaffoldMessenger.of(context).clearSnackBars();
          }

          _lastPendingProofCount = count;
        });
  }

  void _showPendingApprovalsBanner(int count) {
    if (!mounted) return;
    
    final messenger = ScaffoldMessenger.of(context);
    _proofBannerTimer?.cancel();
    messenger.clearSnackBars(); // remove any existing
    
    final controller = messenger.showSnackBar(
      SnackBar(
        content: T(
          count == 1
              ? '1 task is waiting for proof approval.'
              : '$count tasks are waiting for proof approval.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20), // Float it above the navbar
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 4),
        backgroundColor: Theme.of(context).colorScheme.primary,
        action: SnackBarAction(
          label: 'REVIEW',
          textColor: Colors.white,
          onPressed: () {
            messenger.clearSnackBars();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProofReviewScreen(ngoId: widget.ngoId))
            );
          },
        ),
      ),
    );

    // Force close in case platform accessibility settings keep action snackbars open.
    _proofBannerTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        controller.close();
      }
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await LogoutDialog.show(context);
    if (!confirm) return;

    try {
      // 1. Clear FCM token from profiles to prevent ghost notifications
      await FirebaseFirestore.instance
          .collection('ngo_profiles')
          .doc(widget.ngoId)
          .update({'fcmToken': FieldValue.delete()});

      // 2. Sign out (AuthGateway handles redirection)
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: T('Logout failed: $e'), backgroundColor: SahayaColors.coral),
        );
      }
    }
  }

  Future<int> _countUnreadNgoChats({
    required List<String> taskIds,
    required Map<String, dynamic> readByTask,
  }) async {
    int unread = 0;
    for (final taskId in taskIds) {
      final latest = await FirebaseFirestore.instance
          .collection('task_chats')
          .doc(taskId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (latest.docs.isEmpty) continue;
      final data = latest.docs.first.data();
      final senderId = (data['senderId'] as String?) ?? '';
      if (senderId == widget.ngoId) continue;

      final ts = data['timestamp'];
      if (ts is! Timestamp) continue;

      DateTime? lastRead;
      final raw = readByTask[taskId];
      if (raw is Timestamp) {
        lastRead = raw.toDate();
      }

      if (lastRead == null || ts.toDate().isAfter(lastRead)) {
        unread += 1;
      }
    }
    return unread;
  }

  Widget _buildBadgeIcon({required Widget icon, required int count}) {
    if (count <= 0) return icon;
    final label = count > 99 ? '99+' : '$count';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: T('Sahaya NGO', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        centerTitle: false,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('ngo_profiles').doc(widget.ngoId).snapshots(),
            builder: (context, ngoProfileSnap) {
              final profileMap = ngoProfileSnap.data?.data() as Map<String, dynamic>?;
              final readByTask = profileMap?['chatReadAtByTask'] as Map<String, dynamic>? ?? <String, dynamic>{};

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('problem_cards')
                    .where('ngoId', isEqualTo: widget.ngoId)
                    .snapshots(),
                builder: (context, cardSnap) {
                  final cardIds = (cardSnap.data?.docs ?? []).map((d) => d.id).toList();
                  if (cardIds.isEmpty) {
                    return IconButton(
                      icon: const Icon(Icons.chat_bubble_rounded),
                      tooltip: 'Chats',
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => NgoChatHubScreen(ngoId: widget.ngoId)));
                      },
                    );
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('tasks')
                        .where('problemCardId', whereIn: cardIds.take(30).toList())
                        .snapshots(),
                    builder: (context, taskSnap) {
                      final taskIds = (taskSnap.data?.docs ?? []).map((d) => d.id).toList();
                      return FutureBuilder<int>(
                        key: ValueKey(taskIds.join('|')),
                        future: _countUnreadNgoChats(taskIds: taskIds, readByTask: readByTask),
                        builder: (context, unreadSnap) {
                          final unread = unreadSnap.data ?? 0;
                          return IconButton(
                            icon: _buildBadgeIcon(icon: const Icon(Icons.chat_bubble_rounded), count: unread),
                            tooltip: 'Chats',
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => NgoChatHubScreen(ngoId: widget.ngoId)));
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('ngo_notifications')
                .where('ngoId', isEqualTo: widget.ngoId)
                .snapshots(),
            builder: (context, pendingSnap) {
              final pending = (pendingSnap.data?.docs ?? const []).where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _isUnreadProofNotification(data);
              }).length;
              return IconButton(
                icon: _buildBadgeIcon(icon: const Icon(Icons.notifications_rounded), count: pending),
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => NgoNotificationsScreen(ngoId: widget.ngoId)));
                },
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
        child: Column(
          children: [
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('ngo_profiles').doc(widget.ngoId).get(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final name = data?['name'] ?? 'NGO Admin';
                final email = data?['email'] ?? 'admin@sahaya.org';

                return UserAccountsDrawerHeader(
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                  ),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: cs.primary,
                    child: const Icon(Icons.business_rounded, color: Colors.white, size: 32),
                  ),
                  accountName: T(name, style: GoogleFonts.inter(color: cs.onSurface, fontWeight: FontWeight.w700)),
                  accountEmail: T(email, style: GoogleFonts.inter(color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted, fontSize: 13)),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.people_rounded, color: cs.primary),
              title: T('Volunteer Monitor', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => NgoVolunteerMonitorScreen(ngoId: widget.ngoId)));
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: ListTile(
                onTap: _handleLogout,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: SahayaColors.coral.withValues(alpha: 0.1),
                leading: const Icon(Icons.logout_rounded, color: SahayaColors.coral),
                title: T('Log Out', style: GoogleFonts.inter(color: SahayaColors.coral, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
      body: _children[_currentIndex],
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('problem_cards')
            .where('ngoId', isEqualTo: widget.ngoId)
            .snapshots(),
        builder: (context, snapshot) {
          final pendingCount = (snapshot.data?.docs ?? const []).where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _isReviewQueueCard(data);
          }).length;

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
                  label: T(
                    '$pendingCount',
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.rate_review_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: T(
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
              const NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded),
                label: 'Heatmap',
              ),
            ],
          );
        },
      ),
    );
  }
}
