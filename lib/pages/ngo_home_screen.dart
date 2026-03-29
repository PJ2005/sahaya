import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/problem_card.dart';
import '../components/ai_assistant_sheet.dart';
import '../components/ai_batch_task_sheet.dart';

class NgoHomeScreen extends StatelessWidget {
  final String ngoId;
  const NgoHomeScreen({super.key, required this.ngoId});

  static const Map<String, Color> _issueColors = {
    'water_access': Color(0xFF2196F3),
    'sanitation': Color(0xFF795548),
    'education': Color(0xFF9C27B0),
    'nutrition': Color(0xFFFF9800),
    'healthcare': Color(0xFFF44336),
    'livelihood': Color(0xFF4CAF50),
    'other': Color(0xFF607D8B),
  };

  Color _priorityBarColor(double score) {
    if (score < 40) return Colors.green;
    if (score <= 70) return Colors.amber;
    return const Color(0xFFFF6B6B); // coral
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Sahaya Dashboard',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('problem_cards')
            .where('ngoId', isEqualTo: ngoId)
            .where('status', isEqualTo: 'approved')
            .orderBy('priorityScore', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.dashboard_outlined,
                    size: 64,
                    color: Colors.black26,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No approved problem cards yet.',
                    style: TextStyle(
                      color: Colors.black45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Approve cards from the Review Queue to see them here.',
                    style: TextStyle(color: Colors.black38, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final card = ProblemCard.fromJson({
                ...data,
                'id': docs[index].id,
              });
              return _ProblemCardTile(
                card: card,
                issueColors: _issueColors,
                priorityBarColor: _priorityBarColor,
              );
            },
          );
        },
      ),
    );
  }
}

class _ProblemCardTile extends StatefulWidget {
  final ProblemCard card;
  final Map<String, Color> issueColors;
  final Color Function(double) priorityBarColor;

  const _ProblemCardTile({
    required this.card,
    required this.issueColors,
    required this.priorityBarColor,
  });

  @override
  State<_ProblemCardTile> createState() => _ProblemCardTileState();
}

