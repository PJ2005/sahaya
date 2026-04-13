import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/sahaya_theme.dart';
import '../models/problem_card.dart';
import 'ngo_task_detail_screen.dart';
import '../utils/translator.dart';

class ProofDetailScreen extends StatefulWidget {
  final String? notificationId;
  final String matchRecordId;
  final Map<String, dynamic> matchData;

  const ProofDetailScreen({
    super.key,
    this.notificationId,
    required this.matchRecordId,
    required this.matchData,
  });

  @override
  State<ProofDetailScreen> createState() => _ProofDetailScreenState();
}

class _ProofDetailScreenState extends State<ProofDetailScreen> {
  bool _processing = false;
  Map<String, dynamic>? _taskData;
  ProblemCard? _problemCard;
  List<String> _photos = [];
  String _note = '';
  DateTime? _submittedAt;
  String? _aiVerificationLabel;   
  String? _aiVerificationReason;
  bool _aiVerificationLoading = false;
  StreamSubscription<DocumentSnapshot>? _recordSubscription;

  @override
  void initState() {
    super.initState();
    _loadInitialData(widget.matchData);
    _listenToRecord();
    _loadMetadata();
    // Fallback: check notifications if reason is missing
    _fetchNotificationInsight();
  }

  void _loadInitialData(Map<String, dynamic> data) {
    if (!mounted) return;
    final proof = data['proof'] as Map<String, dynamic>?;
    if (proof != null) {
      _photos = List<String>.from(
        proof['photoUrls'] ?? proof['secureUrls'] ?? [],
      );
      _note = proof['note'] as String? ?? '';
      final ts = proof['submittedAt'];
      if (ts is Timestamp) _submittedAt = ts.toDate();
    }

    final cachedLabel = data['aiVerificationLabel'] as String?;
    final cachedReason = data['aiVerificationReason'] as String?;
    if (cachedLabel != null && cachedLabel.isNotEmpty) {
      _aiVerificationLabel = cachedLabel;
      _aiVerificationReason = cachedReason;
    } else {
      _aiVerificationLabel = null;
      _aiVerificationReason = null;
    }

    // Attempt to extract from 'message' field if present in the data
    if (_aiVerificationReason == null) {
      final msg = data['message'] as String?;
      final extracted = _extractAiInsight(msg);
      if (extracted != null) {
        _aiVerificationReason = extracted;
        _aiVerificationLabel ??= _guessLabel(extracted);
      }
    }

    setState(() {});
  }

