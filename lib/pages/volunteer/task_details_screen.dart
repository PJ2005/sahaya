import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/task_model.dart';
import '../../theme/sahaya_theme.dart';
import 'active_task_screen.dart';

class TaskDetailsScreen extends StatefulWidget {
  final String taskId;
  final String matchRecordId;
  final TaskModel initialTask;
  final int matchScore;
  final String whatToBring;
  final bool isAlreadyAccepted;

  const TaskDetailsScreen({
    super.key,
    required this.taskId,
    required this.matchRecordId,
    required this.initialTask,
    required this.matchScore,
    required this.whatToBring,
    this.isAlreadyAccepted = false,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  bool _isAccepting = false;
  late bool _isAccepted;
  late final Future<Map<String, dynamic>> _contextFuture;

  String _ngoName = 'Coordinator';
  String _ngoEmail = '';
  String _ngoPhone = '';

  @override
  void initState() {
    super.initState();
    _isAccepted = widget.isAlreadyAccepted;
    _contextFuture = _fetchTaskContext();
  }

  Future<Map<String, dynamic>> _fetchTaskContext() async {
    if (widget.matchRecordId.isEmpty) {
      return {
        'skills': <String>[],
        'problem': <String, dynamic>{},
        'match': <String, dynamic>{},
        'ngoName': 'Coordinator',
        'ngoEmail': '',
        'ngoPhone': '',
      };
    }

    final matchDoc = await FirebaseFirestore.instance.collection('match_records').doc(widget.matchRecordId).get();
    if (!matchDoc.exists) {
      return {
        'skills': <String>[],
        'problem': <String, dynamic>{},
        'match': <String, dynamic>{},
        'ngoName': 'Coordinator',
        'ngoEmail': '',
        'ngoPhone': '',
      };
    }

    final volunteerId = matchDoc['volunteerId'];
    final volunteerDoc = await FirebaseFirestore.instance.collection('volunteer_profiles').doc(volunteerId).get();
    final problemDoc = await FirebaseFirestore.instance.collection('problem_cards').doc(widget.initialTask.problemCardId).get();

    String ngoName = 'Coordinator', ngoEmail = '', ngoPhone = '';
    if (problemDoc.exists && problemDoc.data() != null) {
      final ngoId = problemDoc.data()!['ngoId'];
      if (ngoId != null) {
        final ngoDoc = await FirebaseFirestore.instance.collection('users').doc(ngoId).get();
        if (ngoDoc.exists) { ngoName = ngoDoc['name'] ?? ngoName; ngoEmail = ngoDoc['email'] ?? ''; ngoPhone = ngoDoc['phone'] ?? ''; }
      }
    }

    return {
      'skills': volunteerDoc.exists ? List<String>.from(volunteerDoc['skillTags'] ?? volunteerDoc['skills'] ?? []) : <String>[],
      'problem': problemDoc.exists ? problemDoc.data()! : {},
      'match': matchDoc.data() ?? <String, dynamic>{},
      'ngoName': ngoName, 'ngoEmail': ngoEmail, 'ngoPhone': ngoPhone,
    };
  }

  Future<void> _acceptTask() async {
    if (widget.matchRecordId.isEmpty) return;
    setState(() => _isAccepting = true);
    try {
      final matchRef = FirebaseFirestore.instance.collection('match_records').doc(widget.matchRecordId);
      final taskRef = FirebaseFirestore.instance.collection('tasks').doc(widget.taskId);
      final currentMatch = await matchRef.get();
      if (!currentMatch.exists) throw Exception('Not found');
      final currentStatus = currentMatch.data()!['status'] as String? ?? '';
      if (currentStatus != 'open') throw Exception('Not available');
      final volunteerId = currentMatch['volunteerId'];
      final batch = FirebaseFirestore.instance.batch();
      batch.update(matchRef, {'status': 'accepted'});
      batch.update(taskRef, {'assignedVolunteerIds': FieldValue.arrayUnion([volunteerId])});
      await batch.commit();

      if (mounted) {
        setState(() => _isAccepted = true);
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => ActiveTaskScreen(matchRecordId: widget.matchRecordId, task: widget.initialTask, ngoName: _ngoName, ngoPhone: _ngoPhone, ngoEmail: _ngoEmail),
          ));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: SahayaColors.coral));
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<Map<String, dynamic>>(
      future: _contextFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(title: Text('Mission', style: GoogleFonts.inter(fontWeight: FontWeight.w700))), body: Center(child: CircularProgressIndicator(color: cs.primary)));
        }

        final ctx = snapshot.data ?? {};
        final volunteerSkills = ctx['skills'] as List<String>? ?? [];
        final problemData = ctx['problem'] as Map<String, dynamic>? ?? {};
        final matchData = ctx['match'] as Map<String, dynamic>? ?? {};
        _ngoName = ctx['ngoName'] as String? ?? 'Coordinator';
        _ngoEmail = ctx['ngoEmail'] as String? ?? '';
        _ngoPhone = ctx['ngoPhone'] as String? ?? '';

        final severity = (problemData['severityLevel']?.toString().split('.').last ?? 'high').toUpperCase();
        final affected = problemData['affectedCount'] as int? ?? 0;

