import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../models/task_model.dart';
import '../../theme/sahaya_theme.dart';
import '../../services/offline_proof_sync_service.dart';
import '../../components/success_overlay.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../../utils/translator.dart';
import '../../components/volunteer_team_list.dart';
import 'task_chat_screen.dart';


class ActiveTaskScreen extends StatefulWidget {
  final String matchRecordId;
  final TaskModel task;
  final String? ngoName;
  final String? ngoPhone;
  final String? ngoEmail;
  final String coordinatorPhone;
  final String status;
  final Map<String, dynamic>? proof;
  final String? adminReviewNote;

  const ActiveTaskScreen({
    super.key,
    required this.matchRecordId,
    required this.task,
    this.ngoName,
    this.ngoPhone,
    this.ngoEmail,
    this.coordinatorPhone = '',
    this.status = 'accepted',
    this.proof,
    this.adminReviewNote,
  });

  @override
  State<ActiveTaskScreen> createState() => _ActiveTaskScreenState();
}

class _ActiveTaskScreenState extends State<ActiveTaskScreen> {
  static const String _ngoDummyPhone = '+919876543210';
  static const String _coordinatorDummyPhone = '+919123456789';

  late Future<Map<String, String>> _ngoInfoFuture;

  String _cleanPhone(String? raw) {
    return (raw ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
  }

  String _effectiveNgoPhone(String? raw) {
    final phone = _cleanPhone(raw);
    return phone.isEmpty ? _ngoDummyPhone : phone;
  }

  String _effectiveCoordinatorPhone(String? raw) {
    final phone = _cleanPhone(raw);
    return phone.isEmpty ? _coordinatorDummyPhone : phone;
  }

  @override
  void initState() {
    super.initState();
    _ngoInfoFuture = _fetchNgoInfo();
  }

  Future<Map<String, String>> _fetchNgoInfo() async {
    // If all info is provided, return immediately
    if (widget.ngoName != null && widget.ngoPhone != null && widget.ngoEmail != null) {
      return {
        'name': widget.ngoName!,
        'phone': widget.ngoPhone!,
        'email': widget.ngoEmail!,
      };
    }

    try {
      final problemDoc = await FirebaseFirestore.instance.collection('problem_cards').doc(widget.task.problemCardId).get();
      if (!problemDoc.exists) throw 'Problem not found';
      
      final ngoId = problemDoc.data()?['ngoId'];
      if (ngoId == null) throw 'NGO ID missing';

      final ngoDoc = await FirebaseFirestore.instance.collection('ngo_profiles').doc(ngoId).get();
      if (ngoDoc.exists) {
        return {
          'name': ngoDoc['name'] ?? 'Coordinator',
          'phone': _cleanPhone(ngoDoc['phone'] as String?),
          'email': ngoDoc['email'] ?? '',
        };
      }

      final legacyDoc = await FirebaseFirestore.instance.collection('users').doc(ngoId).get();
      if (!legacyDoc.exists) throw 'NGO Profile not found';

      return {
        'name': legacyDoc['name'] ?? 'Coordinator',
        'phone': _cleanPhone(legacyDoc['phone'] as String?),
        'email': legacyDoc['email'] ?? '',
      };
    } catch (e) {
      return {
        'name': widget.ngoName ?? 'Coordinator',
        'phone': widget.ngoPhone ?? '',
        'email': widget.ngoEmail ?? '',
      };
    }
  }

  void _openDirections() async {
    final geo = widget.task.locationGeoPoint;
    if (geo != null) {
      final url = Uri.parse('https://maps.google.com/?q=${geo.latitude},${geo.longitude}');
      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: T('Could not open Maps.')));
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: T('Location not available.')));
    }
  }

  void _callCoordinator(String? phoneInput) async {
    final phone = _effectiveNgoPhone(phoneInput);
    final url = Uri.parse('tel:$phone');
    try {
      await launchUrl(url);
    } catch (_) {}
  }

  void _callCoordinatorDirect() async {
    final phone = _effectiveCoordinatorPhone(widget.coordinatorPhone);
    final url = Uri.parse('tel:$phone');
    try {
      await launchUrl(url);
    } catch (_) {}
  }

  void _showProofSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ProofSubmissionSheet(matchRecordId: widget.matchRecordId, task: widget.task),
    ).then((submitted) {
      if (submitted == true && mounted) {
        SuccessOverlay.show(
          context,
          'Proof submitted!\nWaiting for NGO review.',
          onComplete: () => Navigator.of(context).pop(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bool isCompleted = widget.status == 'proof_approved';
    final bool isSubmitted = widget.status == 'proof_submitted';
    final bool isRejected = widget.status == 'proof_rejected';
    final bool isReadOnly = isCompleted || isSubmitted;

    return FutureBuilder<Map<String, String>>(
      future: _ngoInfoFuture,
      builder: (context, ngoSnapshot) {
        final ngoInfo = ngoSnapshot.data ?? {
          'name': widget.ngoName ?? 'Coordinator',
          'phone': widget.ngoPhone ?? '',
          'email': widget.ngoEmail ?? '',
        };

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('tasks').doc(widget.task.id).snapshots(),
          builder: (context, taskSnapshot) {
            final taskData = taskSnapshot.data?.data() as Map<String, dynamic>?;
            final bool teamSubmitted = taskData?['isProofSubmitted'] ?? false;
            final bool canSubmit = !isReadOnly && !teamSubmitted;

        return Scaffold(
          appBar: AppBar(
            title: T(isReadOnly ? 'Mission Summary' : 'Active Mission', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            actions: [
              IconButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => TaskChatScreen(
                    taskId: widget.task.id,
                    taskTitle: widget.task.taskType.name.replaceAll('_', ' '),
                    profileCollection: 'volunteer_profiles',
                  ),
                )),
                icon: const Icon(Icons.forum_rounded),
                tooltip: 'Coordination Chat',
              ),
              const SizedBox(width: 8),
            ],
          ),
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
                        isCompleted
                            ? Icons.verified_rounded
                            : (isSubmitted || teamSubmitted
                                  ? Icons.hourglass_top_rounded
                                  : (isRejected
                                        ? Icons.refresh_rounded
                                        : Icons.run_circle_rounded)),
                        size: 56,
                        color: (isCompleted) ? Colors.white : cs.primary,
                      ),
                      const SizedBox(height: 16),
                      T(
                        isCompleted
                            ? 'Mission Completed'
                            : (isSubmitted
                                  ? 'Awaiting Review'
                                  : (teamSubmitted
                                      ? 'Team member submitted proof'
                                      : (isRejected
                                            ? 'Proof needs revision'
                                            : 'Mission is active'))),
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      T(
                        isCompleted
                            ? 'Thank you for your incredible service!'
                            : (isSubmitted
                                  ? 'We\'ll notify you once the NGO reviews it.'
                                  : (teamSubmitted
                                      ? 'Submission is pending NGO approval.'
                                      : (isRejected
                                            ? 'Please review the NGO feedback and upload updated proof.'
                                            : 'Head to the location and complete the task.'))),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),

            const SizedBox(height: 28),

            VolunteerTeamList(
              volunteerIds: List<String>.from(taskData?['assignedVolunteerIds'] ?? widget.task.assignedVolunteerIds),
              title: 'Your Team',
            ),

            const SizedBox(height: 28),

            if (isRejected && (widget.adminReviewNote?.trim().isNotEmpty ?? false)) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SahayaColors.coral.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: SahayaColors.coral.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T(
                      'NGO Feedback',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: SahayaColors.coral,
                      ),
                    ),
                    const SizedBox(height: 8),
                    T(
                      widget.adminReviewNote!.trim(),
                      style: GoogleFonts.inter(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ─── Proof Section ───
            if (isReadOnly && widget.proof != null) ...[
              T('Your Submission', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
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
                  Expanded(child: _actionCard(Icons.call_rounded, 'Call NGO', SahayaColors.amber, () => _callCoordinator(ngoInfo['phone']), isDark)),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // ─── Coordinator ───
            T('Coordinator', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? SahayaColors.darkBorder : SahayaColors.lightBorder),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(radius: 24, backgroundColor: cs.primary.withValues(alpha: 0.1), child: Icon(Icons.person_rounded, color: cs.primary)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        T(ngoInfo['name'] ?? 'Coordinator', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                        T(_effectiveNgoPhone(ngoInfo['phone']), style: GoogleFonts.inter(fontSize: 13, color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted)),
                      ])),
                      if (!isReadOnly)
                        IconButton(onPressed: () => _callCoordinator(ngoInfo['phone']), icon: const Icon(Icons.call_rounded, color: SahayaColors.amber)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      CircleAvatar(radius: 24, backgroundColor: SahayaColors.amber.withValues(alpha: 0.1), child: const Icon(Icons.support_agent_rounded, color: SahayaColors.amber)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        T('Field Coordinator', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                        T(_effectiveCoordinatorPhone(widget.coordinatorPhone), style: GoogleFonts.inter(fontSize: 13, color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted)),
                      ])),
                      if (!isReadOnly)
                        IconButton(onPressed: _callCoordinatorDirect, icon: const Icon(Icons.call_rounded, color: SahayaColors.amber)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── Task ───
            T('Task Outline', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            T(widget.task.description, style: GoogleFonts.inter(fontSize: 15, height: 1.6, color: isDark ? SahayaColors.darkMuted : const Color(0xFF374151))),

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
                  onPressed: !canSubmit ? null : () {
                    HapticFeedback.lightImpact();
                    _showProofSheet();
                  },
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: T(teamSubmitted ? 'Submitted by team' : 'Submit proof', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        );
      },
    );
  },
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
            T('NOTE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: cs.primary, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            T(note, style: GoogleFonts.inter(fontSize: 14, height: 1.4)),
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
            T(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
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
  final TaskModel task;
  const ProofSubmissionSheet({super.key, required this.matchRecordId, required this.task});

  @override
  State<ProofSubmissionSheet> createState() => _ProofSubmissionSheetState();
}

class _ProofSubmissionSheetState extends State<ProofSubmissionSheet> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _images = [];
  final TextEditingController _noteCtrl = TextEditingController();
  bool _submitting = false;
  
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (val) => debugPrint('Speech Error: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _noteCtrl.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  bool _isPicking = false;

  Future<void> _pickImages() async {
    if (_isPicking) return;
    _isPicking = true;
    try {
      final imgs = await _picker.pickMultiImage();
      if (imgs.isNotEmpty && mounted) {
        setState(() {
          _images.addAll(imgs);
          if (_images.length > 3) _images = _images.sublist(0, 3);
        });
      }
    } on PlatformException catch (e) {
      debugPrint('PlatformException picking images: $e');
      if (e.code == 'already_active') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: T('Image picker is already open. Please complete or cancel the current selection.'),
            backgroundColor: SahayaColors.amber,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    } finally {
      if (mounted) _isPicking = false;
    }
  }

  Future<void> _submit() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: T('Attach at least 1 photo.'), backgroundColor: SahayaColors.coral));
      return;
    }
    setState(() => _submitting = true);
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      bool isOffline = connectivityResult.contains(ConnectivityResult.none);

      if (isOffline) {
        // Queue the proof offline
        List<String> paths = _images.map((f) => f.path).toList();
        await OfflineProofSyncService.queueOfflineProof(
          matchRecordId: widget.matchRecordId,
          localImagePaths: paths,
          note: _noteCtrl.text.trim(),
        );

        await OfflineProofSyncService.queueTaskUpdate(
          matchRecordId: widget.matchRecordId,
          taskId: widget.task.id,
          volunteerId: '',
          updates: {
            'matchStatus': 'proof_submitted',
            'taskStatus': widget.task.status.name,
            'offlineNote': _noteCtrl.text.trim(),
          },
          localMergeNote: _noteCtrl.text.trim(),
        );

        if (mounted) {
          SuccessOverlay.show(
            context,
            'Offline Mode:\nProof saved securely.\nIt will sync automatically when online.',
            onComplete: () => Navigator.of(context).pop(true),
          );
        }
        return;
      }

      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
      final preset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
      final cloudinary = CloudinaryPublic(cloudName, preset, cache: false);

      // Check if already submitted by team just before uploading
      final preCheck = await FirebaseFirestore.instance.collection('tasks').doc(widget.task.id).get();
      if (preCheck.exists && (preCheck.data()?['isProofSubmitted'] ?? false)) {
        throw Exception('A team member already submitted proof just now.');
      }

      List<String> urls = [];
      for (var img in _images) {
        final resp = await cloudinary.uploadFile(CloudinaryFile.fromFile(img.path, resourceType: CloudinaryResourceType.Image));
        urls.add(resp.secureUrl);
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final taskRef = FirebaseFirestore.instance.collection('tasks').doc(widget.task.id);
        final matchRef = FirebaseFirestore.instance.collection('match_records').doc(widget.matchRecordId);
        
        final taskSnap = await transaction.get(taskRef);
        if (taskSnap.exists && (taskSnap.data()?['isProofSubmitted'] ?? false)) {
          throw Exception('A team member already submitted proof while you were uploading.');
        }

        transaction.update(matchRef, {
          'proof': {'photoUrls': urls, 'secureUrls': urls, 'note': _noteCtrl.text.trim(), 'submittedAt': FieldValue.serverTimestamp()},
          'status': 'proof_submitted',
          'aiVerificationLabel': FieldValue.delete(),
          'aiVerificationReason': FieldValue.delete(),
          'aiVerifiedAt': FieldValue.delete(),
        });

        transaction.update(taskRef, {
          'isProofSubmitted': true,
        });
      });

      final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:5000';
      try {
        await http.post(
          Uri.parse('$backendUrl/notify-proof-submitted'), 
          headers: {'Content-Type': 'application/json'}, 
          body: jsonEncode({'matchRecordId': widget.matchRecordId})
        ).timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('Backend relay failed: $e');
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: T('Upload failed: $e'), backgroundColor: SahayaColors.coral));
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
          T('Submit Proof', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          T('Upload up to 3 photos of your work.', style: GoogleFonts.inter(color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted)),
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
                  T('Tap to select photos', style: GoogleFonts.inter(color: cs.primary, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),

          const SizedBox(height: 20),
          TextField(
            controller: _noteCtrl, 
            maxLength: 200, 
            maxLines: null, 
            decoration: InputDecoration(
              hintText: 'Anything the NGO should know?',
              suffixIcon: GestureDetector(
                onTap: _listen,
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? SahayaColors.coral : cs.primary,
                ),
              ),
            )
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : T('Submit', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
