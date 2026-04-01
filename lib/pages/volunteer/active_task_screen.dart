import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../models/task_model.dart';
import '../../theme/sahaya_theme.dart';
import 'dart:convert';

class ActiveTaskScreen extends StatefulWidget {
  final String matchRecordId;
  final TaskModel task;
  final String ngoName;
  final String ngoPhone;
  final String ngoEmail;
  final String status;
  final Map<String, dynamic>? proof;

  const ActiveTaskScreen({
    super.key,
    required this.matchRecordId,
    required this.task,
    required this.ngoName,
    required this.ngoPhone,
    required this.ngoEmail,
    this.status = 'accepted',
    this.proof,
  });

  @override
  State<ActiveTaskScreen> createState() => _ActiveTaskScreenState();
}

class _ActiveTaskScreenState extends State<ActiveTaskScreen> {
  void _openDirections() async {
    final geo = widget.task.locationGeoPoint;
    if (geo != null) {
      final url = Uri.parse('https://maps.google.com/?q=${geo.latitude},${geo.longitude}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not available.')));
    }
  }

  void _callCoordinator() async {
    final phone = widget.ngoPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.isEmpty) return;
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _showProofSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ProofSubmissionSheet(matchRecordId: widget.matchRecordId),
    ).then((submitted) {
      if (submitted == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proof submitted — waiting for NGO review.'), backgroundColor: SahayaColors.emerald),
        );
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bool isCompleted = widget.status == 'proof_approved';
    final bool isSubmitted = widget.status == 'proof_submitted';
    final bool isReadOnly = isCompleted || isSubmitted;

    return Scaffold(
      appBar: AppBar(title: Text(isReadOnly ? 'Mission Summary' : 'Active Mission', style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Status Header ───
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCompleted 
                    ? [SahayaColors.emerald, const Color(0xFF065F46)]
                    : (isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFF111827), const Color(0xFF1F2937)]),
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [sahayaCardShadow(context)],
              ),
              child: Column(
                children: [
                  Icon(
                    isCompleted ? Icons.verified_rounded : (isSubmitted ? Icons.hourglass_top_rounded : Icons.run_circle_rounded), 
                    size: 56, 
                    color: isCompleted ? Colors.white : cs.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isCompleted ? 'Mission Completed' : (isSubmitted ? 'Awaiting Review' : 'Mission is active'), 
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isCompleted 
                      ? 'Thank you for your incredible service!' 
                      : (isSubmitted ? 'We\'ll notify you once the NGO reviews it.' : 'Head to the location and complete the task.'), 
                    textAlign: TextAlign.center, 
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ─── Proof Section ───
            if (isReadOnly && widget.proof != null) ...[
              Text('Your Submission', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _buildProofDisplay(context, widget.proof!),
              const Divider(height: 48),
            ],

            // ─── Quick Actions (Secondary for ReadOnly) ───
            if (!isReadOnly) ...[
              Row(
                children: [
                  Expanded(child: _actionCard(Icons.navigation_rounded, 'Directions', cs.primary, _openDirections, isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _actionCard(Icons.call_rounded, 'Call NGO', SahayaColors.amber, _callCoordinator, isDark)),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // ─── Coordinator ───
            Text('Coordinator', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? SahayaColors.darkBorder : SahayaColors.lightBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(radius: 24, backgroundColor: cs.primary.withValues(alpha: 0.1), child: Icon(Icons.person_rounded, color: cs.primary)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.ngoName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (widget.ngoPhone.isNotEmpty) Text(widget.ngoPhone, style: GoogleFonts.inter(fontSize: 13, color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted)),
                  ])),
                  if (widget.ngoPhone.isNotEmpty && !isReadOnly)
                    IconButton(onPressed: _callCoordinator, icon: const Icon(Icons.call_rounded, color: SahayaColors.amber)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── Task ───
            Text('Task Outline', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(widget.task.description, style: GoogleFonts.inter(fontSize: 15, height: 1.6, color: isDark ? SahayaColors.darkMuted : const Color(0xFF374151))),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: isReadOnly 
        ? null 
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _showProofSheet,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: Text('Submit proof', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildProofDisplay(BuildContext context, Map<String, dynamic> proof) {
    final cs = Theme.of(context).colorScheme;
    final photos = List<String>.from(proof['photoUrls'] ?? proof['secureUrls'] ?? []);
    final note = proof['note'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? SahayaColors.darkSurface : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photos.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _fullScreen(context, photos[i]),
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(image: NetworkImage(photos[i]), fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
          if (photos.isNotEmpty && note.isNotEmpty) const SizedBox(height: 16),
          if (note.isNotEmpty) ...[
            Text('NOTE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: cs.primary, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text(note, style: GoogleFonts.inter(fontSize: 14, height: 1.4)),
          ],
        ],
      ),
    );
  }

  void _fullScreen(BuildContext ctx, String url) {
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(children: [
          Center(child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain))),
          Positioned(top: 8, right: 8, child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28), onPressed: () => Navigator.pop(ctx))),
        ]),
      ),
    );
  }

  Widget _actionCard(IconData icon, String label, Color color, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  PROOF SUBMISSION SHEET
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class ProofSubmissionSheet extends StatefulWidget {
  final String matchRecordId;
  const ProofSubmissionSheet({super.key, required this.matchRecordId});

  @override
  State<ProofSubmissionSheet> createState() => _ProofSubmissionSheetState();
}

class _ProofSubmissionSheetState extends State<ProofSubmissionSheet> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _images = [];
  final TextEditingController _noteCtrl = TextEditingController();
  bool _submitting = false;

  Future<void> _pickImages() async {
    final imgs = await _picker.pickMultiImage();
    if (imgs.isNotEmpty) {
      setState(() {
        _images.addAll(imgs);
        if (_images.length > 3) _images = _images.sublist(0, 3);
      });
    }
  }

  Future<void> _submit() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attach at least 1 photo.'), backgroundColor: SahayaColors.coral));
      return;
    }
    setState(() => _submitting = true);
    try {
      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
      final preset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
      final cloudinary = CloudinaryPublic(cloudName, preset, cache: false);

      List<String> urls = [];
      for (var img in _images) {
        final resp = await cloudinary.uploadFile(CloudinaryFile.fromFile(img.path, resourceType: CloudinaryResourceType.Image));
        urls.add(resp.secureUrl);
      }

      await FirebaseFirestore.instance.collection('match_records').doc(widget.matchRecordId).update({
        'proof': {'photoUrls': urls, 'secureUrls': urls, 'note': _noteCtrl.text.trim(), 'submittedAt': FieldValue.serverTimestamp()},
        'status': 'proof_submitted',
      });

      final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:5000';
      try {
        await http.post(Uri.parse('$backendUrl/notify-proof-submitted'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'matchRecordId': widget.matchRecordId}));
      } catch (_) {}

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: SahayaColors.coral));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? SahayaColors.darkBorder : const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Text('Submit Proof', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Upload up to 3 photos of your work.', style: GoogleFonts.inter(color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted)),
          const SizedBox(height: 20),

          // Photos
          if (_images.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length < 3 ? _images.length + 1 : 3,
                itemBuilder: (_, i) {
                  if (i == _images.length) {
                    return GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 100, margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(color: isDark ? SahayaColors.darkSurface : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(14)),
                        child: Icon(Icons.add_rounded, color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted),
                      ),
                    );
                  }
                  return Stack(children: [
                    Container(
                      width: 100, margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), image: DecorationImage(image: FileImage(File(_images[i].path)), fit: BoxFit.cover)),
                    ),
                    Positioned(top: 4, right: 14, child: GestureDetector(
                      onTap: () => setState(() => _images.removeAt(i)),
                      child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: SahayaColors.coral, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16)),
                    )),
                  ]);
                },
              ),
            )
          else
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                height: 110,
                decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.primary.withValues(alpha: 0.15))),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_a_photo_rounded, size: 36, color: cs.primary),
                  const SizedBox(height: 8),
                  Text('Tap to select photos', style: GoogleFonts.inter(color: cs.primary, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),

          const SizedBox(height: 20),
          TextField(controller: _noteCtrl, maxLength: 200, maxLines: 2, decoration: const InputDecoration(hintText: 'Anything the NGO should know?')),
          const SizedBox(height: 20),

          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text('Submit', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
