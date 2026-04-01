import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/problem_card.dart';
import '../components/ai_assistant_sheet.dart';
import '../components/ai_batch_task_sheet.dart';
import '../components/list_shimmer.dart';
import '../theme/sahaya_theme.dart';

class NgoTaskDetailScreen extends StatefulWidget {
  final ProblemCard card;
  const NgoTaskDetailScreen({super.key, required this.card});

  @override
  State<NgoTaskDetailScreen> createState() => _NgoTaskDetailScreenState();
}

class _NgoTaskDetailScreenState extends State<NgoTaskDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final card = widget.card;

    return Scaffold(
      appBar: AppBar(
        title: Text('Task Details', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            _buildHeader(context),

            // Metrics Grid
            _buildMetricsGrid(context),

            // Description
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Situation Overview', 
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: cs.primary)),
                  const SizedBox(height: 12),
                  Text(card.description, 
                    style: GoogleFonts.inter(fontSize: 15, height: 1.6, color: cs.onSurface.withValues(alpha: 0.8))),
                ],
              ),
            ),

            const Divider(),

            // Volunteer Tasks Section
            _TasksList(problemCardId: card.id),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        label: const Text('Add Volunteer Task'),
        icon: const Icon(Icons.add),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final card = widget.card;
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? SahayaColors.darkSurface : Colors.white,
        border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _severityPill(context, card.severityLevel),
              const Spacer(),
              Text(
                'Priority Score: ${card.priorityScore.toStringAsFixed(1)}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: cs.primary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            card.issueType.name.replaceAll('_', ' ').toUpperCase(),
            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_rounded, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                '${card.locationWard}, ${card.locationCity}',
                style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    final card = widget.card;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _metricItem(context, Icons.people_outline, '${card.affectedCount}', 'Affected'),
          const SizedBox(width: 12),
          _metricItem(context, Icons.calendar_today_outlined, card.createdAt.toString().split(' ')[0], 'Reported'),
          const SizedBox(width: 12),
          _metricItem(context, Icons.security_outlined, card.anonymized ? 'Private' : 'Public', 'Privacy'),
        ],
      ),
    );
  }

  Widget _metricItem(BuildContext context, IconData icon, String value, String label) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHigh : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: cs.primary.withValues(alpha: 0.7)),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _severityPill(BuildContext context, SeverityLevel level) {
    Color color = Colors.grey;
    switch (level) {
      case SeverityLevel.critical: color = SahayaColors.coral; break;
      case SeverityLevel.high: color = SahayaColors.amber; break;
      case SeverityLevel.medium: color = SahayaColors.emerald; break;
      case SeverityLevel.low: color = Colors.teal; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            level.name.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  void _openEditor(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _TaskEditorDialog(problemCardId: widget.card.id),
    );
  }
}

class _TasksList extends StatelessWidget {
  final String problemCardId;
  const _TasksList({required this.problemCardId});

  static const Map<String, Color> _statusColors = {
    'open': Color(0xFF2196F3),
    'filled': Color(0xFFFF9800),
    'done': Color(0xFF4CAF50),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('problemCardId', isEqualTo: problemCardId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListShimmer(itemCount: 2);
        }

        final tasks = snapshot.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  Text('VOLUNTEER MISSIONS', 
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant, letterSpacing: 1)),
                  const Spacer(),
                  if (tasks.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => AiBatchTaskSheet.show(context, problemCardId: problemCardId, taskDocs: tasks),
                      icon: const Icon(Icons.auto_awesome, size: 14),
                      label: const Text('AI Refactor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(horizontal: 6)),
                    ),
                ],
              ),
            ),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.assignment_outlined, size: 48, color: cs.outlineVariant),
                      const SizedBox(height: 12),
                      Text('No tasks defined yet', style: GoogleFonts.inter(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ...tasks.map((doc) {
              final t = doc.data() as Map<String, dynamic>;
              final status = (t['status'] ?? 'open').toString();
              return _TaskItem(doc: doc, task: t, statusColor: _statusColors[status] ?? Colors.grey);
            }),
          ],
        );
      },
    );
  }
}

