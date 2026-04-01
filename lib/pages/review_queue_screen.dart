import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/problem_card.dart';
import '../models/raw_upload.dart';
import '../components/list_shimmer.dart';
import '../theme/sahaya_theme.dart';
import 'review_detail_screen.dart';
import 'manual_entry_form.dart';

class ReviewQueueScreen extends StatelessWidget {
  final String ngoId;
  const ReviewQueueScreen({super.key, required this.ngoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Review Queue', 
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -1)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('problem_cards')
            .where('ngoId', isEqualTo: ngoId)
            .where('status', whereIn: [
              ProblemStatus.pending_review.name,
              ProblemStatus.extraction_failed.name,
            ])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListShimmer(itemCount: 6);
          }
          final docs = snapshot.data?.docs ?? [];
          
          if (docs.isEmpty) {
            return _emptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              ProblemCard card;
              try {
                card = ProblemCard.fromJson({...data, 'id': doc.id});
              } catch (_) {
                card = ProblemCard(
                  id: doc.id,
                  ngoId: ngoId,
                  issueType: IssueType.other,
                  locationWard: 'Manual Review',
                  locationCity: 'Required',
                  locationGeoPoint: const GeoPoint(0, 0),
                  severityLevel: SeverityLevel.medium,
                  affectedCount: 0,
                  description: 'AI Extraction failed or data is corrupted. Please review manually.',
                  confidenceScore: 0,
                  status: ProblemStatus.extraction_failed,
                  priorityScore: 0,
                  severityContrib: 0,
                  scaleContrib: 0,
                  recencyContrib: 0,
                  gapContrib: 0,
                  createdAt: DateTime.now(),
                  anonymized: true,
                );
              }

              return _ReviewBlock(card: card);
            },
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.done_all_rounded, size: 64, color: SahayaColors.emerald.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('Nothing to review!', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 8),
          Text('All reports have been processed.', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ReviewBlock extends StatelessWidget {
  final ProblemCard card;
  const _ReviewBlock({required this.card});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Border color based on confidence or status
    Color borderColor = SahayaColors.amber;
    if (card.status == ProblemStatus.extraction_failed) {
      borderColor = SahayaColors.coral;
    } else if (card.confidenceScore > 0.8) {
      borderColor = SahayaColors.emerald;
    }

    return GestureDetector(
      onTap: () => _navigateToDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? SahayaColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 2),
          boxShadow: [sahayaCardShadow(context)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _miniPill(context, 'PENDING REVIEW', borderColor.withValues(alpha: 0.1), borderColor),
                const Spacer(),
                if (card.status != ProblemStatus.extraction_failed)
                  Text('${(card.confidenceScore * 100).toInt()}% CONFIDENCE', 
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: borderColor, fontSize: 10, letterSpacing: 0.5)),
              ],
            ),
            const SizedBox(height: 14),
            Text(card.description, 
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3), 
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(child: Text('${card.locationWard}, ${card.locationCity}', 
                  style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500))),
                Icon(Icons.auto_awesome_outlined, size: 14, color: cs.primary),
                const SizedBox(width: 4),
                Text('AI DRAFT', style: GoogleFonts.inter(fontSize: 10, color: cs.primary, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context) async {
    if (card.status == ProblemStatus.extraction_failed) {
      // Find the raw upload first
      final snap = await FirebaseFirestore.instance.collection('raw_uploads').where('problemCardId', isEqualTo: card.id).limit(1).get();
      if (snap.docs.isNotEmpty) {
        final upload = RawUpload.fromJson({...snap.docs.first.data(), 'id': snap.docs.first.id});
        if (context.mounted) {
          showDialog(context: context, builder: (_) => ManualEntryFormDialog(upload: upload));
        }
      } else {
        // Just show a message or generic fallback
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Raw evidence not found for this card.')));
        }
      }
      return;
    }

    // Normal review
    final linkSnap = await FirebaseFirestore.instance.collection('raw_uploads').where('problemCardId', isEqualTo: card.id).limit(1).get();
    
    if (linkSnap.docs.isNotEmpty && context.mounted) {
      final upload = RawUpload.fromJson({...linkSnap.docs.first.data(), 'id': linkSnap.docs.first.id});
      Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewDetailScreen(upload: upload, extraction: card.toJson())));
    } else {
       if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Raw evidence not found for this card.')));
        }
    }
  }

  Widget _miniPill(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}
