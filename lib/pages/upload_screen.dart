import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../models/raw_upload.dart';
import '../models/problem_card.dart';
import '../services/gemini_service.dart';
import 'package:uuid/uuid.dart';
import '../components/list_shimmer.dart';
import '../theme/sahaya_theme.dart';
import '../utils/translator.dart';

class UploadScreen extends StatefulWidget {
  final String ngoId;

  const UploadScreen({super.key, required this.ngoId});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _pastedTextController = TextEditingController();
  final Set<String> _processingUploadIds = {};
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pastedTextController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'png',
          'jpg',
          'jpeg',
          'csv',
          'docx',
          'txt',
          'mp3',
          'wav',
          'm4a',
          'aac',
          'ogg',
        ],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isUploading = true);
        await _uploadPath(
          path: result.files.single.path!,
          fileType: _fileTypeFromExtension(
            result.files.single.extension?.toLowerCase() ?? '',
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File uploaded successfully!'), backgroundColor: SahayaColors.emerald),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: SahayaColors.coral),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadPastedText() async {
    final text = _pastedTextController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste or type some field notes first.'),
          backgroundColor: SahayaColors.coral,
        ),
      );
      return;
    }

    try {
      setState(() => _isUploading = true);
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}\\survey_notes_${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(text);
      await _uploadPath(path: file.path, fileType: 'text');
      _pastedTextController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Text notes uploaded successfully!'),
            backgroundColor: SahayaColors.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Text upload failed: $e'),
            backgroundColor: SahayaColors.coral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadPath({
    required String path,
    required String fileType,
  }) async {
    final cloudinary = CloudinaryPublic(
      dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'demo',
      dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? 'preset',
      cache: false,
    );

    final response = await cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        path,
        resourceType: CloudinaryResourceType.Auto,
      ),
    );

    final String docId = const Uuid().v4();
    final rawUpload = RawUpload(
      id: docId,
      ngoId: widget.ngoId,
      cloudinaryUrl: response.secureUrl,
      cloudinaryPublicId: response.publicId,
      fileType: fileType,
      uploadedAt: DateTime.now(),
      status: UploadStatus.pending,
    );

    await _db.collection('raw_uploads').doc(docId).set(rawUpload.toJson());
  }

  String _fileTypeFromExtension(String ext) {
    if (['png', 'jpg', 'jpeg', 'webp'].contains(ext)) return 'image';
    if (ext == 'csv') return 'csv';
    if (ext == 'txt') return 'text';
    if (['mp3', 'wav', 'm4a', 'aac', 'ogg', 'oga'].contains(ext)) {
      return 'audio';
    }
    return 'document';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: T('Smart Ingestion', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header / Tabs
          Container(
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? SahayaColors.darkSurface : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurfaceVariant,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.upload_file, size: 16), SizedBox(width: 8), T('Direct Upload')])),
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.telegram, size: 16), SizedBox(width: 8), T('Telegram Sync')])),
              ],
            ),
          ),

          // Main Interactive Area (60-70% height)
          Expanded(
            flex: 6,
            child: TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(child: _buildDirectUpload(context)),
                SingleChildScrollView(child: _buildTelegramSync(context)),
              ],
            ),
          ),

          // Sync Feed Section (30-40% height)
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: SahayaColors.emerald, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                T('LIVE SYNC FEED', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: cs.primary, letterSpacing: 1)),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: _buildRecentUploads(),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectUpload(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _isUploading ? null : _pickAndUploadFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48),
              decoration: BoxDecoration(
                color: isDark ? SahayaColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cs.primary.withValues(alpha: 0.2), width: 2),
                boxShadow: [sahayaCardShadow(context)],
              ),
              child: Column(
                children: [
                  if (_isUploading)
                    CircularProgressIndicator(color: cs.primary)
                  else
                    Icon(Icons.cloud_upload_rounded, size: 64, color: cs.primary),
                  const SizedBox(height: 20),
                  T(_isUploading ? 'Uploading to cloud...' : 'Press to select files', 
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  T('PDF, TXT, audio notes, CSV, DOCX or images', 
                    style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? SahayaColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
              boxShadow: [sahayaCardShadow(context)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notes_rounded, color: cs.primary),
                    const SizedBox(width: 10),
                    Text(
                      'Paste field notes directly',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pastedTextController,
                  maxLines: 7,
                  minLines: 5,
                  decoration: InputDecoration(
                    hintText:
                        'Paste copied survey notes, call transcripts, or rough observations here...',
                    filled: true,
                    fillColor:
                        isDark ? SahayaColors.darkBg : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _uploadPastedText,
                    icon: const Icon(Icons.auto_awesome),
                    label: const T('Upload pasted text for Gemini'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          T(
            'Files, pasted notes, and voice recordings uploaded here are automatically processed by Sahaya AI to extract problem reports, severity levels, and locations.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTelegramSync(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String registerCmd = '/register ${widget.ngoId}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? SahayaColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF0088cc).withValues(alpha: 0.3)),
              boxShadow: [sahayaCardShadow(context)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.telegram, color: Color(0xFF0088cc), size: 28),
                    const SizedBox(width: 12),
                    Text('Telegram Assistant', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 24),
                Text('YOUR REGISTRATION COMMAND', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0088cc).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0088cc).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(registerCmd, style: GoogleFonts.firaCode(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0088cc))),
                      ),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: registerCmd));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Command copied to clipboard!')));
                        },
                        icon: const Icon(Icons.copy_rounded, size: 20, color: Color(0xFF0088cc)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('CONNECTION STEPS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
                const SizedBox(height: 12),
                _stepRow(context, '1', 'Install Telegram on your mobile device.'),
                _stepRow(context, '2', 'Find @Sahaya_Helper_bot in search.'),
                _stepRow(context, '3', 'Send the registration command copied above.'),
                _stepRow(context, '4', 'Send pasted text, voice notes, text files, photos, or documents.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(BuildContext context, String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$num.', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF0088cc))),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 13, color: Theme.of(context).colorScheme.onSurface, height: 1.3))),
        ],
      ),
    );
  }

  Widget _buildRecentUploads() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('raw_uploads').where('ngoId', isEqualTo: widget.ngoId).orderBy('uploadedAt', descending: true).limit(10).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const ListShimmer(itemCount: 4);
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sync_disabled_rounded, size: 32, color: cs.outlineVariant),
                const SizedBox(height: 8),
                Text('No recent syncs', style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final raw = RawUpload.fromJson({...data, 'id': docs[index].id});

            Color statusColor = SahayaColors.amber;
            if (raw.status == UploadStatus.done) statusColor = SahayaColors.emerald;
            if (raw.status == UploadStatus.extraction_failed) statusColor = SahayaColors.coral;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? SahayaColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(
                      raw.fileType == 'image'
                          ? Icons.image_outlined
                          : raw.fileType == 'csv'
                              ? Icons.table_chart_outlined
                              : raw.fileType == 'audio'
                                  ? Icons.mic_none_rounded
                                  : raw.fileType == 'text'
                                      ? Icons.notes_rounded
                                      : Icons.description_outlined,
                      size: 18, color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${raw.fileType.toUpperCase()} PAYLOAD', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text(_fmtTime(raw.uploadedAt), style: GoogleFonts.inter(fontSize: 10, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  _miniPill(context, raw.status.name.toUpperCase(), statusColor.withValues(alpha: 0.1), statusColor),
                  if (raw.status == UploadStatus.pending) ...[
                    const SizedBox(width: 8),
                    if (_processingUploadIds.contains(raw.id))
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _processUpload(raw),
                        icon: Icon(Icons.auto_awesome, color: cs.primary, size: 18),
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _processUpload(RawUpload raw) async {
    setState(() => _processingUploadIds.add(raw.id));

    try {
      final draftCards = await GeminiService.structureProblemCard(raw);
      for (var draftCard in draftCards) {
        await FirebaseFirestore.instance.collection('problem_cards').doc(draftCard.id).set(draftCard.toJson());
      }
      await FirebaseFirestore.instance.collection('raw_uploads').doc(raw.id).update({'status': 'done'});
    } catch (e) {
      await _handleExtractionFailure(raw, e);
    } finally {
      if (mounted) setState(() => _processingUploadIds.remove(raw.id));
    }
  }

  Future<void> _handleExtractionFailure(RawUpload raw, dynamic e) async {
    await FirebaseFirestore.instance.collection('raw_uploads').doc(raw.id).update({'status': 'extraction_failed'});
    await FirebaseFirestore.instance.collection('problem_cards').doc(raw.id).set({
      'id': raw.id,
      'ngoId': raw.ngoId,
      'issueType': IssueType.other.name,
      'locationWard': 'Manual Review Required',
      'locationCity': 'Manual Review Required',
      'locationGeoPoint': const GeoPoint(0, 0),
      'severityLevel': SeverityLevel.medium.name,
      'affectedCount': 0,
      'description': 'AI extraction failed. Manual entry required. ($e)',
      'confidenceScore': 0.0,
      'status': ProblemStatus.extraction_failed.name,
      'priorityScore': 0.0,
      'severityContrib': 0.0,
      'scaleContrib': 0.0,
      'recencyContrib': 0.0,
      'gapContrib': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'anonymized': true,
    }, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Extraction failed. Review in queue.'), backgroundColor: SahayaColors.coral));
    }
  }

  String _fmtTime(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  Widget _miniPill(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: fg)),
    );
  }
}
