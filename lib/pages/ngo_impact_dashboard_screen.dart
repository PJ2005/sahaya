import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../components/list_shimmer.dart';

class NgoImpactDashboardScreen extends StatelessWidget {
  final String ngoId;

  const NgoImpactDashboardScreen({super.key, required this.ngoId});

  @override
  Widget build(BuildContext context) {
    final windowStart = DateTime.now().subtract(const Duration(days: 30));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Impact Dashboard',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('problem_cards')
            .where('ngoId', isEqualTo: ngoId)
            .snapshots(),
        builder: (context, cardsSnapshot) {
          if (cardsSnapshot.hasError) {
            return Center(child: Text('Error: ${cardsSnapshot.error}'));
          }
          if (cardsSnapshot.connectionState == ConnectionState.waiting) {
            return const ListShimmer(itemCount: 6);
          }

          final cards = cardsSnapshot.data?.docs ?? [];
          if (cards.isEmpty) {
            return const Center(
              child: Text(
                'No data yet. Approve problem cards to unlock impact KPIs.',
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('tasks').snapshots(),
            builder: (context, tasksSnapshot) {
              if (tasksSnapshot.hasError) {
                return Center(child: Text('Error: ${tasksSnapshot.error}'));
              }
              if (!tasksSnapshot.hasData) {
                return const ListShimmer(itemCount: 6);
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('match_records')
                    .snapshots(),
                builder: (context, matchSnapshot) {
                  if (matchSnapshot.hasError) {
                    return Center(child: Text('Error: ${matchSnapshot.error}'));
                  }
                  if (!matchSnapshot.hasData) {
                    return const ListShimmer(itemCount: 6);
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('raw_uploads')
                        .where('ngoId', isEqualTo: ngoId)
                        .snapshots(),
                    builder: (context, uploadsSnapshot) {
                      if (uploadsSnapshot.hasError) {
                        return Center(
                          child: Text('Error: ${uploadsSnapshot.error}'),
                        );
                      }
                      if (!uploadsSnapshot.hasData) {
                        return const ListShimmer(itemCount: 6);
                      }

                      final metrics = _computeMetrics(
                        cards,
                        tasksSnapshot.data!.docs,
                        matchSnapshot.data!.docs,
                        uploadsSnapshot.data!.docs,
                        windowStart,
                      );

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _KpiCard(
                                title: 'Avg upload to first task',
                                value:
                                    '${metrics.avgHoursToFirstTask.toStringAsFixed(1)}h',
                                subtitle: 'Last 30 days',
                                color: const Color(0xFF1565C0),
                              ),
                              _KpiCard(
                                title: 'Priority needs covered',
                                value:
                                    '${metrics.priorityCoveragePercent.toStringAsFixed(1)}%',
                                subtitle: 'Priority score > 70',
                                color: const Color(0xFF2E7D32),
                              ),
                              _KpiCard(
                                title: 'Task completion rate',
                                value:
                                    '${metrics.taskCompletionRatePercent.toStringAsFixed(1)}%',
                                subtitle: 'Approved / accepted (30d)',
                                color: const Color(0xFFF57C00),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Completions by Issue Type',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 260,
                                  child: BarChart(
                                    BarChartData(
                                      maxY: metrics.maxChartY,
                                      barGroups: metrics.chartGroups,
                                      gridData: FlGridData(
                                        show: true,
                                        horizontalInterval: 1,
                                        drawVerticalLine: false,
                                      ),
                                      borderData: FlBorderData(show: false),
                                      titlesData: FlTitlesData(
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 28,
                                            interval: 1,
                                            getTitlesWidget: (v, meta) => Text(
                                              v.toInt().toString(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 38,
                                            getTitlesWidget: (value, meta) {
                                              final index = value.toInt();
                                              if (index < 0 ||
                                                  index >=
                                                      metrics.labels.length) {
                                                return const SizedBox.shrink();
                                              }
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                child: Text(
                                                  metrics.labels[index],
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
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
                          ),
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
      if (uploadedAt != null) {
        uploadTimeById[doc.id] = uploadedAt;
      }
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

    double avgHoursToFirstTask = 0;
    final delays = <double>[];
    for (final entry in tasksByCard.entries) {
      DateTime? firstTaskTime;
      for (final task in entry.value) {
        final created = _asDate(task['createdAt']);
        if (created == null) continue;
        if (firstTaskTime == null || created.isBefore(firstTaskTime)) {
          firstTaskTime = created;
        }
      }
      if (firstTaskTime == null || firstTaskTime.isBefore(windowStart)) {
        continue;
      }

      final rawUploadId = _rawUploadIdForCard(entry.key);
      final uploadedAt = uploadTimeById[rawUploadId];
      if (uploadedAt == null || firstTaskTime.isBefore(uploadedAt)) continue;

      final hours = firstTaskTime.difference(uploadedAt).inMinutes / 60.0;
      delays.add(hours);
    }
    if (delays.isNotEmpty) {
      avgHoursToFirstTask = delays.reduce((a, b) => a + b) / delays.length;
    }

    final approvedMatchTaskIds = <String>{};
    int approvedInWindow = 0;
    int acceptedInWindow = 0;

    final acceptedStatuses = {
      'accepted',
      'proof_submitted',
      'proof_rejected',
      'proof_approved',
    };

    for (final doc in matchDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      final taskId = data['taskId'] as String? ?? '';
      if (status == 'proof_approved' && taskId.isNotEmpty) {
        approvedMatchTaskIds.add(taskId);
      }

      final createdAt = _asDate(data['createdAt']);
      final completedAt = _asDate(data['completedAt']);

      if (acceptedStatuses.contains(status) &&
          createdAt != null &&
          !createdAt.isBefore(windowStart)) {
        acceptedInWindow += 1;
      }

      final approvalTime = completedAt ?? createdAt;
      if (status == 'proof_approved' &&
          approvalTime != null &&
          !approvalTime.isBefore(windowStart)) {
        approvedInWindow += 1;
      }
    }

    final priorityCards = cardById.entries
        .where(
          (entry) =>
              ((entry.value['priorityScore'] as num?)?.toDouble() ?? 0) > 70,
        )
        .toList();

    int coveredPriorityCards = 0;
    for (final card in priorityCards) {
      final taskList = tasksByCard[card.key] ?? const [];
      final hasApproved = taskList.any((task) {
        final taskId = task['id'] as String? ?? '';
        return taskId.isNotEmpty && approvedMatchTaskIds.contains(taskId);
      });
      if (hasApproved) {
        coveredPriorityCards += 1;
      }
    }

    final priorityCoveragePercent = priorityCards.isEmpty
        ? 0.0
        : (coveredPriorityCards / priorityCards.length) * 100.0;

    final taskCompletionRatePercent = acceptedInWindow == 0
        ? 0.0
        : (approvedInWindow / acceptedInWindow) * 100.0;

    final issueOrder = [
      'water_access',
      'sanitation',
      'education',
      'nutrition',
      'healthcare',
      'livelihood',
      'other',
    ];

    final completionsByIssue = <String, int>{for (final i in issueOrder) i: 0};

    for (final doc in matchDocs) {
      final data = doc.data() as Map<String, dynamic>;
      if ((data['status'] as String? ?? '') != 'proof_approved') continue;

      final completedAt =
          _asDate(data['completedAt']) ?? _asDate(data['createdAt']);
      if (completedAt == null || completedAt.isBefore(windowStart)) continue;

      final taskId = data['taskId'] as String? ?? '';
      final cardId = taskToCardId[taskId];
      if (cardId == null) continue;

      final issue = (cardById[cardId]?['issueType'] as String? ?? 'other')
          .trim();
      if (!completionsByIssue.containsKey(issue)) {
        completionsByIssue['other'] = (completionsByIssue['other'] ?? 0) + 1;
      } else {
        completionsByIssue[issue] = (completionsByIssue[issue] ?? 0) + 1;
      }
    }

    final labels = [
      'Water',
      'San.',
      'Edu.',
      'Nutri.',
      'Health',
      'Live.',
      'Other',
    ];
    final chartValues = issueOrder
        .map((k) => (completionsByIssue[k] ?? 0).toDouble())
        .toList();

    final chartGroups = <BarChartGroupData>[];
    for (int i = 0; i < chartValues.length; i++) {
      chartGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: chartValues[i],
              width: 18,
              borderRadius: BorderRadius.circular(4),
              color: const Color(0xFF1976D2),
            ),
          ],
        ),
      );
    }

    final maxCount = chartValues.fold<double>(
      0,
      (prev, v) => v > prev ? v : prev,
    );
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
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidth = (MediaQuery.of(context).size.width - 44) / 2;

    return Container(
      width: cardWidth < 240 ? double.infinity : cardWidth,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.black45),
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

  const _ImpactMetrics({
    required this.avgHoursToFirstTask,
    required this.priorityCoveragePercent,
    required this.taskCompletionRatePercent,
    required this.labels,
    required this.chartGroups,
    required this.maxChartY,
  });
}
