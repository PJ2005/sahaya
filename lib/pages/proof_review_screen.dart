import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../components/list_shimmer.dart';
import '../theme/sahaya_theme.dart';
import 'proof_detail_screen.dart';
import '../utils/translator.dart';


class ProofReviewScreen extends StatelessWidget {
  final String ngoId;
  const ProofReviewScreen({super.key, required this.ngoId});

  Future<List<_ProofReviewItem>> _loadPendingForNgo() async {
    final pendingSnap = await FirebaseFirestore.instance
        .collection('match_records')
        .where('status', isEqualTo: 'proof_submitted')
        .get();

    if (pendingSnap.docs.isEmpty) {
      return <_ProofReviewItem>[];
    }

    final taskCache = <String, Map<String, dynamic>?>{};
    final cardCache = <String, String?>{};
    final items = <_ProofReviewItem>[];

    for (final doc in pendingSnap.docs) {
      final data = doc.data();
      final taskId = (data['taskId'] as String?) ?? '';
      if (taskId.isEmpty) {
        continue;
      }

      Map<String, dynamic>? taskData = taskCache[taskId];
      if (!taskCache.containsKey(taskId)) {
        final taskDoc = await FirebaseFirestore.instance
            .collection('tasks')
            .doc(taskId)
            .get();
        taskData = taskDoc.data();
        taskCache[taskId] = taskData;
      }
      if (taskData == null) {
        continue;
      }

      final cardId = (taskData['problemCardId'] as String?) ?? '';
      if (cardId.isEmpty) {
        continue;
      }

      String? ownerNgoId = cardCache[cardId];
      if (!cardCache.containsKey(cardId)) {
        final cardDoc = await FirebaseFirestore.instance
            .collection('problem_cards')
            .doc(cardId)
            .get();
        ownerNgoId = cardDoc.data()?['ngoId'] as String?;
        cardCache[cardId] = ownerNgoId;
      }

      if (ownerNgoId == ngoId) {
        items.add(_ProofReviewItem(matchRecordId: doc.id, matchData: data));
      }
    }

    items.sort((a, b) {
      final aProof = a.matchData['proof'] as Map<String, dynamic>?;
      final bProof = b.matchData['proof'] as Map<String, dynamic>?;
      final aTs = aProof?['submittedAt'];
      final bTs = bProof?['submittedAt'];
      final aMillis = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
      final bMillis = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
      return bMillis.compareTo(aMillis);
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: T(
          'Proof Reviews',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: -1,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('match_records')
            .where('status', isEqualTo: 'proof_submitted')
            .snapshots(),
        builder: (context, matchSnapshot) {
          if (matchSnapshot.hasError) {
            return _emptyState(context);
          }
          if (matchSnapshot.connectionState == ConnectionState.waiting &&
              !matchSnapshot.hasData) {
            return const ListShimmer(itemCount: 6);
          }

          return FutureBuilder<List<_ProofReviewItem>>(
            future: _loadPendingForNgo(),
            builder: (context, filteredSnapshot) {
              if (filteredSnapshot.connectionState == ConnectionState.waiting) {
                return const ListShimmer(itemCount: 6);
              }

              final pending = filteredSnapshot.data ?? const <_ProofReviewItem>[];
              if (pending.isEmpty) {
                return _emptyState(context);
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                itemCount: pending.length,
                itemBuilder: (context, index) {
                  final item = pending[index];
                  return _ProofBlock(
                    matchRecordId: item.matchRecordId,
                    matchData: item.matchData,
                  );
                },
              );
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
          Icon(
            Icons.verified_user_outlined,
            size: 64,
            color: SahayaColors.emerald.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          T(
            'Nothing to review!',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 8),
          T(
            'All volunteer proofs are reviewed.',
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofReviewItem {
  final String matchRecordId;
  final Map<String, dynamic> matchData;

  const _ProofReviewItem({
    required this.matchRecordId,
    required this.matchData,
  });
}

class _ProofBlock extends StatefulWidget {
  final String matchRecordId;
  final Map<String, dynamic> matchData;

  const _ProofBlock({required this.matchRecordId, required this.matchData});

  @override
  State<_ProofBlock> createState() => _ProofBlockState();
}

class _ProofBlockState extends State<_ProofBlock> {
  String? _taskDesc;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  Future<void> _loadTask() async {
    final taskId = widget.matchData['taskId'] as String? ?? '';
    if (taskId.isEmpty) {
      return;
    }

    try {
      final taskDoc = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .get();
      if (taskDoc.exists && mounted) {
        setState(() => _taskDesc = taskDoc.data()?['description'] as String?);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final volId = (widget.matchData['volunteerId'] as String? ?? 'N/A');
    final shortVol = volId.length > 8 ? '${volId.substring(0, 8)}...' : volId;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProofDetailScreen(
            matchRecordId: widget.matchRecordId,
            matchData: widget.matchData,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? SahayaColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: SahayaColors.amber.withValues(alpha: 0.6),
            width: 2,
          ),
          boxShadow: [sahayaCardShadow(context)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _miniPill(
                  context,
                  'VERIFICATION PENDING',
                  SahayaColors.amber.withValues(alpha: 0.1),
                  SahayaColors.amber,
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 14),
            T(
              _taskDesc ?? 'Loading task details...',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.person_pin_outlined,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: T(
                    'Volunteer $shortVol',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                T(
                  'TAP TO REVIEW',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: SahayaColors.amber,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniPill(BuildContext context, String text, Color bg, Color fg) {
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
}