        return Scaffold(
          appBar: AppBar(title: Text('Mission Briefing', style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Context Banner ───
                if (problemData.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: SahayaColors.amberMuted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: SahayaColors.amber, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$severity priority · $affected households affected',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Match & Type ───
                      Row(
                        children: [
                          _chip('${widget.matchScore}% Match', cs.primary.withValues(alpha: 0.1), cs.primary),
                          const SizedBox(width: 8),
                          _chip(widget.initialTask.taskType.name.replaceAll('_', ' '), isDark ? SahayaColors.darkBorder : const Color(0xFFF3F4F6), cs.onSurface.withValues(alpha: 0.6)),
                        ],
                      ),
                      if (_buildMatchExplanation(matchData)?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 12),
                        _matchExplanationCard(context, matchData, isDark),
                      ],
                      const SizedBox(height: 24),

                      // ─── Description ───
                      Text('The Challenge', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(widget.initialTask.description, style: GoogleFonts.inter(fontSize: 15, height: 1.6, color: isDark ? SahayaColors.darkMuted : const Color(0xFF374151))),

                      const SizedBox(height: 28),

                      // ─── Logistics ───
                      Text('Logistics', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      _logisticRow(Icons.location_on_outlined, 'Location', widget.initialTask.locationWard, isDark),
                      _logisticRow(Icons.schedule_rounded, 'Duration', '${widget.initialTask.estimatedDurationHours} hours', isDark),
                      _logisticRow(Icons.people_outline_rounded, 'Team size', '${widget.initialTask.estimatedVolunteers} volunteers', isDark),
                      _logisticRow(Icons.backpack_outlined, 'What to bring', widget.whatToBring, isDark),

                      const SizedBox(height: 28),

                      // ─── Skills ───
                      Text('Skills Required', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.initialTask.skillTags.map((skill) {
                          final match = volunteerSkills.map((s) => s.toLowerCase()).contains(skill.toLowerCase());
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: match ? SahayaColors.emeraldMuted : (isDark ? SahayaColors.darkSurface : const Color(0xFFF3F4F6)),
                              borderRadius: BorderRadius.circular(28),
                              border: match ? Border.all(color: SahayaColors.emerald.withValues(alpha: 0.3)) : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (match) ...[Icon(Icons.check_circle_rounded, size: 16, color: SahayaColors.emeraldDark), const SizedBox(width: 6)],
                                Text(skill, style: GoogleFonts.inter(fontSize: 13, fontWeight: match ? FontWeight.w600 : FontWeight.w500, color: match ? SahayaColors.emeraldDark : cs.onSurface.withValues(alpha: 0.6))),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 28),

                      // ─── Contact ───
                      Text('Point of Contact', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? SahayaColors.darkSurface : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDark ? SahayaColors.darkBorder : SahayaColors.lightBorder),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(backgroundColor: cs.primary.withValues(alpha: 0.1), child: Icon(Icons.person_rounded, color: cs.primary)),
                                  const SizedBox(width: 14),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(_ngoName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
                                    if (_ngoEmail.isNotEmpty) Text(_ngoEmail, style: GoogleFonts.inter(fontSize: 13, color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted)),
                                  ])),
                                ],
                              ),
                            ),
                            if (!_isAccepted)
                              Positioned.fill(
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 8.0, end: _isAccepted ? 0.0 : 8.0),
                                  duration: const Duration(milliseconds: 300),
                                  builder: (context, blur, _) {
                                    if (blur <= 0.01) return const SizedBox.shrink();
                                    return BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                                      child: Container(
                                        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.3),
                                        alignment: Alignment.center,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(color: cs.onSurface, borderRadius: BorderRadius.circular(28)),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            Icon(Icons.lock_rounded, color: cs.surface, size: 14),
                                            const SizedBox(width: 6),
                                            Text('Accept to unlock', style: GoogleFonts.inter(color: cs.surface, fontSize: 13, fontWeight: FontWeight.w600)),
                                          ]),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _isAccepted
              ? const SizedBox.shrink()
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isAccepting ? null : _acceptTask,
                        child: _isAccepting
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Icon(Icons.handshake_rounded),
                                const SizedBox(width: 8),
                                Text('Accept Mission', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                              ]),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _chip(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
    child: Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
  );

  Widget _matchExplanationCard(BuildContext context, Map<String, dynamic> matchData, bool isDark) {
    final explanation = _buildMatchExplanation(matchData) ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? SahayaColors.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tune_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Matched because: $explanation.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _buildMatchExplanation(Map<String, dynamic> matchData) {
    final parts = <String>[];

    final distanceKm = (matchData['distanceKm'] as num?)?.toDouble();
    if (distanceKm != null) {
      parts.add('within ${distanceKm.round()}km');
    }

    final skillOverlap = (matchData['skillOverlap'] as num?)?.toInt();
    final requiredSkills = widget.initialTask.skillTags.length;
    if (skillOverlap != null && requiredSkills > 0) {
      parts.add('$skillOverlap of $requiredSkills skills overlap');
    }

    final availabilityBonus = (matchData['availabilityBonus'] as num?)?.toDouble() ?? 0;
    if (availabilityBonus > 0) {
      parts.add('available this weekend');
    }

    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  Widget _logisticRow(IconData icon, String title, String value, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: isDark ? SahayaColors.darkSurface : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.inter(fontSize: 12, color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
        ])),
      ],
    ),
  );
}
