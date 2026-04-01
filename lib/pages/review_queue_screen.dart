import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/problem_card.dart';
import '../models/raw_upload.dart';
import '../components/review_card_dialog.dart';
import '../components/list_shimmer.dart';
import 'manual_entry_form.dart';

class ReviewQueueScreen extends StatelessWidget {
  final String ngoId;
  const ReviewQueueScreen({super.key, required this.ngoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Pending Human Review Queue',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('problem_cards')
            .where('ngoId', isEqualTo: ngoId)
            .where(
              'status',
              whereIn: [
                ProblemStatus.pending_review.name,
                ProblemStatus.extraction_failed.name,
              ],
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Structural Generic Reject natively intercepted: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListShimmer(itemCount: 6);
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.green,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Target Review Queue is entirely purged.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final struct = () {
                try {
                  return ProblemCard.fromJson({...data, 'id': docs[index].id});
                } catch (_) {
                  return ProblemCard(
                    id: docs[index].id,
                    ngoId: data['ngoId'] as String? ?? ngoId,
                    issueType: IssueType.other,
                    locationWard: 'Manual Review Required',
                    locationCity: 'Manual Review Required',
                    locationGeoPoint: const GeoPoint(0, 0),
                    severityLevel: SeverityLevel.medium,
                    affectedCount: 0,
                    description:
                        'Extraction failed for this upload. Please complete manual entry.',
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
              }();
              final isExtractionFailed =
                  struct.status == ProblemStatus.extraction_failed;

              Color confidenceColor = Colors.green;
              if (struct.confidenceScore < 0.70) {
                confidenceColor = Colors.red;
              } else if (struct.confidenceScore <= 0.85) {
                confidenceColor = Colors.orange;
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                elevation: 0,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: struct.confidenceScore,
                        backgroundColor: Colors.grey[100],
                        color: confidenceColor,
                      ),
                      const Icon(
                        Icons.science,
                        size: 16,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                  title: Text(
                    struct.issueType.name.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    isExtractionFailed
                        ? 'Manual entry required before approval'
                        : "${struct.locationWard}, ${struct.locationCity}\nSeverity: ${struct.severityLevel.name.toUpperCase()}",
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.blueAccent,
                  ),
                  onTap: () async {
                    if (isExtractionFailed) {
                      final rawDoc = await FirebaseFirestore.instance
                          .collection('raw_uploads')
                          .doc(struct.id)
                          .get();
                      if (!context.mounted) return;

                      if (!rawDoc.exists || rawDoc.data() == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Raw upload not found for manual entry.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final upload = RawUpload.fromJson({
                        ...rawDoc.data()!,
                        'id': rawDoc.id,
                      });

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => ManualEntryFormDialog(upload: upload),
                      );
                      return;
                    }

                    showDialog(
                      context: context,
                      builder: (_) => ReviewCardDialog(draftCard: struct),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
