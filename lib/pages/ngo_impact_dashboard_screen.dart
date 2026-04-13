import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../components/list_shimmer.dart';
import '../models/problem_card.dart';
import '../theme/sahaya_theme.dart';
import '../l10n/app_text.dart';
import '../utils/translator.dart';


class NgoImpactDashboardScreen extends StatefulWidget {
  final String ngoId;
  const NgoImpactDashboardScreen({super.key, required this.ngoId});

  @override
  State<NgoImpactDashboardScreen> createState() => _NgoImpactDashboardScreenState();
}

class _NgoImpactDashboardScreenState extends State<NgoImpactDashboardScreen> {
  int _daysWindow = 30;
  double _shortagePercent = 20;
  double _surgePercent = 30;
  double _horizonDays = 7;
  bool _simLoading = false;
  Map<String, dynamic>? _simResult;
  final Map<String, DateTime?> _uploadedAtCache = <String, DateTime?>{};
  List<QueryDocumentSnapshot> _lastCards = <QueryDocumentSnapshot>[];
  List<QueryDocumentSnapshot> _lastMatches = <QueryDocumentSnapshot>[];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final windowStart = DateTime.now().subtract(Duration(days: _daysWindow));

    return Scaffold(
      appBar: AppBar(
        title: T('Impact Metrics', 
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Time Window Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                T('WINDOW:', 
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, 
                    color: cs.onSurfaceVariant, letterSpacing: 1)),
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
              stream: FirebaseFirestore.instance
                  .collection('problem_cards')
                  .where('ngoId', isEqualTo: widget.ngoId)
                  .snapshots(),
              builder: (context, cardsSnapshot) {
                if (cardsSnapshot.connectionState == ConnectionState.waiting) return const ListShimmer(itemCount: 6);
                final cards = cardsSnapshot.data?.docs ?? [];
                if (cards.isEmpty) return _buildNoData(context);

                return FutureBuilder<Map<String, List<QueryDocumentSnapshot>>>(
                  future: _loadAnalyticsData(cards),
                  builder: (context, dataSnapshot) {
                    if (!dataSnapshot.hasData) return const ListShimmer(itemCount: 6);
                    
                    final tasks = dataSnapshot.data!['tasks']!;
                    final matches = dataSnapshot.data!['matches']!;

                    _lastCards = cards;
                    _lastMatches = matches;

                    return FutureBuilder<_ImpactMetrics>(
                      future: _computeMetrics(
                        cards,
                        tasks,
                        matches,
                        windowStart,
                      ),
                      builder: (context, metricsSnapshot) {
                        if (!metricsSnapshot.hasData) {
                          return const ListShimmer(itemCount: 6);
                        }

                        final metrics = metricsSnapshot.data!;
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          children: [
                            _buildKpiGrid(metrics),
                            const SizedBox(height: 24),
                            _buildImpactCard(context, metrics, cs, isDark),
                            const SizedBox(height: 20),
                            _buildIncidentQueueCard(context),
                            const SizedBox(height: 20),
                            _buildScenarioSimulatorCard(context),
                            const SizedBox(height: 20),
                          ],
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
        child: T(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: active ? Colors.white : cs.onSurfaceVariant)),
      ),
    );
  }

  Widget _buildKpiGrid(_ImpactMetrics metrics) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _KpiCard(title: 'TIME TO FIRST TASK', value: '${metrics.avgHoursToFirstTask.toStringAsFixed(1)}h', subtitle: 'Ingestion delay', icon: Icons.speed_rounded, color: SahayaColors.emerald, onTap: () => _openKpiDrilldown('time_to_first_task'))),
            const SizedBox(width: 12),
            Expanded(child: _KpiCard(title: 'PRIORITY COVERED', value: '${metrics.priorityCoveragePercent.toStringAsFixed(0)}%', subtitle: 'Critical needs', icon: Icons.priority_high_rounded, color: SahayaColors.amber, onTap: () => _openKpiDrilldown('priority_covered'))),
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
          onTap: () => _openKpiDrilldown('completion_rate'),
        ),
      ],
    );
  }

  Widget _buildIncidentQueueCard(BuildContext context) {
    final t = AppText.of(context);
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadIncidentQueue(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
              boxShadow: [sahayaCardShadow(context)],
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final incidents = snapshot.data!;
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
                  const Icon(Icons.warning_amber_rounded, color: SahayaColors.coral),
                  const SizedBox(width: 8),
                  T(t.incidentQueue, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                ],
              ),
              const SizedBox(height: 12),
              if (incidents.isEmpty)
                T('No stale accepted tasks right now.', style: GoogleFonts.inter(color: cs.onSurfaceVariant))
              else
                ...incidents.take(4).map((it) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      T(it['taskDescription'] ?? 'Task', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 4),
                      T('Stale ${it['hoursStale']}h • ${it['sdgTag']}', style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () => _redispatchTask(it['taskId'] as String),
                          icon: const Icon(Icons.restart_alt_rounded, size: 16),
                          label: const T('Redispatch'),
                        ),
                      ),
                    ],
                  ),
                )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScenarioSimulatorCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final projection = _simResult?['projection'] as Map<String, dynamic>?;
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
              const Icon(Icons.science_outlined, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              T('SCENARIO SIMULATOR', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 14),
          _buildSliderRow('Volunteer shortage', _shortagePercent, 0, 70, '%', (v) => setState(() => _shortagePercent = v)),
          _buildSliderRow('Demand surge', _surgePercent, 0, 200, '%', (v) => setState(() => _surgePercent = v)),
          _buildSliderRow('Horizon', _horizonDays, 1, 30, 'days', (v) => setState(() => _horizonDays = v)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _simLoading ? null : _runScenarioSimulation,
              icon: _simLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow_rounded, size: 18),
              label: T(_simLoading ? 'Running...' : 'Run Simulation'),
            ),
          ),
          if (projection != null) ...[
            const SizedBox(height: 14),
            T(
              'Coverage ${projection['projectedCoveragePercent']}% • Backlog ${projection['expectedBacklogSlots']} slots',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 6),
            T(
              'Delay ${projection['expectedDelayHours']}h • Risk ${projection['riskLevel']}',
              style: GoogleFonts.inter(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    String unit,
    ValueChanged<double> onChanged,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            T(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
            const Spacer(),
            T('${value.toStringAsFixed(0)}$unit', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
        Slider(value: value, min: min, max: max, divisions: (max - min).toInt(), onChanged: onChanged),
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
              T('COMPLETIONS BY ISSUE', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
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
                        child: T(v.toInt().toString(), style: GoogleFonts.inter(fontSize: 10, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
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
                          child: T(metrics.labels[index], style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
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
          T('Analyze your NGO\'s Impact', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          T('Start approving tasks to see live KPIs.', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Future<Map<String, List<QueryDocumentSnapshot>>> _loadAnalyticsData(List<QueryDocumentSnapshot> cards) async {
    final cardIds = cards.map((c) => c.id).toList();
    if (cardIds.isEmpty) return {'tasks': [], 'matches': []};

    final tasksSnapshot = await FirebaseFirestore.instance
        .collection('tasks')
        .where('problemCardId', whereIn: cardIds.take(10).toList())
        .get();
        
    final taskIds = tasksSnapshot.docs.map((t) => t.id).toList();
    if (taskIds.isEmpty) {
      return {'tasks': tasksSnapshot.docs, 'matches': []};
    }

    final matchesSnapshot = await FirebaseFirestore.instance
        .collection('match_records')
        .where('taskId', whereIn: taskIds.take(10).toList())
        .get();

    return {
      'tasks': tasksSnapshot.docs,
      'matches': matchesSnapshot.docs,
    };
  }

  Future<_ImpactMetrics> _computeMetrics(
    List<QueryDocumentSnapshot> cardDocs,
    List<QueryDocumentSnapshot> taskDocs,
    List<QueryDocumentSnapshot> matchDocs,
    DateTime windowStart,
  ) async {
    final cardById = <String, Map<String, dynamic>>{};
    final cardIds = <String>{};
    for (final doc in cardDocs) {
      final data = doc.data() as Map<String, dynamic>;
      cardById[doc.id] = data;
      cardIds.add(doc.id);
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
      if (firstTaskTime == null) continue;

      final uploadedAt = await _uploadedAtForCard(entry.key);
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

  Future<DateTime?> _uploadedAtForCard(String cardId) async {
    if (_uploadedAtCache.containsKey(cardId)) {
      return _uploadedAtCache[cardId];
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('raw_uploads')
          .where('ngoId', isEqualTo: widget.ngoId)
          .where('problemCardId', isEqualTo: cardId)
          .limit(1)
          .get();

      DateTime? uploadedAt;
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        uploadedAt = _asDate(data['uploadedAt']);
      }

      _uploadedAtCache[cardId] = uploadedAt;
      return uploadedAt;
    } catch (_) {
      _uploadedAtCache[cardId] = null;
      return null;
    }
  }

  String _sdgTagForIssue(String issue) {
    return IssueTypeX.fromString(issue).sdgTag;
  }

  Future<List<Map<String, dynamic>>> _loadIncidentQueue() async {
    final acceptedSnapshot = await FirebaseFirestore.instance
        .collection('match_records')
        .where('status', isEqualTo: 'accepted')
        .get();

    final now = DateTime.now();
    final incidents = <Map<String, dynamic>>[];

    for (final doc in acceptedSnapshot.docs) {
      final data = doc.data();
      final createdAt = _asDate(data['createdAt']);
      if (createdAt == null) continue;
      final hours = now.difference(createdAt).inHours;
      if (hours < 8) continue;

      final taskId = data['taskId'] as String? ?? '';
      if (taskId.isEmpty) continue;

      final taskDoc = await FirebaseFirestore.instance.collection('tasks').doc(taskId).get();
      if (!taskDoc.exists) continue;
      final taskData = taskDoc.data() as Map<String, dynamic>;
      final cardId = taskData['problemCardId'] as String? ?? '';
      if (cardId.isEmpty) continue;

      final cardDoc = await FirebaseFirestore.instance.collection('problem_cards').doc(cardId).get();
      if (!cardDoc.exists) continue;
      final cardData = cardDoc.data() as Map<String, dynamic>;
      if ((cardData['ngoId'] as String?) != widget.ngoId) continue;

      final issue = (cardData['issueType'] as String?) ?? 'other';
      incidents.add({
        'matchId': doc.id,
        'taskId': taskId,
        'taskDescription': (taskData['description'] as String?) ?? 'Task',
        'hoursStale': hours,
        'sdgTag': _sdgTagForIssue(issue),
      });
    }

    incidents.sort((a, b) => (b['hoursStale'] as int).compareTo(a['hoursStale'] as int));
    return incidents;
  }

  Future<void> _redispatchTask(String taskId) async {
    final backendUrl = dotenv.env['BACKEND_URL'] ?? 'https://sahaya-faas-puz67as73a-uc.a.run.app';
    try {
      final response = await http
          .post(
            Uri.parse('$backendUrl/redispatch-task'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'taskId': taskId, 'reason': 'ngo_incident_queue', 'staleHours': 8}),
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: T('Redispatch triggered.'), backgroundColor: SahayaColors.emerald));
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: T('Redispatch failed: ${response.statusCode}'), backgroundColor: SahayaColors.coral));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: T('Redispatch error: $e'), backgroundColor: SahayaColors.coral));
    }
  }

  Future<void> _runScenarioSimulation() async {
    final backendUrl = dotenv.env['BACKEND_URL'] ?? 'https://sahaya-faas-puz67as73a-uc.a.run.app';
    setState(() => _simLoading = true);
    try {
      final response = await http
          .post(
            Uri.parse('$backendUrl/simulate-scenario'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'ngoId': widget.ngoId,
              'shortagePercent': _shortagePercent,
              'surgePercent': _surgePercent,
              'horizonDays': _horizonDays.round(),
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _simResult = body['result'] as Map<String, dynamic>?;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: T('Simulation failed: ${response.statusCode}'),
            backgroundColor: SahayaColors.coral,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: T('Simulation error: $e'), backgroundColor: SahayaColors.coral),
      );
    } finally {
      if (mounted) {
        setState(() => _simLoading = false);
      }
    }
  }

  void _openKpiDrilldown(String kind) {
    if (_lastCards.isEmpty) return;

    final cs = Theme.of(context).colorScheme;
    final lines = <String>[];

    if (kind == 'time_to_first_task') {
      for (final c in _lastCards.take(12)) {
        final d = c.data() as Map<String, dynamic>;
        lines.add('${d['locationWard'] ?? 'Ward'} • P${((d['priorityScore'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}');
      }
    } else if (kind == 'priority_covered') {
      final highCards = _lastCards.where((c) {
        final d = c.data() as Map<String, dynamic>;
        return ((d['priorityScore'] as num?)?.toDouble() ?? 0) > 70;
      }).toList();
      lines.add('High-priority cards: ${highCards.length}');
      for (final c in highCards.take(10)) {
        final d = c.data() as Map<String, dynamic>;
        final issue = (d['issueType'] as String?) ?? 'other';
        lines.add('${d['locationWard'] ?? 'Ward'} • ${_sdgTagForIssue(issue)}');
      }
    } else {
      final accepted = _lastMatches.where((m) {
        final d = m.data() as Map<String, dynamic>;
        final s = (d['status'] as String?) ?? '';
        return {'accepted', 'proof_submitted', 'proof_rejected', 'proof_approved'}.contains(s);
      }).length;
      final approved = _lastMatches.where((m) {
        final d = m.data() as Map<String, dynamic>;
        return (d['status'] as String?) == 'proof_approved';
      }).length;
      lines.add('Accepted window matches: $accepted');
      lines.add('Approved matches: $approved');
      final pct = accepted == 0 ? 0 : ((approved / accepted) * 100).toStringAsFixed(1);
      lines.add('Completion rate: $pct%');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            T('KPI Drilldown', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 10),
            ...lines.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: T('• $l', style: GoogleFonts.inter(fontSize: 13)),
            )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isWide;
  final VoidCallback? onTap;

  const _KpiCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.color, this.isWide = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
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
                  T(title, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: cs.onSurfaceVariant, letterSpacing: 0.8)),
                  const SizedBox(height: 12),
                  T(value, style: GoogleFonts.inter(fontSize: 28, color: color, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  T(subtitle, style: GoogleFonts.inter(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500, height: 1.3)),
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
