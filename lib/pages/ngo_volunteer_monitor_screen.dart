import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/sahaya_theme.dart';
import '../utils/translator.dart';
import '../models/volunteer_profile.dart';
import '../models/task_model.dart';

class NgoVolunteerMonitorScreen extends StatelessWidget {
  final String ngoId;
  const NgoVolunteerMonitorScreen({super.key, required this.ngoId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: T('Volunteer Monitor', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
          bottom: TabBar(
            indicatorColor: cs.primary,
            labelColor: cs.primary,
            unselectedLabelColor: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
            tabs: const [
              Tab(text: 'Active Force'),
              Tab(text: 'Mission Tracking'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ActiveForceTab(),
            _MissionTrackingTab(ngoId: ngoId),
          ],
        ),
      ),
    );
  }
}

class _ActiveForceTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('volunteer_profiles')
          .where('availabilityWindowActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyPlaceholder(
            icon: Icons.person_off_rounded,
            title: 'Quiet out there',
            subtitle: 'No volunteers are currently checked in.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final profile = VolunteerProfile.fromJson(docs[i].data() as Map<String, dynamic>);
            return _VolunteerCard(profile: profile);
          },
        );
      },
    );
  }
}

class _MissionTrackingTab extends StatelessWidget {
  final String ngoId;
  const _MissionTrackingTab({required this.ngoId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('problem_cards')
          .where('ngoId', isEqualTo: ngoId)
          .snapshots(),
      builder: (context, problemSnap) {
        if (problemSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final problemIds = problemSnap.data?.docs.map((d) => d.id).toList() ?? [];
        if (problemIds.isEmpty) {
          return const _EmptyPlaceholder(icon: Icons.assignment_late_rounded, title: 'No Problems Active', subtitle: 'You haven\'t approved any problem cards yet.');
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tasks')
              .where('problemCardId', whereIn: problemIds.take(30).toList())
              .snapshots(),
          builder: (context, taskSnap) {
            if (taskSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            
            final tasks = taskSnap.data?.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return TaskModel.fromJson(data);
            }).toList() ?? [];
            final taskIds = tasks.map((t) => t.id).toList();

            if (taskIds.isEmpty) {
              return const _EmptyPlaceholder(icon: Icons.hail_rounded, title: 'Awaiting Heroes', subtitle: 'No missions have been generated for your problems.');
            }

            // Use task assignments as source of truth; match_records only backfills older rows.
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('match_records')
                  .where('taskId', whereIn: taskIds.take(30).toList())
                  .snapshots(),
              builder: (context, matchSnap) {
                if (matchSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final Map<String, Set<String>> assignmentSets = {
                  for (final t in tasks.where((t) => t.status != TaskStatus.done && t.assignedVolunteerIds.isNotEmpty))
                    t.id: {...t.assignedVolunteerIds}
                };

                final allMatches = matchSnap.data?.docs ?? [];
                for (final m in allMatches) {
                  final data = m.data() as Map<String, dynamic>;
                  final tid = data['taskId'] as String?;
                  final vid = data['volunteerId'] as String?;
                  final status = (data['status'] as String? ?? '').toLowerCase();
                  if (tid == null || vid == null) continue;
                  if (status == 'accepted' || status == 'proof_submitted' || status == 'proof_rejected') {
                    assignmentSets.putIfAbsent(tid, () => <String>{}).add(vid);
                  }
                }

                final assignedTasks = tasks.where((t) => assignmentSets[t.id]?.isNotEmpty ?? false).toList();

                if (assignedTasks.isEmpty) {
                  return const _EmptyPlaceholder(icon: Icons.hail_rounded, title: 'Awaiting Heroes', subtitle: 'No volunteers have accepted missions yet.');
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: assignedTasks.length,
                  itemBuilder: (context, i) {
                    final task = assignedTasks[i];
                    return _AssignmentGroupCard(
                      task: task,
                      volunteerIds: (assignmentSets[task.id] ?? <String>{}).toList(),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _VolunteerCard extends StatelessWidget {
  final VolunteerProfile profile;
  const _VolunteerCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? SahayaColors.darkBorder : SahayaColors.lightBorder),
        boxShadow: [sahayaCardShadow(context)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: cs.primary.withValues(alpha: 0.1),
            child: Icon(Icons.person_rounded, color: cs.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                T(profile.username, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: profile.skillTags.take(3).map((s) => _SkillPill(skill: s)).toList(),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              T('${profile.trustScore} XP', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: SahayaColors.amber, fontSize: 14)),
              T('AVAILABLE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: SahayaColors.emerald, letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssignmentGroupCard extends StatelessWidget {
  final TaskModel task;
  final List<String> volunteerIds;
  const _AssignmentGroupCard({required this.task, required this.volunteerIds});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [sahayaCardShadow(context)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.task_alt_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: T(task.description, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                T('WARD: ${task.locationWard}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Fetch assigned volunteers
          ...volunteerIds.map((uid) => _AssignedVolunteerTile(uid: uid)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AssignedVolunteerTile extends StatelessWidget {
  final String uid;
  const _AssignedVolunteerTile({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('volunteer_profiles').doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        final data = snapshot.data!.data() as Map<String, dynamic>;
        return ListTile(
          dense: true,
          leading: const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
          title: T(data['username'] ?? 'Anonymous', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: SahayaColors.emerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: T('ACCEPTED', style: GoogleFonts.inter(color: SahayaColors.emerald, fontSize: 9, fontWeight: FontWeight.w900)),
          ),
        );
      },
    );
  }
}

class _SkillPill extends StatelessWidget {
  final String skill;
  const _SkillPill({required this.skill});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? SahayaColors.darkBorder.withValues(alpha: 0.5) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: T(skill, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyPlaceholder({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: isDark ? SahayaColors.darkBorder : const Color(0xFFD1D5DB)),
          const SizedBox(height: 16),
          T(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          T(subtitle, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted)),
        ],
      ),
    );
  }
}
