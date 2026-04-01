import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/list_shimmer.dart';
import '../theme/sahaya_theme.dart';

class NgoImpactDashboardScreen extends StatefulWidget {
  final String ngoId;
  const NgoImpactDashboardScreen({super.key, required this.ngoId});

  @override
  State<NgoImpactDashboardScreen> createState() => _NgoImpactDashboardScreenState();
}

class _NgoImpactDashboardScreenState extends State<NgoImpactDashboardScreen> {
  int _daysWindow = 30;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final windowStart = DateTime.now().subtract(Duration(days: _daysWindow));

    return Scaffold(
      appBar: AppBar(
        title: Text('Impact Metrics', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Time Window Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text('WINDOW:', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: cs.onSurfaceVariant, letterSpacing: 1)),
                const Spacer(),
                _toggleButton(7, '7D'),
                const SizedBox(width: 8),
                _toggleButton(30, '30D'),
                const SizedBox(width: 8),
                _toggleButton(90, '90D'),
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('problem_cards').where('ngoId', isEqualTo: widget.ngoId).snapshots(),
              builder: (context, cardsSnapshot) {
                if (cardsSnapshot.connectionState == ConnectionState.waiting) return const ListShimmer(itemCount: 6);
                final cards = cardsSnapshot.data?.docs ?? [];
                if (cards.isEmpty) return _buildNoData(context);

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('tasks').snapshots(),
                  builder: (context, tasksSnapshot) {
                    if (!tasksSnapshot.hasData) return const ListShimmer(itemCount: 6);

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('match_records').snapshots(),
                      builder: (context, matchSnapshot) {
                        if (!matchSnapshot.hasData) return const ListShimmer(itemCount: 6);

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('raw_uploads').where('ngoId', isEqualTo: widget.ngoId).snapshots(),
                          builder: (context, uploadsSnapshot) {
                            if (!uploadsSnapshot.hasData) return const ListShimmer(itemCount: 6);

                            final metrics = _computeMetrics(
                              cards,
                              tasksSnapshot.data!.docs,
                              matchSnapshot.data!.docs,
                              uploadsSnapshot.data!.docs,
                              windowStart,
                            );

                            return ListView(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              children: [
                                // KPI Grid
                                _buildKpiGrid(metrics),
                                
                                const SizedBox(height: 24),

                                // Main Chart Card
                                _buildImpactCard(context, metrics, cs, isDark),
                                const SizedBox(height: 20),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton(int days, String label) {
    final cs = Theme.of(context).colorScheme;
    final active = _daysWindow == days;
    return GestureDetector(
      onTap: () => setState(() => _daysWindow = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? Colors.transparent : cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: active ? Colors.white : cs.onSurfaceVariant)),
      ),
    );
  }

  Widget _buildKpiGrid(_ImpactMetrics metrics) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _KpiCard(title: 'TIME TO FIRST TASK', value: '${metrics.avgHoursToFirstTask.toStringAsFixed(1)}h', subtitle: 'Ingestion delay', icon: Icons.speed_rounded, color: SahayaColors.emerald)),
            const SizedBox(width: 12),
            Expanded(child: _KpiCard(title: 'PRIORITY COVERED', value: '${metrics.priorityCoveragePercent.toStringAsFixed(0)}%', subtitle: 'Critical needs', icon: Icons.priority_high_rounded, color: SahayaColors.amber)),
          ],
        ),
        const SizedBox(height: 12),
        _KpiCard(
          title: 'TASK COMPLETION RATE', 
          value: '${metrics.taskCompletionRatePercent.toStringAsFixed(1)}%', 
          subtitle: 'Active vs Finished tasks within the time window', 
          icon: Icons.check_circle_outline_rounded, 
          color: const Color(0xFF6366F1), 
          isWide: true,
        ),
      ],
    );
  }

