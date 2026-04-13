import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/raw_upload.dart';
import '../components/ai_assistant_sheet.dart';
import '../services/location_geocode_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../theme/sahaya_theme.dart';
import '../utils/translator.dart';
import 'ngo_dashboard.dart';


class ReviewDetailScreen extends StatefulWidget {
  final RawUpload? upload;
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
        : (widget.upload?.id ?? 'manual_draft');
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
            'ngoId': widget.upload?.ngoId ?? widget.extraction['ngoId'],
            'status': 'approved',
            'createdAt': FieldValue.serverTimestamp(),
            'confidenceScore': 0.9,
            'locationGeoPoint': locationGeoPoint,
            'priorityScore': 50.0, // Initial priority
          }, SetOptions(merge: true));

      if (widget.upload != null) {
        await FirebaseFirestore.instance
            .collection('raw_uploads')
            .doc(widget.upload!.id)
            .update({'status': 'done', 'problemCardId': _cardId});
      }

      final ngoId =
          (widget.upload?.ngoId ?? widget.extraction['ngoId'] ?? '')
              .toString();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: T('Building Action Plan & Connecting Volunteers...'), duration: Duration(seconds: 2)),
        );
      }

      if (mounted) {
        if (ngoId.isNotEmpty) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => NgoDashboard(ngoId: ngoId)),
            (route) => false,
          );
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }

      // Fire and forget: user should not wait for backend decomposition/matching.
      Future<void>(() async {
        try {
          final backendUrl = dotenv.env['BACKEND_URL'] ?? 'https://telegram-webhook-c7dxdhg6czb6bpdt.southindia-01.azurewebsites.net';
          final response = await http.post(
            Uri.parse('$backendUrl/generate-tasks'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'problemCardId': _cardId,
              'ngoId': ngoId,
            }),
          );
          if (response.statusCode != 200) {
            debugPrint('Flask matching sequence failed cleanly: ${response.body}');
          }
        } catch (e) {
          debugPrint('Flask unreachable natively: $e');
        }
      });
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
        title: T(
          'Review Extraction',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media Preview
            _buildMediaPreview(upload),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const T(
                  'AI Assistant',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => AiAssistantSheet.show(
                  context,
                  currentData: _editedData,
                  contextDescription: 'an AI extraction review',
                  onResult: (mod) {
                    setState(() => _editedData = mod);
                  },
                ),
              ),
            ),
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
                child: T(
                  _saving ? 'Processing...' : 'Approve & Create Problem Card',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SahayaColors.coral,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  side: BorderSide(
                    color: SahayaColors.coral.withValues(alpha: 0.45),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.close_rounded, size: 18),
                      const SizedBox(width: 8),
                      const T(
                        'Discard Extraction',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(RawUpload? upload) {
    if (upload == null) {
      return Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_none_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            T('No Media (Direct Entry)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
          ],
        ),
      );
    }
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
                  T(
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
              T(
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
