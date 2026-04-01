import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/task_model.dart';
import 'active_task_screen.dart';

class TaskDetailsScreen extends StatefulWidget {
  final String taskId;
  final String matchRecordId;
  final TaskModel initialTask;
  final int matchScore;
  final String whatToBring;
  final bool isAlreadyAccepted;

  const TaskDetailsScreen({
    super.key,
    required this.taskId,
    required this.matchRecordId,
    required this.initialTask,
    required this.matchScore,
    required this.whatToBring,
    this.isAlreadyAccepted = false,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  bool _isAccepting = false;
  late bool _isAccepted;
  late final Future<Map<String, dynamic>> _contextFuture;

  @override
  void initState() {
    super.initState();
    _isAccepted = widget.isAlreadyAccepted;
    _contextFuture = _fetchTaskContext();
  }

  String _ngoName = 'NGO Coordinator';
  String _ngoEmail = '';
  String _ngoPhone = '+1234567890';

  Future<Map<String, dynamic>> _fetchTaskContext() async {
    if (widget.matchRecordId.isEmpty) {
      return {
        'skills': <String>[],
        'problem': <String, dynamic>{},
        'ngoName': 'NGO Coordinator',
        'ngoEmail': 'hidden',
        'ngoPhone': '+1234567890',
      };
    }

    final matchDoc = await FirebaseFirestore.instance
        .collection('match_records')
        .doc(widget.matchRecordId)
        .get();
    if (!matchDoc.exists || matchDoc.data() == null) {
      return {
        'skills': <String>[],
        'problem': <String, dynamic>{},
        'ngoName': 'NGO Coordinator',
        'ngoEmail': 'hidden',
        'ngoPhone': '+1234567890',
      };
    }

    final volunteerId = matchDoc['volunteerId'];
    final volunteerDoc = await FirebaseFirestore.instance
        .collection('volunteer_profiles')
        .doc(volunteerId)
        .get();

    final problemDoc = await FirebaseFirestore.instance
        .collection('problem_cards')
        .doc(widget.initialTask.problemCardId)
        .get();

    // Default Values in case ngo is missing from problem cards
    String ngoName = 'NGO Coordinator';
    String ngoEmail = 'hidden';
    String ngoPhone = '+1234567890';

    if (problemDoc.exists && problemDoc.data() != null) {
      final problemData = problemDoc.data()!;
      if (problemData.containsKey('ngoId') && problemData['ngoId'] != null) {
        final ngoId = problemData['ngoId'];
        final ngoDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(ngoId)
            .get();
        if (ngoDoc.exists && ngoDoc.data() != null) {
          ngoName = ngoDoc['name'] ?? ngoName;
          ngoEmail = ngoDoc['email'] ?? ngoEmail;
          ngoPhone = ngoDoc['phone'] ?? ngoPhone;
        }
      }
    }

    return {
      'skills': volunteerDoc.exists
          ? List<String>.from(volunteerDoc['skills'] ?? [])
          : <String>[],
      'problem': problemDoc.exists ? problemDoc.data()! : {},
      'ngoName': ngoName,
      'ngoEmail': ngoEmail,
      'ngoPhone': ngoPhone,
    };
  }

  Future<void> _acceptTask() async {
    if (widget.matchRecordId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invalid mission reference. Please refresh and try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isAccepting = true);
    try {
      final matchRef = FirebaseFirestore.instance
          .collection('match_records')
          .doc(widget.matchRecordId);
      final taskRef = FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId);

      final currentMatch = await matchRef.get();
      if (!currentMatch.exists || currentMatch.data() == null) {
        throw Exception('Match record not found');
      }

      final currentStatus = currentMatch.data()!['status'] as String? ?? '';
      if (currentStatus != 'open' && currentStatus != 'accepted') {
        throw Exception('Mission is not available for acceptance');
      }

      final volunteerId = currentMatch['volunteerId'];
      final batch = FirebaseFirestore.instance.batch();
      batch.update(matchRef, {'status': 'accepted'});
      batch.update(taskRef, {
        'assignedVolunteerIds': FieldValue.arrayUnion([volunteerId]),
      });
      await batch.commit();

      if (mounted) {
        setState(() => _isAccepted = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task accepted! Redirecting to your active mission...'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate directly to ActiveTaskScreen after acceptance
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ActiveTaskScreen(
                matchRecordId: widget.matchRecordId,
                task: widget.initialTask,
                ngoName: _ngoName,
                ngoPhone: _ngoPhone,
                ngoEmail: _ngoEmail,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to accept task: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _contextFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Mission Details',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.blueAccent),
              elevation: 0,
            ),
            body: const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            ),
          );
        }

        final ctxData = snapshot.data ?? {};
        final volunteerSkills = ctxData['skills'] as List<String>? ?? [];
        final problemData = ctxData['problem'] as Map<String, dynamic>? ?? {};
        final ngoName = ctxData['ngoName'] as String? ?? 'NGO Coordinator';
        final ngoEmail = ctxData['ngoEmail'] as String? ?? '';
        final ngoPhone = ctxData['ngoPhone'] as String? ?? '+1234567890';

        // Store for use in _acceptTask navigation
        _ngoName = ngoName;
        _ngoEmail = ngoEmail;
        _ngoPhone = ngoPhone;

        final String rank =
            (problemData['severityLevel']?.toString().split('.').last ?? 'HIGH')
                .toUpperCase();
        final int affectedCount = problemData['affectedCount'] as int? ?? 0;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Mission Details',
              style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.blueAccent),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Warm-tinted context band
                if (problemData.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: Colors.orange.shade50,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade800,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Priority #$rank issue in your area · $affectedCount households affected',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Header Image/Hero
                Container(
                  height: 160,
                  width: double.infinity,
                  color: Colors.blue[50],
                  child: const Icon(
                    Icons.handshake,
                    size: 80,
                    color: Colors.blueAccent,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${widget.matchScore}% Match',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.initialTask.taskType.name
                                  .replaceAll('_', ' ')
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Description
                      const Text(
                        'The Challenge',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.initialTask.description,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Logistics grid
                      const Text(
                        'Mission Logistics',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildLogicRow(
                        Icons.location_on,
                        'Location',
                        widget.initialTask.locationWard,
                      ),
                      _buildLogicRow(
                        Icons.timer,
                        'Estimated Time',
                        '${widget.initialTask.estimatedDurationHours} Hours',
                      ),
                      _buildLogicRow(
                        Icons.people,
                        'Required Output',
                        '${widget.initialTask.estimatedVolunteers} Volunteers required',
                      ),
                      _buildLogicRow(
                        Icons.backpack,
                        'What to Bring',
                        widget.whatToBring,
                      ),

                      const SizedBox(height: 32),

                      // Skills Matches
                      const Text(
                        'Targeted Skills',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.initialTask.skillTags.map((skill) {
                          final isMatch = volunteerSkills
                              .map((s) => s.toLowerCase())
                              .contains(skill.toLowerCase());
                          return Chip(
                            label: Text(
                              skill,
                              style: TextStyle(
                                color: isMatch
                                    ? Colors.green.shade900
                                    : Colors.black87,
                                fontWeight: isMatch
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            backgroundColor: isMatch
                                ? Colors.green.shade100
                                : Colors.grey[200],
                            side: BorderSide.none,
                            avatar: isMatch
                                ? Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade700,
                                    size: 18,
                                  )
                                : null,
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 32),

                      // NGO Coordinator Contact
                      const Text(
                        'Point of Contact',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ngoName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          ngoEmail,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.email,
                                      color: _isAccepted
                                          ? Colors.blueAccent
                                          : Colors.grey,
                                    ),
                                    onPressed: _isAccepted ? () {} : null,
                                  ),
                                ],
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                ignoring: _isAccepted,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                    begin: 8.0,
                                    end: _isAccepted ? 0.0 : 8.0,
                                  ),
                                  duration: const Duration(milliseconds: 300),
                                  builder: (context, blur, child) {
                                    if (blur <= 0.01) {
                                      return const SizedBox.shrink();
                                    }
                                    return BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: blur,
                                        sigmaY: blur,
                                      ),
                                      child: Container(
                                        color: Colors.white.withOpacity(
                                          0.2 + (blur / 80),
                                        ),
                                        alignment: Alignment.center,
                                        child: Opacity(
                                          opacity: (blur / 8.0).clamp(0.0, 1.0),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(
                                                  Icons.lock,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Accept task to unlock contact',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _isAccepted
            ? const SizedBox.shrink() // Already accepted — no button needed
            : SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                height: 60,
                child: ElevatedButton(
                  onPressed: _isAccepting ? null : _acceptTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: _isAccepting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.handshake, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Accept Mission',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogicRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.blueAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
