import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/volunteer_profile.dart';
import '../../models/task_model.dart';
import '../../theme/sahaya_theme.dart';
import '../../app.dart';
import 'task_details_screen.dart';
import 'active_task_screen.dart';

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
            content: const Text('Availability updated!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: SahayaColors.coral,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sahaya',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: -1,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            onPressed: () => themeProvider.toggle(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('volunteer_profiles')
            .doc(widget.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: cs.primary));
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(child: Text('Profile not found.'));
          }

          final profileMap = snapshot.data!.data() as Map<String, dynamic>;
          final profile = VolunteerProfile.fromJson(profileMap);
          final bool windowActive = profile.availabilityWindowActive;
          final DateTime updatedAt = profile.availabilityUpdatedAt;
          final bool isStale = DateTime.now().difference(updatedAt).inDays >= 7;

          if (!windowActive || isStale) {
            return _buildCheckInPrompt(context);
          }
          return _buildDashboard(context, profile);
        },
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  CHECK-IN PROMPT
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildCheckInPrompt(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.event_available_rounded,
                size: 44,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Available this\nweekend?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -1,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Help your community — we\'ll match you with\nnearby tasks based on your skills.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: isDark
                    ? SahayaColors.darkMuted
                    : SahayaColors.lightMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 44),

            // Yes
            ScaleTransition(
              scale: _pulseAnimation,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _updateAvailability(true, false),
                  child: const Text('Yes, I\'m available'),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Partially
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () => _updateAvailability(true, true),
                child: const Text('Partially — a few hours'),
              ),
            ),
            const SizedBox(height: 12),

            // No
            SizedBox(
              width: double.infinity,
              height: 56,
              child: TextButton(
                onPressed: () => _updateAvailability(false, false),
                style: TextButton.styleFrom(
                  foregroundColor: isDark
                      ? SahayaColors.darkMuted
                      : SahayaColors.lightMuted,
                ),
                child: const Text('Not this time'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  MAIN DASHBOARD
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildDashboard(BuildContext context, VolunteerProfile profile) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // ─── Status Hero ───
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFF111827), const Color(0xFF1F2937)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You\'re checked in',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Matching you with nearby tasks',
                          style: GoogleFonts.inter(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: cs.primary),
                        const SizedBox(width: 6),
                        Text(
                          profile.isPartialAvailability ? 'Partial' : 'Active',
                          style: GoogleFonts.inter(
                            color: cs.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Tab Bar ───
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? SahayaColors.darkSurface
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: cs.onSurface,
              unselectedLabelColor: isDark
                  ? SahayaColors.darkMuted
                  : SahayaColors.lightMuted,
              labelStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(child: _MarqueeText(text: 'Available')),
                Tab(child: _MarqueeText(text: 'My Missions')),
                Tab(child: _MarqueeText(text: 'History')),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ─── Tab Body ───
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('match_records')
                  .where('volunteerId', isEqualTo: widget.uid)
                  .snapshots(),
              builder: (context, matchSnapshot) {
                if (matchSnapshot.hasError) {
                  return Center(child: Text('Error: ${matchSnapshot.error}'));
                }
                if (matchSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: cs.primary),
                  );
                }
                if (!matchSnapshot.hasData ||
                    matchSnapshot.data!.docs.isEmpty) {
                  return _emptyState(
                    icon: Icons.radar_rounded,
                    title: 'Scanning for tasks',
                    subtitle: 'We\'ll notify you when there\'s a match nearby.',
                  );
                }

                final allDocs = matchSnapshot.data!.docs.toList();

                final acceptedDocs = allDocs.where((d) {
                  final s =
                      (d.data() as Map<String, dynamic>)['status'] as String? ??
                      '';
                  return s == 'accepted' ||
                      s == 'proof_submitted' ||
                      s == 'proof_rejected';
                }).toList()..sort(_byScoreDesc);

                final openDocs = allDocs.where((d) {
                  final s =
                      (d.data() as Map<String, dynamic>)['status'] as String? ??
                      '';
                  return s == 'open';
                }).toList()..sort(_byScoreDesc);

                final historyDocs = allDocs.where((d) {
                  final s =
                      (d.data() as Map<String, dynamic>)['status'] as String? ??
                      '';
                  return s == 'proof_approved';
                }).toList()..sort(_byScoreDesc);

                return TabBarView(
                  children: [
                    _missionList(openDocs, isAccepted: false),
                    _missionList(acceptedDocs, isAccepted: true),
                    _missionList(
                      historyDocs,
                      isAccepted: true,
                      isHistory: true,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int _byScoreDesc(QueryDocumentSnapshot a, QueryDocumentSnapshot b) {
    final aS =
        ((a.data() as Map<String, dynamic>)['matchScore'] as num?)
            ?.toDouble() ??
        0;
    final bS =
        ((b.data() as Map<String, dynamic>)['matchScore'] as num?)
            ?.toDouble() ??
        0;
    return bS.compareTo(aS);
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 56,
            color: isDark ? SahayaColors.darkBorder : const Color(0xFFD1D5DB),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _missionList(
    List<QueryDocumentSnapshot> docs, {
    required bool isAccepted,
    bool isHistory = false,
  }) {
    if (docs.isEmpty) {
      return _emptyState(
        icon: isHistory
            ? Icons.history_rounded
            : (isAccepted
                  ? Icons.assignment_turned_in_outlined
                  : Icons.search_rounded),
        title: isHistory
            ? 'No past missions'
            : (isAccepted ? 'No active missions' : 'No tasks right now'),
        subtitle: isHistory
            ? 'Your impact journey starts here.'
            : (isAccepted
                  ? 'Accept a task from Available to begin.'
                  : 'Check back soon — new tasks appear daily.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final doc = docs[i];
        final matchMap = Map<String, dynamic>.from(
          doc.data() as Map<String, dynamic>,
        );
        matchMap['id'] = doc.id;
        return _TaskCard(
          matchMap: matchMap,
          isAccepted: isAccepted,
          isHistory: isHistory,
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  TASK CARD
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> matchMap;
  final bool isAccepted;
  final bool isHistory;
  const _TaskCard({
    required this.matchMap,
    required this.isAccepted,
    this.isHistory = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final taskId = matchMap['taskId'] ?? '';
    final matchScore = (matchMap['matchScore'] as num?)?.toDouble() ?? 0;
    final pct = (matchScore * 100).round();
    final status = matchMap['status'] ?? 'open';
    final impactStatement = (matchMap['impactStatement'] as String? ?? '')
        .trim();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('tasks').doc(taskId).get(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();

        final td = snap.data!.data() as Map<String, dynamic>;
        final desc = td['description'] ?? 'Task';
        final ward = td['locationWard'] ?? '';
        final type = (td['taskType'] ?? 'other').toString().replaceAll(
          '_',
          ' ',
        );

        return GestureDetector(
          onTap: () => _onTap(context, td, pct, status),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(18),
              border: isHistory
                  ? Border.all(
                      color: SahayaColors.emerald.withValues(alpha: 0.2),
                      width: 1,
                    )
                  : (isAccepted
                        ? Border.all(
                            color: cs.primary.withValues(alpha: 0.3),
                            width: 1.5,
                          )
                        : Border.all(
                            color: isDark
                                ? SahayaColors.darkBorder
                                : SahayaColors.lightBorder,
                          )),
              boxShadow: [sahayaCardShadow(context)],
            ),
            child: Row(
              children: [
                // Left icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isAccepted
                        ? cs.primary.withValues(alpha: 0.1)
                        : (isDark
                              ? SahayaColors.darkBorder.withValues(alpha: 0.3)
                              : const Color(0xFFF3F4F6)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isHistory
                        ? Icons.verified_rounded
                        : (isAccepted
                              ? Icons.run_circle_rounded
                              : Icons.assignment_outlined),
                    color: isHistory
                        ? SahayaColors.emerald
                        : (isAccepted
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.5)),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        desc,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isHistory && impactStatement.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          impactStatement,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark
                                ? SahayaColors.darkMuted
                                : SahayaColors.lightMuted,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (ward.isNotEmpty) ...[
                            Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: isDark
                                  ? SahayaColors.darkMuted
                                  : SahayaColors.lightMuted,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                ward,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark
                                      ? SahayaColors.darkMuted
                                      : SahayaColors.lightMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          _pill(
                            context,
                            type,
                            isDark
                                ? SahayaColors.darkBorder
                                : const Color(0xFFE5E7EB),
                            cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Right badge
                _statusBadge(context, status, pct),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pill(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: fg,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context, String status, int pct) {
    if (isHistory) {
      return _pill(
        context,
        'Completed',
        SahayaColors.emeraldMuted,
        SahayaColors.emerald,
      );
    }
    final cs = Theme.of(context).colorScheme;
    if (status == 'proof_submitted') {
      return _pill(
        context,
        'Proof sent',
        SahayaColors.amberMuted,
        SahayaColors.amber,
      );
    } else if (status == 'proof_rejected') {
      return _pill(
        context,
        'Needs update',
        SahayaColors.coral.withValues(alpha: 0.12),
        SahayaColors.coral,
      );
    } else if (status == 'accepted') {
      return _pill(
        context,
        'Active',
        SahayaColors.emeraldMuted,
        SahayaColors.emerald,
      );
    }
    return _pill(
      context,
      '$pct%',
      cs.primary.withValues(alpha: 0.1),
      cs.primary,
    );
  }

  void _onTap(
    BuildContext context,
    Map<String, dynamic> taskData,
    int pct,
    String status,
  ) {
    if (isAccepted || status == 'proof_submitted' || isHistory) {
      _goActive(context, taskData);
    } else {
      _goDetails(context, taskData, pct);
    }
  }

  void _goActive(BuildContext context, Map<String, dynamic> td) async {
    final task = TaskModel.fromJson(td);
    String ngoName = 'Coordinator', ngoPhone = '', ngoEmail = '';
    try {
      final pc = await FirebaseFirestore.instance
          .collection('problem_cards')
          .doc(task.problemCardId)
          .get();
      if (pc.exists) {
        final ngoId = pc.data()?['ngoId'];
        if (ngoId != null) {
          final ngo = await FirebaseFirestore.instance
              .collection('users')
              .doc(ngoId)
              .get();
          if (ngo.exists) {
            ngoName = ngo['name'] ?? ngoName;
            ngoPhone = ngo['phone'] ?? '';
            ngoEmail = ngo['email'] ?? '';
          }
        }
      }
    } catch (_) {}
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveTaskScreen(
          matchRecordId: matchMap['id'] ?? '',
          task: task,
          ngoName: ngoName,
          ngoPhone: ngoPhone,
          ngoEmail: ngoEmail,
          status: matchMap['status'] ?? 'accepted',
          proof: matchMap['proof'] as Map<String, dynamic>?,
          adminReviewNote: matchMap['adminReviewNote'] as String?,
        ),
      ),
    );
  }

  void _goDetails(BuildContext context, Map<String, dynamic> td, int pct) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailsScreen(
          taskId: matchMap['taskId'] ?? '',
          matchRecordId: matchMap['id'] ?? '',
          initialTask: TaskModel.fromJson(td),
          matchScore: pct,
          isAlreadyAccepted: false,
          whatToBring: matchMap['whatToBring'] ?? 'Standard gear and water.',
        ),
      ),
    );
  }
}

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  const _MarqueeText({required this.text, this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrolling() async {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    while (mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) break;
      await _scrollController.animateTo(
        maxScroll,
        duration: Duration(milliseconds: (maxScroll * 40).toInt()),
        curve: Curves.linear,
      );
      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) break;
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          widget.text,
          style:
              widget.style ??
              GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          maxLines: 1,
        ),
      ),
    );
  }
}