class _TaskItem extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> task;
  final Color statusColor;

  const _TaskItem({required this.doc, required this.task, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final taskType = (task['taskType'] ?? 'other').toString().replaceAll('_', ' ');
    final skills = List<String>.from(task['skillTags'] ?? []);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [sahayaCardShadow(context)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(taskType.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: cs.primary)),
              ),
              _pill(context, task['status']?.toString().toUpperCase() ?? 'OPEN', statusColor.withValues(alpha: 0.1), statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(task['description'] ?? '', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Row(
            children: [
              ...skills.take(3).map((s) => _skillPill(context, s)),
              if (skills.length > 3) 
                Text(' +${skills.length - 3}', style: GoogleFonts.inter(fontSize: 10, color: cs.onSurfaceVariant)),
              const Spacer(),
              Icon(Icons.person_outline, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${task['estimatedVolunteers'] ?? 1}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionBtn(context, Icons.auto_awesome, 'AI Update', const Color(0xFF6366F1), () {
                AiAssistantSheet.show(context, currentData: task, contextDescription: 'a volunteer task', onResult: (mod) async {
                  await FirebaseFirestore.instance.collection('tasks').doc(doc.id).update(mod);
                });
              }),
              const SizedBox(width: 8),
              _actionBtn(context, Icons.edit_outlined, 'Edit', cs.primary, () {
                showDialog(context: context, builder: (_) => _TaskEditorDialog(
                  problemCardId: task['problemCardId'],
                  existingTask: task,
                  existingDocId: doc.id,
                ));
              }),
              const SizedBox(width: 8),
              _actionBtn(context, Icons.delete_outline_rounded, 'Delete', SahayaColors.coral, () => _deleteTask(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _skillPill(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: cs.outlineVariant.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _pill(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  Widget _actionBtn(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  void _deleteTask(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('tasks').doc(doc.id).delete();
    }
  }
}

class _TaskEditorDialog extends StatefulWidget {
  final String problemCardId;
  final Map<String, dynamic>? existingTask;
  final String? existingDocId;

  const _TaskEditorDialog({required this.problemCardId, this.existingTask, this.existingDocId});

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  static const _defaultTaskTypes = ['data_collection','community_outreach','logistics_coordination','technical_repair','awareness_session','other'];
  static const _defaultSkills = ['communication','data_entry','transport','technical','medical','education','physical_labor','community_outreach'];
  late String _taskType;
  late String _status;
  late TextEditingController _descController;
  late TextEditingController _volunteersController;
  late TextEditingController _durationController;
  late TextEditingController _taskTypeController;
  late TextEditingController _customTagController;
  late Set<String> _selectedSkills;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.existingTask;
    _taskType = t?['taskType'] ?? 'other';
    _status = t?['status'] ?? 'open';
    _descController = TextEditingController(text: t?['description'] ?? '');
    _volunteersController = TextEditingController(text: (t?['estimatedVolunteers'] ?? 1).toString());
    _durationController = TextEditingController(text: (t?['estimatedDurationHours'] ?? 1).toString());
    _taskTypeController = TextEditingController(text: _taskType.replaceAll('_', ' '));
    _customTagController = TextEditingController();
    _selectedSkills = Set<String>.from(t?['skillTags'] ?? []);
  }

  void _addCustomTag() {
    final tag = _customTagController.text.trim().toLowerCase().replaceAll(' ', '_');
    if (tag.isNotEmpty && !_selectedSkills.contains(tag)) {
      setState(() => _selectedSkills.add(tag));
      _customTagController.clear();
    }
  }

  void _save() async {
    final typedTaskType = _taskTypeController.text.trim().toLowerCase().replaceAll(' ', '_');
    if (typedTaskType.isNotEmpty) _taskType = typedTaskType;
    setState(() => _saving = true);
    final data = {
      'problemCardId': widget.problemCardId,
      'taskType': _taskType,
      'description': _descController.text.trim(),
      'estimatedVolunteers': int.tryParse(_volunteersController.text) ?? 1,
      'estimatedDurationHours': double.tryParse(_durationController.text) ?? 1.0,
      'skillTags': _selectedSkills.toList(),
      'status': _status,
      'createdAt': widget.existingTask?['createdAt'] ?? FieldValue.serverTimestamp(),
    };
    if (widget.existingDocId != null) {
      await FirebaseFirestore.instance.collection('tasks').doc(widget.existingDocId).update(data);
    } else {
      await FirebaseFirestore.instance.collection('tasks').add(data);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingTask == null ? 'Create Mission' : 'Edit Mission', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _defaultTaskTypes.contains(_taskType) ? _taskType : 'other',
              items: _defaultTaskTypes.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ')))).toList(),
              onChanged: (v) => setState(() => _taskType = v!),
              decoration: const InputDecoration(labelText: 'Task Type'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Brief Description'), maxLines: 2),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: _volunteersController, decoration: const InputDecoration(labelText: 'Volunteers'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _durationController, decoration: const InputDecoration(labelText: 'Hours'), keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerLeft, child: Text('Required Skills', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: _defaultSkills.map((s) => FilterChip(
                label: Text(s.replaceAll('_', ' '), style: const TextStyle(fontSize: 10)),
                selected: _selectedSkills.contains(s),
                onSelected: (v) => setState(() => v ? _selectedSkills.add(s) : _selectedSkills.remove(s)),
              )).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: _customTagController, decoration: const InputDecoration(labelText: 'Custom tag', isDense: true), onSubmitted: (_) => _addCustomTag())),
                IconButton(onPressed: _addCustomTag, icon: Icon(Icons.add_circle, color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Save')),
      ],
    );
  }
}