  Widget _buildImpactCard(BuildContext context, _ImpactMetrics metrics, ColorScheme cs, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [sahayaCardShadow(context)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 12, height: 12, decoration: const BoxDecoration(color: SahayaColors.emerald, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Text('COMPLETIONS BY ISSUE', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 280,
            child: BarChart(
              BarChartData(
                maxY: metrics.maxChartY,
                barGroups: metrics.chartGroups,
                gridData: FlGridData(show: true, horizontalInterval: 1, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.2), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark ? const Color(0xFF334155) : Colors.black,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipBorderRadius: BorderRadius.circular(8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${metrics.labels[groupIndex]}\n${rod.toY.toInt()} Finished',
                        GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 32, interval: 1,
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(v.toInt().toString(), style: GoogleFonts.inter(fontSize: 10, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= metrics.labels.length) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          space: 12,
                          child: Text(metrics.labels[index], style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoData(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('Analyze your NGO\'s Impact', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Start approving tasks to see live KPIs.', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  _ImpactMetrics _computeMetrics(
    List<QueryDocumentSnapshot> cardDocs,
    List<QueryDocumentSnapshot> taskDocs,
    List<QueryDocumentSnapshot> matchDocs,
    List<QueryDocumentSnapshot> uploadDocs,
    DateTime windowStart,
  ) {
    final cardById = <String, Map<String, dynamic>>{};
    final cardIds = <String>{};
    for (final doc in cardDocs) {
      final data = doc.data() as Map<String, dynamic>;
      cardById[doc.id] = data;
      cardIds.add(doc.id);
    }

    final uploadTimeById = <String, DateTime>{};
    for (final doc in uploadDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final uploadedAt = _asDate(data['uploadedAt']);
      if (uploadedAt != null) uploadTimeById[doc.id] = uploadedAt;
    }

    final tasksByCard = <String, List<Map<String, dynamic>>>{};
    final taskToCardId = <String, String>{};
    for (final doc in taskDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final problemCardId = data['problemCardId'] as String? ?? '';
      if (!cardIds.contains(problemCardId)) continue;
      tasksByCard.putIfAbsent(problemCardId, () => []).add(data);
      taskToCardId[doc.id] = problemCardId;
    }

    // Delay computation
    double avgHoursToFirstTask = 0;
    final delays = <double>[];
    for (final entry in tasksByCard.entries) {
      DateTime? firstTaskTime;
      for (final task in entry.value) {
        final created = _asDate(task['createdAt']);
        if (created == null) continue;
        if (firstTaskTime == null || created.isBefore(firstTaskTime)) firstTaskTime = created;
      }
      if (firstTaskTime == null || firstTaskTime.isBefore(windowStart)) continue;

      final rawUploadId = _rawUploadIdForCard(entry.key);
      final uploadedAt = uploadTimeById[rawUploadId];
      if (uploadedAt == null || firstTaskTime.isBefore(uploadedAt)) continue;

      delays.add(firstTaskTime.difference(uploadedAt).inMinutes / 60.0);
    }
    if (delays.isNotEmpty) avgHoursToFirstTask = delays.reduce((a, b) => a + b) / delays.length;

    // Completion Rates
    final approvedMatchTaskIds = <String>{};
    int approvedInWindow = 0;
    int acceptedInWindow = 0;
    final acceptedStatuses = {'accepted', 'proof_submitted', 'proof_rejected', 'proof_approved'};

    for (final doc in matchDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      final taskId = data['taskId'] as String? ?? '';
      if (status == 'proof_approved' && taskId.isNotEmpty) approvedMatchTaskIds.add(taskId);

      final createdAt = _asDate(data['createdAt']);
      final completedAt = _asDate(data['completedAt']);

      if (acceptedStatuses.contains(status) && createdAt != null && !createdAt.isBefore(windowStart)) acceptedInWindow += 1;
      
      final approvalTime = completedAt ?? createdAt;
      if (status == 'proof_approved' && approvalTime != null && !approvalTime.isBefore(windowStart)) approvedInWindow += 1;
    }

    // Priority
    final priorityCards = cardById.entries.where((e) => ((e.value['priorityScore'] as num?)?.toDouble() ?? 0) > 70).toList();
    int coveredPriorityCards = 0;
    for (final card in priorityCards) {
      final hasApproved = (tasksByCard[card.key] ?? []).any((t) => approvedMatchTaskIds.contains(t['id'] ?? ''));
      if (hasApproved) coveredPriorityCards += 1;
    }

    final priorityCoveragePercent = priorityCards.isEmpty ? 0.0 : (coveredPriorityCards / priorityCards.length) * 100.0;
    final taskCompletionRatePercent = acceptedInWindow == 0 ? 0.0 : (approvedInWindow / acceptedInWindow) * 100.0;

    // Bar Chart Multi-color Logic
    final issueOrder = ['water_access', 'sanitation', 'education', 'nutrition', 'healthcare', 'livelihood', 'other'];
    final categoryColors = [
      const Color(0xFF3B82F6), // Water (Blue)
      const Color(0xFFF59E0B), // Sanitation (Amber)
      const Color(0xFF8B5CF6), // Education (Purple)
      const Color(0xFF10B981), // Nutrition (Green)
      const Color(0xFFEF4444), // Healthcare (Red)
      const Color(0xFF14B8A6), // Livelihood (Teal)
      const Color(0xFF94A3B8), // Other (Slate)
    ];

    final completionsByIssue = <String, int>{for (final i in issueOrder) i: 0};
    for (final doc in matchDocs) {
      final data = doc.data() as Map<String, dynamic>;
      if ((data['status'] as String? ?? '') != 'proof_approved') continue;
      final completedAt = _asDate(data['completedAt']) ?? _asDate(data['createdAt']);
      if (completedAt == null || completedAt.isBefore(windowStart)) continue;
      final tid = data['taskId'] as String? ?? '';
      final cid = taskToCardId[tid];
      if (cid == null) continue;
      final issue = (cardById[cid]?['issueType'] as String? ?? 'other').trim();
      if (!completionsByIssue.containsKey(issue)) {
        completionsByIssue['other'] = (completionsByIssue['other'] ?? 0) + 1;
      } else {
        completionsByIssue[issue] = (completionsByIssue[issue] ?? 0) + 1;
      }
    }

    final labels = ['Water', 'San.', 'Edu.', 'Nutri.', 'Health', 'Live.', 'Other'];
    final chartValues = issueOrder.map((k) => (completionsByIssue[k] ?? 0).toDouble()).toList();
    final chartGroups = <BarChartGroupData>[];
    for (int i = 0; i < chartValues.length; i++) {
      chartGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: chartValues[i],
              width: 22,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              color: categoryColors[i],
              gradient: LinearGradient(
                colors: [categoryColors[i], categoryColors[i].withValues(alpha: 0.6)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ],
        ),
      );
    }

    final maxCount = chartValues.fold<double>(0, (prev, v) => v > prev ? v : prev);
    final maxChartY = maxCount < 4 ? 4.0 : maxCount + 1;

    return _ImpactMetrics(
      avgHoursToFirstTask: avgHoursToFirstTask,
      priorityCoveragePercent: priorityCoveragePercent,
      taskCompletionRatePercent: taskCompletionRatePercent,
      labels: labels,
      chartGroups: chartGroups,
      maxChartY: maxChartY,
    );
  }

  DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _rawUploadIdForCard(String cardId) {
    final parts = cardId.split('_');
    return parts.isEmpty ? cardId : parts.first;
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isWide;

  const _KpiCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.color, this.isWide = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [sahayaCardShadow(context)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: cs.onSurfaceVariant, letterSpacing: 0.8)),
                const SizedBox(height: 12),
                Text(value, style: GoogleFonts.inter(fontSize: 28, color: color, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500, height: 1.3)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 22),
          ),
        ],
      ),
    );
  }
}

class _ImpactMetrics {
  final double avgHoursToFirstTask;
  final double priorityCoveragePercent;
  final double taskCompletionRatePercent;
  final List<String> labels;
  final List<BarChartGroupData> chartGroups;
  final double maxChartY;
  _ImpactMetrics({required this.avgHoursToFirstTask, required this.priorityCoveragePercent, required this.taskCompletionRatePercent, required this.labels, required this.chartGroups, required this.maxChartY});
}