  void _listenToRecord() {
    _recordSubscription = FirebaseFirestore.instance
        .collection('match_records')
        .doc(widget.matchRecordId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            _loadInitialData(snapshot.data() as Map<String, dynamic>);
          }
        });
  }

  @override
  void dispose() {
    _recordSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    final tid = widget.matchData['taskId'] as String? ?? '';
    if (tid.isEmpty) return;
    try {
      final tdoc = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(tid)
          .get();
      if (!tdoc.exists || !mounted) return;

      setState(() => _taskData = tdoc.data());
      /* final taskType =
          (_taskData?['taskType'] as String?)?.replaceAll('_', ' ') ??
          'community task'; */

      final pid = _taskData?['problemCardId'] as String? ?? '';
      if (pid.isNotEmpty) {
        final pdoc = await FirebaseFirestore.instance
            .collection('problem_cards')
            .doc(pid)
            .get();
        if (pdoc.exists && mounted) {
          setState(
            () => _problemCard = ProblemCard.fromJson({
              ...pdoc.data()!,
              'id': pdoc.id,
            }),
          );
        }
      }
    } catch (_) {}
  }

  String? _extractAiInsight(String? text) {
    if (text == null) return null;
    final regex = RegExp(r'\(AI insight:\s*(.*?)\)', caseSensitive: false);
    final match = regex.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)?.trim();
    }
    return null;
  }

  String _guessLabel(String insight) {
    final lower = insight.toLowerCase();
    if (lower.contains('no evidence') ||
        lower.contains('unrelated') ||
        lower.contains('nothing to do with') ||
        lower.contains('incorrect')) {
      return 'unrelated';
    }
    if (lower.contains('genuine') ||
        lower.contains('verified') ||
        lower.contains('clear evidence') ||
        lower.contains('shows evidence')) {
      return 'likely_genuine';
    }
    return 'needs_clarification';
  }

  Future<void> _fetchNotificationInsight() async {
    if (_aiVerificationReason != null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      setState(() => _aiVerificationLoading = true);
      final qs = await FirebaseFirestore.instance
          .collection('ngo_notifications')
          .where('ngoId', isEqualTo: uid)
          .get();

      final filtered = qs.docs.where((doc) {
        final data = doc.data();
        return data['matchRecordId'] == widget.matchRecordId;
      }).toList()
        ..sort((a, b) {
          final aTs = a.data()['createdAt'];
          final bTs = b.data()['createdAt'];
          final aMs = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
          final bMs = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
          return bMs.compareTo(aMs);
        });

      if (filtered.isNotEmpty && mounted) {
        final msg = filtered.first.data()['message'] as String?;
        final extracted = _extractAiInsight(msg);
        if (extracted != null) {
          setState(() {
            _aiVerificationReason = extracted;
            _aiVerificationLabel ??= _guessLabel(extracted);
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching notification insight: $e");
    } finally {
      if (mounted) setState(() => _aiVerificationLoading = false);
    }
  }

  Future<void> _approve() async {
    setState(() => _processing = true);
    try {
      await FirebaseFirestore.instance
          .collection('match_records')
          .doc(widget.matchRecordId)
          .update({
            'status': 'proof_approved',
            'completedAt': FieldValue.serverTimestamp(),
          });
      await _markNotificationHandled();

      final url =
          dotenv.env['BACKEND_URL'] ??
          'https://sahaya-faas-puz67as73a-uc.a.run.app';
      try {
        await http
            .post(
              Uri.parse('$url/complete-task'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'matchRecordId': widget.matchRecordId}),
            )
            .timeout(const Duration(seconds: 15));
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: T('Submission Approved!'),
            backgroundColor: SahayaColors.emerald,
          ),
        );
        Navigator.pop(context);
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
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showRejectDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const T('Reject Proof'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const T('Why are you rejecting this submission?'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLength: 100,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. Photo quality is too low',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const T('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SahayaColors.coral,
            ),
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              _reject(ctrl.text.trim());
            },
            child: const T('Reject Submission'),
          ),
        ],
      ),
    );
  }

  Future<void> _reject(String reason) async {
    setState(() => _processing = true);
    try {
      await FirebaseFirestore.instance
          .collection('match_records')
          .doc(widget.matchRecordId)
          .update({
            'status': 'proof_rejected',
            'adminReviewNote': reason,
            'aiVerificationLabel': FieldValue.delete(),
            'aiVerificationReason': FieldValue.delete(),
            'aiVerifiedAt': FieldValue.delete(),
          });
      
      final tid = widget.matchData['taskId'] as String? ?? '';
      if (tid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('tasks').doc(tid).update({
          'isProofSubmitted': false,
        });
      }
      await _markNotificationHandled();

      final url =
          dotenv.env['BACKEND_URL'] ??
          'https://sahaya-faas-puz67as73a-uc.a.run.app';
      unawaited(() async {
        try {
          await http
              .post(
                Uri.parse('$url/notify-proof-rejected'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'matchRecordId': widget.matchRecordId}),
              )
              .timeout(const Duration(seconds: 8));
        } catch (_) {}
      }());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: T('Rejected. Volunteer notified.'),
            backgroundColor: SahayaColors.amber,
          ),
        );
        Navigator.pop(context);
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
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _markNotificationHandled() async {
    final notificationId = widget.notificationId;
    if (notificationId != null && notificationId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('ngo_notifications')
            .doc(notificationId)
            .update({'read': true, 'handledAt': FieldValue.serverTimestamp()});
      } catch (_) {}
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final qs = await FirebaseFirestore.instance
          .collection('ngo_notifications')
          .where('ngoId', isEqualTo: uid)
          .get();

      for (final doc in qs.docs) {
        final data = doc.data();
        final isMatch = data['matchRecordId'] == widget.matchRecordId;
        final isUnread = data['read'] == false;
        if (!isMatch || !isUnread) {
          continue;
        }
        await doc.reference.update({
          'read': true,
          'handledAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Failed to mark notifications handled: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: T(
          'Review Submission',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            // Status Pills
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill(
                  context,
                  'PENDING REVIEW',
                  SahayaColors.amber.withValues(alpha: 0.1),
                  SahayaColors.amber,
                ),
                if (_submittedAt != null)
                  _pill(
                    context,
                    _fmtTime(_submittedAt!),
                    cs.surfaceContainerHighest,
                    cs.onSurfaceVariant,
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Task Context Section
            _buildTaskOverview(context, cs, isDark),

            const SizedBox(height: 20),
            _aiVerificationPanel(context, cs, isDark),

            const SizedBox(height: 32),

            // Evidence Section
            T(
              'EVIDENCE SUBMITTED',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: cs.primary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 16),
            if (_photos.isEmpty)
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: T(
                    'No photos uploaded',
                    style: GoogleFonts.inter(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: _photos.length,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => _fullScreen(context, _photos[index]),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                        image: NetworkImage(_photos[index]),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [sahayaCardShadow(context)],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Volunteer Note
            if (_note.isNotEmpty) ...[
              T(
                'VOLUNTEER NOTE',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? SahayaColors.darkSurface
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: T(
                  _note,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _processing ? null : _approve,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SahayaColors.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : T(
                          'Approve Submission',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              width: 64,
              child: OutlinedButton(
                onPressed: _processing ? null : _showRejectDialog,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: SahayaColors.coral, width: 2),
                  foregroundColor: SahayaColors.coral,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.close_rounded, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskOverview(BuildContext context, ColorScheme cs, bool isDark) {
    if (_taskData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? SahayaColors.darkSurface.withValues(alpha: 0.5)
            : cs.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              T(
                'MISSION GOAL',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (_problemCard != null)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NgoTaskDetailScreen(card: _problemCard!),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        T(
                          'FULL TASK',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 8,
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          T(
            _taskData!['description'] ?? '',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.4,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _metaRow(
            Icons.category_outlined,
            'Type',
            (_taskData!['taskType'] ?? 'General')
                .toString()
                .replaceAll('_', ' ')
                .toUpperCase(),
            cs,
          ),
          const SizedBox(height: 8),
          _metaRow(
            Icons.timer_outlined,
            'Duration',
            '${_taskData!['estimatedDurationHours'] ?? 1} Hours (Est.)',
            cs,
          ),
          const SizedBox(height: 8),
          if (_problemCard != null)
            _metaRow(
              Icons.location_on_outlined,
              'Location',
              '${_problemCard!.locationWard}, ${_problemCard!.locationCity}',
              cs,
            ),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String label, String value, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        T(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: T(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pill(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: T(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  Widget _aiVerificationPanel(
    BuildContext context,
    ColorScheme cs,
    bool isDark,
  ) {
    final (title, bg, fg, icon) = switch (_aiVerificationLabel) {
      'likely_genuine' => (
        'Likely genuine',
        SahayaColors.emeraldMuted,
        SahayaColors.emerald,
        Icons.verified_rounded,
      ),
      'unrelated' => (
        'Unrelated',
        SahayaColors.coral.withValues(alpha: 0.12),
        SahayaColors.coral,
        Icons.report_gmailerrorred_rounded,
      ),
      _ => (
        _aiVerificationLoading ? 'Analyzing proof...' : 'Needs clarification',
        SahayaColors.amber.withValues(alpha: 0.12),
        SahayaColors.amber,
        Icons.auto_awesome_rounded,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? SahayaColors.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: fg.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: fg),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: T(
                  'AI Verification',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
              _pill(context, title, bg, fg),
            ],
          ),
          const SizedBox(height: 12),
          T(
            (_aiVerificationReason != null &&
                    _aiVerificationReason!.contains(
                      'Deprecated. Handled automatically via backend.',
                    ))
                ? 'AI verification is processing on the server and will update shortly.'
                : (_aiVerificationReason ??
                      (_aiVerificationLoading
                          ? 'Gemini is checking whether the submitted photos show evidence of this task being completed.'
                          : 'AI verification was not available for this proof.')),
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}M AGO';
    if (d.inHours < 24) return '${d.inHours}H AGO';
    return '${d.inDays}D AGO';
  }

  void _fullScreen(BuildContext ctx, String url) {
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
