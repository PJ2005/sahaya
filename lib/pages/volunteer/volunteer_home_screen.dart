import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/translator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/volunteer_profile.dart';
import '../../models/task_model.dart';
import '../../theme/sahaya_theme.dart';
import '../../app.dart';
import '../../l10n/app_text.dart';
import 'task_details_screen.dart';
import 'active_task_screen.dart';
import '../../services/offline_proof_sync_service.dart';
import '../../components/skeleton_loader.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../components/logout_dialog.dart';
import 'volunteer_chat_hub_screen.dart';
import 'volunteer_notifications_screen.dart';

class VolunteerHomeScreen extends StatefulWidget {
  final String uid;
  const VolunteerHomeScreen({super.key, required this.uid});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _triggerOfflineSync();
  }

  Future<void> _triggerOfflineSync() async {
    try {
      await OfflineProofSyncService.attemptSync();
    } catch (e) {
      debugPrint("Offline Sync Trigger Error: $e");
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _updateAvailability(bool isActive, bool isPartial) async {
    try {
      await FirebaseFirestore.instance
          .collection('volunteer_profiles')
          .doc(widget.uid)
          .update({
            'availabilityWindowActive': isActive,
            'isPartialAvailability': isPartial,
            'availabilityUpdatedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: T('Availability updated!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: T('Failed: $e'),
            backgroundColor: SahayaColors.coral,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await LogoutDialog.show(context);
    if (!confirm) return;

    try {
      await FirebaseFirestore.instance
          .collection('volunteer_profiles')
          .doc(widget.uid)
          .update({'fcmToken': FieldValue.delete()});

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sahaya_offline_actions_v2');

      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: T('Logout failed: $e'), backgroundColor: SahayaColors.coral),
        );
      }
    }
  }

  Future<int> _countUnreadChats({
    required List<String> taskIds,
    required Map<String, dynamic> readByTask,
    required String uid,
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

      if (latest.docs.isEmpty) {
        continue;
      }

      final data = latest.docs.first.data();
      final senderId = (data['senderId'] as String?) ?? '';
      if (senderId == uid) {
        continue;
      }

      final ts = data['timestamp'];
      if (ts is! Timestamp) {
        continue;
      }

      final lastReadRaw = readByTask[taskId];
      DateTime? lastRead;
      if (lastReadRaw is Timestamp) {
        lastRead = lastReadRaw.toDate();
      }

      if (lastRead == null || ts.toDate().isAfter(lastRead)) {
        unread += 1;
      }
    }

    return unread;
  }

  Widget _buildBadgeIcon({
    required Widget icon,
    required int count,
  }) {
    if (count <= 0) {
      return icon;
    }

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
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: T(
          t.appName,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: -1,
          ),
        ),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('volunteer_profiles').doc(widget.uid).snapshots(),
            builder: (context, profileSnap) {
              final profileMap = profileSnap.data?.data() as Map<String, dynamic>?;
              final readByTask = profileMap?['chatReadAtByTask'] as Map<String, dynamic>? ?? <String, dynamic>{};

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tasks')
                    .where('assignedVolunteerIds', arrayContains: widget.uid)
                    .snapshots(),
                builder: (context, taskSnap) {
                  final taskIds = (taskSnap.data?.docs ?? []).map((d) => d.id).toList();
                  return FutureBuilder<int>(
                    key: ValueKey(taskIds.join('|')),
                    future: _countUnreadChats(taskIds: taskIds, readByTask: readByTask, uid: widget.uid),
                    builder: (context, unreadSnap) {
                      final unreadCount = unreadSnap.data ?? 0;
                      return IconButton(
                        icon: _buildBadgeIcon(icon: const Icon(Icons.chat_bubble_rounded), count: unreadCount),
                        tooltip: 'Chats',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VolunteerChatHubScreen(uid: widget.uid),
                            ),
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
                .collection('match_records')
                .where('volunteerId', isEqualTo: widget.uid)
                .where('status', isEqualTo: 'proof_submitted')
                .snapshots(),
            builder: (context, proofSnap) {
              final pending = proofSnap.data?.docs.length ?? 0;
              return IconButton(
                icon: _buildBadgeIcon(icon: const Icon(Icons.notifications_rounded), count: pending),
                tooltip: 'Review Pending',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VolunteerNotificationsScreen(uid: widget.uid),
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: t.toggleTheme,
            onPressed: () => themeProvider.toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.translate_rounded),
            tooltip: t.toggleLanguage,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (ctx) {
                  return ListView(
                    shrinkWrap: true,
                    children: localeProvider.supportedLanguages.map((lang) {
                      return ListTile(
                        leading: localeProvider.locale.languageCode == lang['code']
                            ? const Icon(Icons.check, color: Colors.green)
                            : const SizedBox(width: 24),
                        title: T(lang['name']!),
                        onTap: () {
                          localeProvider.setLocale(Locale(lang['code']!));
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  );
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
              future: FirebaseFirestore.instance.collection('volunteer_profiles').doc(widget.uid).get(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final name = data?['username'] ?? 'Fellow Volunteer';

                return UserAccountsDrawerHeader(
                  decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1)),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: cs.primary,
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 32),
                  ),
                  accountName: T(name, style: GoogleFonts.inter(color: cs.onSurface, fontWeight: FontWeight.w700)),
                  accountEmail: T('Sahaya Volunteer Account', style: GoogleFonts.inter(color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted, fontSize: 12)),
                );
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('volunteer_profiles').doc(widget.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: T('Profile not found.'));
          }

          final profile = VolunteerProfile.fromJson(snapshot.data!.data() as Map<String, dynamic>);
          final bool windowActive = profile.availabilityWindowActive;
          final bool isStale = DateTime.now().difference(profile.availabilityUpdatedAt).inDays >= 7;

          if (!windowActive || isStale) return _buildCheckInPrompt(context);
          return _buildDashboard(context, profile);
        },
      ),
    );
  }

  Widget _buildCheckInPrompt(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(28)),
              child: Icon(Icons.event_available_rounded, size: 44, color: cs.primary),
            ),
            const SizedBox(height: 32),
            T('Available this\nweekend?', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -1)),
            const SizedBox(height: 12),
            T('Help your community — we\'ll match you with\nnearby tasks based on your skills.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 15, color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted, height: 1.5)),
            const SizedBox(height: 44),
            ScaleTransition(
              scale: _pulseAnimation,
              child: SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: () => _updateAvailability(true, false), child: T('Yes, I\'m available'))),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 56, child: OutlinedButton(onPressed: () => _updateAvailability(true, true), child: T('Partially — a few hours'))),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _updateAvailability(false, false),
              style: TextButton.styleFrom(foregroundColor: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted),
              child: T('Not this time'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, VolunteerProfile profile) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // ─── Status Hero ───
          _buildHero(profile),
          const SizedBox(height: 16),

          // ─── Tab Bar ───
          _buildTabBar(context),
          const SizedBox(height: 8),

          Expanded(
            child: TabBarView(
              children: [
                _buildAvailableTab(profile),
                _buildMyMissionsTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(VolunteerProfile profile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? [const Color(0xFF1E293B), const Color(0xFF0F172A)] : [const Color(0xFF111827), const Color(0xFF1F2937)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.workspace_premium_rounded, color: SahayaColors.coral, size: 22),
                  const SizedBox(width: 8),
                  T(profile.trustScore > 100 ? 'Community Leader' : 'Volunteer', style: GoogleFonts.inter(color: SahayaColors.coral, fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 8),
                T('You\'re checked in', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                T('${profile.tasksCompleted} Missions • ${profile.trustScore} XP', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                Icon(Icons.circle, size: 8, color: cs.primary),
                const SizedBox(width: 6),
                T(profile.isPartialAvailability ? 'Partial' : 'Active', style: GoogleFonts.inter(color: cs.primary, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: isDark ? SahayaColors.darkSurface : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(14)),
      child: TabBar(
        indicator: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]),
        labelColor: cs.onSurface,
        unselectedLabelColor: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: const [Tab(child: T('Available')), Tab(child: T('My Missions')), Tab(child: T('History'))],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  TAB LOGIC
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildAvailableTab(VolunteerProfile profile) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('tasks').where('status', isEqualTo: 'open').snapshots(),
      builder: (context, taskSnapshot) {
        if (taskSnapshot.hasError) return _emptyState(icon: Icons.error_outline_rounded, title: 'Discovery Error', subtitle: 'Could not reach community central.');
        if (taskSnapshot.connectionState == ConnectionState.waiting) return _skeleton();

        if (!taskSnapshot.hasData || taskSnapshot.data!.docs.isEmpty) {
          return _emptyState(icon: Icons.radar_rounded, title: 'No missions nearby', subtitle: 'Stay tuned! New tasks appear as needs arise.');
        }

        final availableTasks = taskSnapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Map document ID to model ID correctly
          return TaskModel.fromJson(data);
        }).where((t) => !t.assignedVolunteerIds.contains(widget.uid)).toList();

        final scored = availableTasks.map((task) {
          final scoreData = _calculateDynamicScore(task, profile);
          return {'task': task, 'score': scoreData['score'] as int, 'why': scoreData['why'] as String};
        }).toList();

        scored.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: scored.length,
          itemBuilder: (context, i) {
            final m = scored[i];
            return MissionCard(
              task: m['task'] as TaskModel,
              matchRecordId: '',
              matchScore: m['score'] as int,
              isAccepted: false,
              whyMatched: m['why'] as String,
            );
          },
        );
      },
    );
  }

  Widget _buildMyMissionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('assignedVolunteerIds', arrayContains: widget.uid)
          .snapshots(),
      builder: (context, taskSnap) {
        if (taskSnap.connectionState == ConnectionState.waiting) return _skeleton();
        final taskDocs = taskSnap.data?.docs ?? [];
        if (taskDocs.isEmpty) {
          return _emptyState(
            icon: Icons.assignment_rounded,
            title: 'No active missions',
            subtitle: 'Join missions from the Available tab.',
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('match_records')
              .where('volunteerId', isEqualTo: widget.uid)
              .snapshots(),
          builder: (context, matchSnap) {
            if (matchSnap.connectionState == ConnectionState.waiting) return _skeleton();

            final matchDocs = matchSnap.data?.docs ?? [];
            final Map<String, QueryDocumentSnapshot> matchByTaskId = {};
            for (final m in matchDocs) {
              final data = m.data() as Map<String, dynamic>;
              final taskId = data['taskId'] as String?;
              if (taskId != null && taskId.isNotEmpty) {
                matchByTaskId[taskId] = m;
              }
            }

            final activeTaskDocs = taskDocs.where((doc) {
              final taskMap = doc.data() as Map<String, dynamic>;
              final taskStatus = (taskMap['status'] as String?) ?? 'open';
              if (taskStatus == 'done') return false;

              final matchDoc = matchByTaskId[doc.id];
              if (matchDoc == null) {
                // Fallback: assigned task without a visible match record should still be shown.
                return true;
              }
              final matchMap = matchDoc.data() as Map<String, dynamic>;
              final matchStatus = (matchMap['status'] as String?) ?? '';
              return matchStatus == 'accepted' ||
                  matchStatus == 'proof_submitted' ||
                  matchStatus == 'proof_rejected' ||
                  matchStatus == 'open' ||
                  matchStatus == 'assigned';
            }).toList();

            if (activeTaskDocs.isEmpty) {
              return _emptyState(
                icon: Icons.assignment_rounded,
                title: 'No active missions',
                subtitle: 'Join missions from the Available tab.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: activeTaskDocs.length,
              itemBuilder: (context, i) {
                final doc = activeTaskDocs[i];
                final taskMap = doc.data() as Map<String, dynamic>;
                taskMap['id'] = doc.id;
                final task = TaskModel.fromJson(taskMap);
                final matchDoc = matchByTaskId[doc.id];
                final matchMap = matchDoc?.data() as Map<String, dynamic>?;

                return MissionCard(
                  task: task,
                  matchRecordId: matchDoc?.id ?? '',
                  matchScore: (matchMap?['matchScore'] as num?)?.toInt() ?? 0,
                  isAccepted: true,
                  whyMatched: (matchMap?['whyMatched'] as String?) ?? '',
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('match_records').where('volunteerId', isEqualTo: widget.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _skeleton();
        final docs = snapshot.data?.docs ?? [];
        final history = docs.where((d) => d['status'] == 'proof_approved').toList();

        if (history.isEmpty) return _emptyState(icon: Icons.history_rounded, title: 'No history', subtitle: 'Your completed tasks will appear here.');

        return _missionList(history, isAccepted: true, isHistory: true);
      },
    );
  }

  Widget _missionList(List<QueryDocumentSnapshot> docs, {required bool isAccepted, bool isHistory = false}) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final d = docs[i].data() as Map<String, dynamic>;
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('tasks').doc(d['taskId']).get(),
          builder: (context, taskSnap) {
              if (!taskSnap.hasData || !taskSnap.data!.exists) {
                return _archivedMissionCard(d);
              }
            final task = TaskModel.fromJson(taskSnap.data!.data() as Map<String, dynamic>);
            return MissionCard(
              task: task,
              matchRecordId: docs[i].id,
              matchScore: (d['matchScore'] as num?)?.toInt() ?? 0,
              isAccepted: isAccepted,
              isHistory: isHistory,
              whyMatched: d['whyMatched'] ?? '',
            );
          },
        );
      },
    );
  }

  Widget _archivedMissionCard(Map<String, dynamic> matchData) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final briefing = (matchData['missionBriefing'] as String?)?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? SahayaColors.darkBorder : SahayaColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: T(
                  briefing?.isNotEmpty == true
                      ? briefing!
                      : 'Mission details unavailable',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          T(
            'This mission is still linked to your record, but task details are currently unavailable.',
            style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _skeleton() => ListView.builder(itemCount: 3, padding: const EdgeInsets.all(20), itemBuilder: (context, i) => const SkeletonMissionCard());

  Widget _emptyState({required IconData icon, required String title, required String subtitle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 48, color: isDark ? SahayaColors.darkBorder : const Color(0xFFD1D5DB)),
        const SizedBox(height: 16),
        T(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        T(subtitle, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted)),
      ]),
    ));
  }

  Map<String, dynamic> _calculateDynamicScore(TaskModel task, VolunteerProfile profile) {
    final taskSkills = task.skillTags.map((s) => s.toLowerCase()).toSet();
    final volSkills = profile.skillTags.map((s) => s.toLowerCase()).toSet();
    final overlap = taskSkills.intersection(volSkills).length;
    double skillScore = taskSkills.isEmpty ? 60 : (overlap / taskSkills.length) * 60;

    final taskGeo = task.locationGeoPoint;
    double dist = 0;
    if (taskGeo != null) {
      dist = Geolocator.distanceBetween(
        profile.locationGeoPoint.latitude, profile.locationGeoPoint.longitude,
        taskGeo.latitude, taskGeo.longitude,
      ) / 1000.0;
    }

    double proxScore = 0;
    if (taskGeo == null) {
      proxScore = 20; // Default if no location info
    } else if (dist <= profile.radiusKm) {
      proxScore = 40;
    } else {
      proxScore = (profile.radiusKm / dist).clamp(0, 1) * 40;
    }

    String why = overlap > 0 ? 'Matches $overlap skills' : 'General support';
    if (taskGeo != null && dist <= profile.radiusKm) why += ' • Nearby';
    
    return {'score': (skillScore + proxScore).round().clamp(10, 99), 'why': why};
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  MISSION CARD
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class MissionCard extends StatelessWidget {
  final TaskModel task;
  final String matchRecordId;
  final int matchScore;
  final bool isAccepted;
  final bool isHistory;
  final String whyMatched;

  const MissionCard({
    super.key,
    required this.task,
    required this.matchRecordId,
    required this.matchScore,
    required this.isAccepted,
    this.isHistory = false,
    this.whyMatched = '',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (isAccepted) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ActiveTaskScreen(
              matchRecordId: matchRecordId,
              task: task,
              // NGO info will be fetched by ActiveTaskScreen itself
              ngoName: null, 
              ngoPhone: null,
              ngoEmail: null,
            ),
          ));
        } else {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => TaskDetailsScreen(
              taskId: task.id,
              matchRecordId: matchRecordId,
              initialTask: task,
              matchScore: matchScore,
              whatToBring: 'Basic supplies',
              whyMatched: whyMatched,
              isAlreadyAccepted: isAccepted,
            ),
          ));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isAccepted ? cs.primary.withValues(alpha: 0.3) : (isDark ? SahayaColors.darkBorder : SahayaColors.lightBorder)),
          boxShadow: [sahayaCardShadow(context)],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: isAccepted ? cs.primary.withValues(alpha: 0.1) : (isDark ? SahayaColors.darkSurface : const Color(0xFFF3F4F6)), borderRadius: BorderRadius.circular(14)),
              child: Icon(isHistory ? Icons.verified_rounded : (isAccepted ? Icons.run_circle_rounded : Icons.assignment_outlined), color: isHistory ? SahayaColors.emerald : (isAccepted ? cs.primary : cs.onSurface.withValues(alpha: 0.5))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                T(task.description, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.location_on_outlined, size: 12, color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted),
                  const SizedBox(width: 4),
                  T(task.locationWard, style: GoogleFonts.inter(fontSize: 12, color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted)),
                ]),
              ],
            )),
            const SizedBox(width: 10),
            _buildBadge(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (isHistory) return T('Done', style: GoogleFonts.inter(color: SahayaColors.emerald, fontWeight: FontWeight.bold));
    return Column(children: [
      T('$matchScore%', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: cs.primary)),
      T('MATCH', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: cs.primary, letterSpacing: 0.5)),
    ]);
  }
}

class _MarqueeText extends StatefulWidget {
  final String text;
  const _MarqueeText({required this.text});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late double _textWidth;
  static const double _gap = 32.0;

  @override
  void initState() {
    super.initState();
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: _style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    _textWidth = tp.size.width;

    final ms = ((_textWidth + _gap) * 50).toInt().clamp(2000, 8000);
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    )..repeat();
  }

  TextStyle get _style => GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalWidth = _textWidth + _gap;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final offset = _ctrl.value * totalWidth;
        return ClipRect(
          child: OverflowBox(
            maxWidth: double.infinity,
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: Offset(-offset, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  T(widget.text, style: _style, maxLines: 1),
                  const SizedBox(width: _gap),
                  T(widget.text, style: _style, maxLines: 1),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