class _ProblemCardTileState extends State<_ProblemCardTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final issueColor = widget.issueColors[card.issueType.name] ?? Colors.grey;
    final barColor = widget.priorityBarColor(card.priorityScore);
    final barValue = (card.priorityScore / 100).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Priority bar at the top
          LinearProgressIndicator(
            value: barValue,
            backgroundColor: Colors.grey[100],
            color: barColor,
            minHeight: 4,
          ),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Issue type pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: issueColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: issueColor.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          card.issueType.name
                              .replaceAll('_', ' ')
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: issueColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Priority: ${card.priorityScore.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: barColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.black45,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    card.description,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.black45,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${card.locationWard}, ${card.locationCity}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.people_outline,
                        size: 14,
                        color: Colors.black45,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${card.affectedCount} affected',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Expanded tasks section
          if (_expanded) _TasksList(problemCardId: card.id),
        ],
      ),
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

  void _deleteTask(BuildContext context, String taskId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Delete Task',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to permanently delete this task?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('tasks').doc(taskId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _openEditor(
    BuildContext context, {
    Map<String, dynamic>? existingTask,
    String? existingDocId,
  }) {
    showDialog(
      context: context,
      builder: (_) => _TaskEditorDialog(
        problemCardId: problemCardId,
        existingTask: existingTask,
        existingDocId: existingDocId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('problemCardId', isEqualTo: problemCardId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final tasks = snapshot.data?.docs ?? [];

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(
              top: BorderSide(color: Colors.grey.withOpacity(0.15)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    const Text(
                      'VOLUNTEER TASKS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.black45,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    if (tasks.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => AiBatchTaskSheet.show(context, problemCardId: problemCardId, taskDocs: tasks),
                        icon: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]).createShader(bounds),
                          child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                        ),
                        label: const Text(
                          'AI Refactor',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () => _openEditor(context),
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text(
                        'Add Task',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
              if (tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'No tasks yet. Tap "Add Task" to create one.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black38,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ...tasks.map((doc) {
                final t = doc.data() as Map<String, dynamic>;
                final taskType = (t['taskType'] ?? 'other')
                    .toString()
                    .replaceAll('_', ' ');
                final desc = t['description'] ?? '';
                final skills = List<String>.from(t['skillTags'] ?? []);
                final estVol = t['estimatedVolunteers'] ?? 1;
                final status = (t['status'] ?? 'open').toString();
                final statusColor = _statusColors[status] ?? Colors.grey;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              taskType.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: statusColor.withOpacity(0.4),
                              ),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => AiAssistantSheet.show(
                              context,
                              currentData: t,
                              contextDescription: 'a volunteer task',
                              onResult: (modified) async {
                                await FirebaseFirestore.instance
                                    .collection('tasks')
                                    .doc(doc.id)
                                    .update(modified);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Task updated via AI'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [
                                        Color(0xFF6366F1),
                                        Color(0xFF8B5CF6),
                                      ],
                                    ).createShader(bounds),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _openEditor(
                              context,
                              existingTask: t,
                              existingDocId: doc.id,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _deleteTask(context, doc.id),
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                          maxLines: 2,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ...skills
                              .take(3)
                              .map(
                                (s) => Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withOpacity(
                                        0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      s,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          if (skills.length > 3)
                            Text(
                              '+${skills.length - 3}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.black38,
                              ),
                            ),
                          const Spacer(),
                          const Icon(
                            Icons.person_outline,
                            size: 12,
                            color: Colors.black38,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$estVol needed',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}

// ─── Task Editor Dialog (Create / Edit) ───────────────────────────────
class _TaskEditorDialog extends StatefulWidget {
  final String problemCardId;
  final Map<String, dynamic>? existingTask;
  final String? existingDocId;

  const _TaskEditorDialog({
    required this.problemCardId,
    this.existingTask,
    this.existingDocId,
  });

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  static const _defaultTaskTypes = [
    'data_collection',
    'community_outreach',
    'logistics_coordination',
    'technical_repair',
    'awareness_session',
    'other',
  ];
  static const _defaultSkills = [
    'communication',
    'data_entry',
    'transport',
    'technical',
    'medical',
    'education',
    'physical_labor',
    'community_outreach',
  ];
  static const _statuses = ['open', 'filled', 'done'];

  late String _taskType;
  late String _status;
  late TextEditingController _descController;
  late TextEditingController _volunteersController;
  late TextEditingController _durationController;
  late TextEditingController _taskTypeController;
  late TextEditingController _customTagController;
  late Set<String> _selectedSkills;
  bool _saving = false;

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existingTask;
    _taskType = t?['taskType'] ?? 'other';
    _status = t?['status'] ?? 'open';
    _descController = TextEditingController(text: t?['description'] ?? '');
    _volunteersController = TextEditingController(
      text: (t?['estimatedVolunteers'] ?? 1).toString(),
    );
    _durationController = TextEditingController(
      text: (t?['estimatedDurationHours'] ?? 1).toString(),
    );
    _taskTypeController = TextEditingController(
      text: _taskType.replaceAll('_', ' '),
    );
    _customTagController = TextEditingController();
    _selectedSkills = Set<String>.from(t?['skillTags'] ?? []);
  }

  void _addCustomTag() {
    final tag = _customTagController.text.trim().toLowerCase().replaceAll(
      ' ',
      '_',
    );
    if (tag.isNotEmpty && !_selectedSkills.contains(tag)) {
      setState(() => _selectedSkills.add(tag));
      _customTagController.clear();
    }
  }

  void _save() async {
    // Capture task type from the text field (normalized)
    final typedTaskType = _taskTypeController.text
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_');
    if (typedTaskType.isNotEmpty) _taskType = typedTaskType;

    setState(() => _saving = true);
    final data = {
      'problemCardId': widget.problemCardId,
      'taskType': _taskType,
      'description': _descController.text.trim(),
      'skillTags': _selectedSkills.toList(),
      'estimatedVolunteers': int.tryParse(_volunteersController.text) ?? 1,
      'estimatedDurationHours':
          double.tryParse(_durationController.text) ?? 1.0,
      'status': _status,
      'assignedVolunteerIds':
          widget.existingTask?['assignedVolunteerIds'] ?? [],
    };

    try {
      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('tasks')
            .doc(widget.existingDocId)
            .update(data);
      } else {
        final docRef = FirebaseFirestore.instance.collection('tasks').doc();
        data['id'] = docRef.id;
        await docRef.set(data);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Task updated' : 'Task added'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Merge defaults with any custom existing value so it always appears
    final allSkills = {..._defaultSkills, ..._selectedSkills}.toList()..sort();

    return AlertDialog(
      title: Text(
        _isEditing ? 'Edit Task' : 'Add New Task',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Task Type — Autocomplete with free text
            Autocomplete<String>(
              initialValue: _taskTypeController.value,
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.toLowerCase();
                if (query.isEmpty) return _defaultTaskTypes;
                return _defaultTaskTypes.where(
                  (t) => t.contains(query.replaceAll(' ', '_')),
                );
              },
              displayStringForOption: (opt) => opt.replaceAll('_', ' '),
              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                _taskTypeController = controller;
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Task Type (select or type new)',
                    isDense: true,
                    hintText: 'e.g. water_testing',
                  ),
                  style: const TextStyle(fontSize: 13),
                );
              },
              onSelected: (val) {
                _taskType = val;
                _taskTypeController.text = val.replaceAll('_', ' ');
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLength: 100,
              maxLines: 2,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _volunteersController,
                    decoration: const InputDecoration(
                      labelText: 'Volunteers (1-5)',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Hours (1-8)',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                isDense: true,
              ),
              items: _statuses
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        s.toUpperCase(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 12),
            const Text(
              'Skill Tags',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: allSkills.map((skill) {
                final selected = _selectedSkills.contains(skill);
                return FilterChip(
                  label: Text(
                    skill.replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 10,
                      color: selected ? Colors.white : Colors.blueAccent,
                    ),
                  ),
                  selected: selected,
                  selectedColor: Colors.blueAccent,
                  backgroundColor: Colors.blueAccent.withOpacity(0.08),
                  checkmarkColor: Colors.white,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedSkills.add(skill);
                      } else {
                        _selectedSkills.remove(skill);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _customTagController,
                    decoration: const InputDecoration(
                      labelText: 'Add custom tag',
                      isDense: true,
                      hintText: 'e.g. first_aid',
                    ),
                    style: const TextStyle(fontSize: 12),
                    onFieldSubmitted: (_) => _addCustomTag(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _addCustomTag,
                  icon: const Icon(
                    Icons.add_circle,
                    color: Colors.blueAccent,
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _isEditing ? 'Save' : 'Add',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
