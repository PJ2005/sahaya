import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/raw_upload.dart';
import '../components/ai_assistant_sheet.dart';
import '../services/location_geocode_service.dart';
import '../theme/sahaya_theme.dart';

class ReviewDetailScreen extends StatefulWidget {
  final RawUpload upload;
  final Map<String, dynamic> extraction;

  const ReviewDetailScreen({
    super.key,
    required this.upload,
    required this.extraction,
  });

  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  late Map<String, dynamic> _editedData;
  bool _saving = false;
  late final String _cardId;

  @override
  void initState() {
    super.initState();
    _editedData = Map<String, dynamic>.from(widget.extraction);
    _cardId = (widget.extraction['id']?.toString().isNotEmpty ?? false)
        ? widget.extraction['id'].toString()
        : widget.upload.id;
  }

  Future<void> _approve() async {
    setState(() => _saving = true);
    try {
      final locationGeoPoint =
          await LocationGeocodeService.approximateFromFields(
            ward: _editedData['locationWard']?.toString() ?? '',
            city: _editedData['locationCity']?.toString(),
          );

      await FirebaseFirestore.instance
          .collection('problem_cards')
          .doc(_cardId)
          .set({
            ..._editedData,
            'id': _cardId,
            'ngoId': widget.upload.ngoId,
            'status': 'approved',
            'createdAt': FieldValue.serverTimestamp(),
            'confidenceScore': 0.9,
            'locationGeoPoint': locationGeoPoint,
            'priorityScore': 50.0, // Initial priority
          }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('raw_uploads')
          .doc(widget.upload.id)
          .update({'status': 'done', 'problemCardId': _cardId});

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error approving: $e');
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final upload = widget.upload;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Review Extraction',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => AiAssistantSheet.show(
              context,
              currentData: _editedData,
              contextDescription: 'an AI extraction review',
              onResult: (mod) {
                setState(() => _editedData = mod);
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media Preview
            _buildMediaPreview(upload),
            const SizedBox(height: 24),

            // Form
            _buildField('Issue Type', 'issueType', Icons.category_outlined),
            _buildField(
              'Severity',
              'severityLevel',
              Icons.warning_amber_rounded,
            ),
            _buildField('Ward', 'locationWard', Icons.map_outlined),
            _buildField(
              'Affected Count',
              'affectedCount',
              Icons.people_outline,
            ),
            _buildField(
              'Description',
              'description',
              Icons.description_outlined,
              maxLines: 4,
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saving ? null : _approve,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _saving ? 'Processing...' : 'Approve & Create Problem Card',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Discard Extraction',
                  style: TextStyle(
                    color: SahayaColors.coral,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(RawUpload upload) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [sahayaCardShadow(context)],
      ),
      clipBehavior: Clip.antiAlias,
      child: upload.fileType == 'image'
          ? Image.network(
              upload.cloudinaryUrl,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, prog) => prog == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_collection_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Video Evidence',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildField(
    String label,
    String key,
    IconData icon, {
    int maxLines = 1,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _editedData[key]?.toString(),
            maxLines: maxLines,
            onChanged: (v) => _editedData[key] = v,
            decoration: InputDecoration(
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? SahayaColors.darkSurface
                  : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
