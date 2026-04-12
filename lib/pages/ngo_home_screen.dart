import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/problem_card.dart';
import '../components/list_shimmer.dart';
import '../theme/sahaya_theme.dart';
import '../app.dart';
import 'proof_review_screen.dart';
import 'ngo_task_detail_screen.dart';
import 'ngo_create_problem_screen.dart';

class NgoHomeScreen extends StatelessWidget {
  final String ngoId;
  const NgoHomeScreen({super.key, required this.ngoId});

  ProblemCard _safeProblemCardFromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final issueTypeName = (data['issueType'] as String?) ?? 'other';
    final severityName = (data['severityLevel'] as String?) ?? 'medium';
    final statusName = (data['status'] as String?) ?? 'approved';

    final issueType = IssueType.values.firstWhere(
      (v) => v.name == issueTypeName,
      orElse: () => IssueType.other,
    );
    final severity = SeverityLevel.values.firstWhere(
      (v) => v.name == severityName,
      orElse: () => SeverityLevel.medium,
    );
    final status = ProblemStatus.values.firstWhere(
      (v) => v.name == statusName,
      orElse: () => ProblemStatus.approved,
    );

    final geoPoint = data['locationGeoPoint'] is GeoPoint
        ? data['locationGeoPoint'] as GeoPoint
        : const GeoPoint(0, 0);

    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    double asDouble(dynamic value, double fallback) {
      if (value is num) return value.toDouble();
      return fallback;
    }

    int asInt(dynamic value, int fallback) {
      if (value is num) return value.toInt();
      return fallback;
    }

    return ProblemCard(
      id: doc.id,
      ngoId: (data['ngoId'] as String?) ?? ngoId,
      issueType: issueType,
      locationWard: (data['locationWard'] as String?) ?? 'Unknown Ward',
      locationCity: (data['locationCity'] as String?) ?? 'Unknown City',
      locationGeoPoint: geoPoint,
      severityLevel: severity,
      affectedCount: asInt(data['affectedCount'], 0),
      description: (data['description'] as String?) ?? '',
      confidenceScore: asDouble(data['confidenceScore'], 0),
      status: status,
      priorityScore: asDouble(data['priorityScore'], 0),
      severityContrib: asDouble(data['severityContrib'], 0),
      scaleContrib: asDouble(data['scaleContrib'], 0),
      recencyContrib: asDouble(data['recencyContrib'], 0),
      gapContrib: asDouble(data['gapContrib'], 0),
      createdAt: createdAt,
      anonymized: (data['anonymized'] as bool?) ?? true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sahaya Admin',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: -1,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            onPressed: () => themeProvider.toggle(),
          ),
          _pendingProofsBadge(context),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('problem_cards')
            .where('ngoId', isEqualTo: ngoId)
            .where('status', isEqualTo: 'approved')
            .orderBy('priorityScore', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListShimmer(itemCount: 6);
          }
          final docs = snapshot.data?.docs ?? [];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHero(context, docs.length)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        'ACTIVE PROBLEM CARDS',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.sort_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              if (docs.isEmpty)
                SliverFillRemaining(child: _emptyState(context))
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final card = _safeProblemCardFromDoc(docs[index]);
                      return NgoTaskBlock(card: card);
                    }, childCount: docs.length),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => NgoCreateProblemScreen(ngoId: ngoId),
            ),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('New Problem', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHero(BuildContext context, int activeCount) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [const Color(0xFF111827), const Color(0xFF1F2937)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good morning,',
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'NGO Coordinator',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  backgroundColor: cs.primary.withValues(alpha: 0.2),
                  radius: 20,
                  child: Icon(Icons.person_pin_rounded, color: cs.primary),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _statsItem('Active Cards', activeCount.toString()),
                const SizedBox(width: 32),
                _statsItem('Avg Priority', 'High'),
                const SizedBox(width: 32),
                _statsItem('Reach', '8.4k'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsItem(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          val,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  Widget _pendingProofsBadge(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('problem_cards')
          .where('ngoId', isEqualTo: ngoId)
          .snapshots(),
      builder: (context, cardsSnapshot) {
        if (!cardsSnapshot.hasData) return const SizedBox.shrink();
        final cardIds = cardsSnapshot.data!.docs.map((doc) => doc.id).toSet();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance 
              .collection('match_records')
              .where('status', isEqualTo: 'proof_submitted')
              .snapshots(),
          builder: (context, matchSnapshot) {
            if (!matchSnapshot.hasData) return const SizedBox.shrink();
            
            return FutureBuilder<int>(
              future: _countMyPendingProofs(matchSnapshot.data!.docs, cardIds),
              builder: (context, countSnapshot) {
                final count = countSnapshot.data ?? 0;
                return IconButton(
                  icon: Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count', style: const TextStyle(fontSize: 10)),
                    child: const Icon(Icons.fact_check_outlined),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProofReviewScreen(ngoId: ngoId),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<int> _countMyPendingProofs(List<QueryDocumentSnapshot> matchDocs, Set<String> myCardIds) async {
    if (matchDocs.isEmpty) return 0;
    int count = 0;
    for (final mDoc in matchDocs) {
      final mData = mDoc.data() as Map<String, dynamic>;
      final taskId = mData['taskId'] as String? ?? '';
      if (taskId.isEmpty) continue;
      
      final tDoc = await FirebaseFirestore.instance.collection('tasks').doc(taskId).get();
      if (tDoc.exists) {
        final tData = tDoc.data() as Map<String, dynamic>;
        final problemCardId = tData['problemCardId'] as String? ?? '';
        if (myCardIds.contains(problemCardId)) {
          count++;
        }
      }
    }
    return count;
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dashboard_customize_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No approved cards yet',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Approve cards from the Review Queue',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _aiAssistantPrompt(context),
        ],
      ),
    );
  }

  Widget _aiAssistantPrompt(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, color: cs.primary),
          const SizedBox(height: 10),
          Text(
            'Try the AI assistant — describe any change in plain English.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Open a Review Queue item and tap AI Assistant to describe edits in plain English.',
                ),
              ),
            ),
            child: const Text('Open AI Assistant'),
          ),
        ],
      ),
    );
  }
}

class NgoTaskBlock extends StatelessWidget {
  final ProblemCard card;
  const NgoTaskBlock({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color severityColor = SahayaColors.emerald;
    switch (card.severityLevel) {
      case SeverityLevel.critical:
        severityColor = SahayaColors.coral;
        break;
      case SeverityLevel.high:
        severityColor = SahayaColors.amber;
        break;
      case SeverityLevel.medium:
        severityColor = SahayaColors.emerald;
        break;
      case SeverityLevel.low:
        severityColor = Colors.teal;
        break;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NgoTaskDetailScreen(card: card)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? SahayaColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: severityColor.withValues(alpha: 0.6),
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
                  card.issueType.name.replaceAll('_', ' ').toUpperCase(),
                  cs.primary.withValues(alpha: 0.1),
                  cs.primary,
                ),
                const Spacer(),
                Text(
                  'PRIORITY ${card.priorityScore.toInt()}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    color: severityColor,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              card.description,
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
                  Icons.location_on_outlined,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${card.locationWard}, ${card.locationCity}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.groups_outlined,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${card.affectedCount}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
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
      child: Text(
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
