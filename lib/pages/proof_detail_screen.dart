import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/sahaya_theme.dart';
import '../models/problem_card.dart';
import 'ngo_task_detail_screen.dart';

class ProofDetailScreen extends StatefulWidget {
  final String matchRecordId;
  final Map<String, dynamic> matchData;

  const ProofDetailScreen({
    super.key,
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

  @override
  void initState() {
    super.initState();
    final proof = widget.matchData['proof'] as Map<String, dynamic>?;
    if (proof != null) {
      _photos = List<String>.from(proof['photoUrls'] ?? proof['secureUrls'] ?? []);
      _note = proof['note'] as String? ?? '';
      final ts = proof['submittedAt'];
      if (ts is Timestamp) _submittedAt = ts.toDate();
    }
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final tid = widget.matchData['taskId'] as String? ?? '';
    if (tid.isEmpty) return;
    try {
      final tdoc = await FirebaseFirestore.instance.collection('tasks').doc(tid).get();
      if (!tdoc.exists || !mounted) return;
      
      setState(() => _taskData = tdoc.data());
      
      final pid = _taskData?['problemCardId'] as String? ?? '';
      if (pid.isNotEmpty) {
        final pdoc = await FirebaseFirestore.instance.collection('problem_cards').doc(pid).get();
        if (pdoc.exists && mounted) {
          setState(() => _problemCard = ProblemCard.fromJson({...pdoc.data()!, 'id': pdoc.id}));
        }
      }
    } catch (_) {}
  }

  Future<void> _approve() async {
    setState(() => _processing = true);
    try {
      await FirebaseFirestore.instance.collection('match_records').doc(widget.matchRecordId).update({
        'status': 'proof_approved', 
        'completedAt': FieldValue.serverTimestamp()
      });
      
      final url = dotenv.env['BACKEND_URL'] ?? 'https://sahaya-faas-puz67as73a-uc.a.run.app';
      try { 
        await http.post(
          Uri.parse('$url/complete-task'), 
          headers: {'Content-Type': 'application/json'}, 
          body: jsonEncode({'matchRecordId': widget.matchRecordId})
        ); 
      } catch (_) {}
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submission Approved!'), backgroundColor: SahayaColors.emerald));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: SahayaColors.coral));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showRejectDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Proof'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you rejecting this submission?'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl, 
              maxLength: 100, 
              maxLines: 2, 
              decoration: const InputDecoration(hintText: 'e.g. Photo quality is too low'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SahayaColors.coral),
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              _reject(ctrl.text.trim());
            },
            child: const Text('Reject Submission'),
          ),
        ],
      ),
    );
  }

  Future<void> _reject(String reason) async {
    setState(() => _processing = true);
    try {
      await FirebaseFirestore.instance.collection('match_records').doc(widget.matchRecordId).update({
        'status': 'proof_rejected', 
        'adminReviewNote': reason
      });
      
      final url = dotenv.env['BACKEND_URL'] ?? 'https://sahaya-faas-puz67as73a-uc.a.run.app';
      try { 
        await http.post(
          Uri.parse('$url/notify-proof-rejected'), 
          headers: {'Content-Type': 'application/json'}, 
          body: jsonEncode({'matchRecordId': widget.matchRecordId})
        ); 
      } catch (_) {}
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejected. Volunteer notified.'), backgroundColor: SahayaColors.amber));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: SahayaColors.coral));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Review Submission', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            // Status Pills
            Row(
              children: [
                _pill(context, 'PENDING REVIEW', SahayaColors.amber.withValues(alpha: 0.1), SahayaColors.amber),
                const SizedBox(width: 8),
                if (_submittedAt != null)
                  _pill(context, _fmtTime(_submittedAt!), cs.surfaceContainerHighest, cs.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 24),

            // Task Context Section
            _buildTaskOverview(context, cs, isDark),
            
            const SizedBox(height: 32),

            // Evidence Section
            Text('EVIDENCE SUBMITTED', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: cs.primary, letterSpacing: 0.8)),
            const SizedBox(height: 16),
            if (_photos.isEmpty)
              Container(
                height: 160, width: double.infinity,
                decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(20), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3))),
                child: Center(child: Text('No photos uploaded', style: GoogleFonts.inter(color: cs.onSurfaceVariant))),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1),
                itemCount: _photos.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _fullScreen(context, _photos[i]),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(image: NetworkImage(_photos[i]), fit: BoxFit.cover),
                      boxShadow: [sahayaCardShadow(context)],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Volunteer Note
            if (_note.isNotEmpty) ...[
              Text('VOLUNTEER NOTE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: cs.primary, letterSpacing: 0.8)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? SahayaColors.darkSurface : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Text(_note, style: GoogleFonts.inter(fontSize: 15, height: 1.6, fontWeight: FontWeight.w500, color: cs.onSurface)),
              ),
            ],

            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _processing 
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text('Approve Submission', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56, width: 64,
              child: OutlinedButton(
                onPressed: _processing ? null : _showRejectDialog,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: SahayaColors.coral, width: 2),
                  foregroundColor: SahayaColors.coral,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    if (_taskData == null) return const Center(child: CircularProgressIndicator());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? SahayaColors.darkSurface.withValues(alpha: 0.5) : cs.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('MISSION GOAL', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: cs.primary, letterSpacing: 0.8)),
              const Spacer(),
              if (_problemCard != null)
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NgoTaskDetailScreen(card: _problemCard!))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Text('FULL TASK', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: cs.primary)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 8, color: cs.primary),
                    ]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_taskData!['description'] ?? '', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, height: 1.4, color: cs.onSurface)),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _metaRow(Icons.category_outlined, 'Type', (_taskData!['taskType'] ?? 'General').toString().replaceAll('_', ' ').toUpperCase(), cs),
          const SizedBox(height: 8),
          _metaRow(Icons.timer_outlined, 'Duration', '${_taskData!['estimatedDurationHours'] ?? 1} Hours (Est.)', cs),
          const SizedBox(height: 8),
          if (_problemCard != null)
            _metaRow(Icons.location_on_outlined, 'Location', '${_problemCard!.locationWard}, ${_problemCard!.locationCity}', cs),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String label, String value, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text('$label: ', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
        Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface))),
      ],
    );
  }

  Widget _pill(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
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
            Center(child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain))),
            Positioned(top: 8, right: 8, child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28), onPressed: () => Navigator.pop(ctx))),
          ],
        ),
      ),
    );
  }
}
