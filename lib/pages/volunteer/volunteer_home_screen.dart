import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../models/volunteer_profile.dart';
import '../../models/task_model.dart';
import '../../components/list_shimmer.dart';
import 'task_details_screen.dart';
import 'active_task_screen.dart';

class VolunteerHomeScreen extends StatefulWidget {
  final String uid;

  const VolunteerHomeScreen({super.key, required this.uid});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription<QuerySnapshot>? _proofRejectedSubscription;
  final Set<String> _handledNotificationIds = <String>{};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startProofRejectedListener();
  }

  @override
  void dispose() {
    _proofRejectedSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startProofRejectedListener() {
    _proofRejectedSubscription = FirebaseFirestore.instance
        .collection('volunteer_notifications')
        .where('volunteerId', isEqualTo: widget.uid)
        .snapshots()
        .listen((snapshot) async {
          if (!mounted) return;

          for (final doc in snapshot.docs) {
            if (_handledNotificationIds.contains(doc.id)) {
              continue;
            }

            final data = doc.data();
            final isRead = data['read'] == true;
            final type = (data['type'] as String? ?? '').trim();
            if (isRead || type != 'proof_rejected') {
              continue;
            }

            final matchRecordId = data['matchRecordId'] as String? ?? '';
            final note = data['adminReviewNote'] as String? ?? '';
            if (matchRecordId.isEmpty) {
              continue;
            }

            _handledNotificationIds.add(doc.id);

            try {
              await FirebaseFirestore.instance
                  .collection('volunteer_notifications')
                  .doc(doc.id)
                  .update({
                    'read': true,
                    'readAt': FieldValue.serverTimestamp(),
                  });
            } catch (_) {}

            await _openResubmissionFlow(matchRecordId, note);
          }
        });
  }

  Future<void> _openResubmissionFlow(
    String matchRecordId,
    String reason,
  ) async {
    try {
      final matchDoc = await FirebaseFirestore.instance
          .collection('match_records')
          .doc(matchRecordId)
          .get();
      if (!matchDoc.exists || matchDoc.data() == null || !mounted) {
        return;
      }

      final matchData = matchDoc.data()!;
      final taskId = matchData['taskId'] as String? ?? '';
      if (taskId.isEmpty) return;

      final taskDoc = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .get();
      if (!taskDoc.exists || taskDoc.data() == null || !mounted) {
        return;
      }

      final taskMap = Map<String, dynamic>.from(taskDoc.data()!);
      final taskModel = TaskModel.fromJson(taskMap);

      String ngoName = 'NGO Coordinator';
      String ngoPhone = '';
      String ngoEmail = '';

      try {
        final pcDoc = await FirebaseFirestore.instance
            .collection('problem_cards')
            .doc(taskModel.problemCardId)
            .get();
        if (pcDoc.exists && pcDoc.data() != null) {
          final ngoId = pcDoc.data()!['ngoId'];
          if (ngoId != null) {
            final ngoDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(ngoId)
                .get();
            if (ngoDoc.exists && ngoDoc.data() != null) {
              ngoName = ngoDoc['name'] ?? ngoName;
              ngoPhone = ngoDoc['phone'] ?? ngoPhone;
              ngoEmail = ngoDoc['email'] ?? ngoEmail;
            }
          }
        }
      } catch (_) {}

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActiveTaskScreen(
            matchRecordId: matchRecordId,
            task: taskModel,
            ngoName: ngoName,
            ngoPhone: ngoPhone,
            ngoEmail: ngoEmail,
            autoOpenProofSheet: true,
            rejectionReason: reason,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _updateAvailability(bool isActive, bool isPartial) async {
    try {
      await FirebaseFirestore.instance
          .collection('volunteer_profiles')
          .doc(widget.uid)
          .update({
            'availabilityWindowActive': isActive,
            'isPartialAvailability': isPartial,
            'availabilityUpdatedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Availability updated successfully!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sahaya Volunteer',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.blueAccent,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.blueAccent),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('volunteer_profiles')
            .doc(widget.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(child: Text('Profile not found.'));
          }

          final profileMap = snapshot.data!.data() as Map<String, dynamic>;
          final profile = VolunteerProfile.fromJson(profileMap);

          final bool windowActive = profile.availabilityWindowActive;
          final DateTime updatedAt = profile.availabilityUpdatedAt;
          final bool isStale = DateTime.now().difference(updatedAt).inDays >= 7;

          if (!windowActive || isStale) {
            return _buildCheckInPrompt(context);
          } else {
            return _buildDashboard(profile);
          }
        },
      ),
    );
  }

  Widget _buildCheckInPrompt(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF7F9FC),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_available, size: 80, color: Colors.blueAccent),
          const SizedBox(height: 24),
          const Text(
            'Available this weekend?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Let us know if you can help with community tasks recently matched to your location and skillset.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          ScaleTransition(
            scale: _pulseAnimation,
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => _updateAvailability(true, false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: Colors.blueAccent.withValues(alpha: 0.5),
                ),
                child: const Text(
                  'Yes, I am available!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: OutlinedButton(
              onPressed: () => _updateAvailability(true, true),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.blueAccent, width: 2),
                foregroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Partially (A few hours)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: TextButton(
              onPressed: () => _updateAvailability(false, false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Not this time',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(VolunteerProfile profile) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Card
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blueAccent, Colors.lightBlue],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              profile.isPartialAvailability
                                  ? 'Partially Active'
                                  : 'Fully Active',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You are checked in!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'We are matching you with nearby tasks based on your skills.',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tab bar to clearly separate the two views
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black54,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'My Missions'),
                Tab(text: 'Available'),
                Tab(text: 'History'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Tab body
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('match_records')
                  .where('volunteerId', isEqualTo: widget.uid)
                  .snapshots(),
              builder: (context, matchSnapshot) {
                if (matchSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${matchSnapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (matchSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListShimmer(itemCount: 6);
                }
                if (!matchSnapshot.hasData ||
                    matchSnapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.radar, size: 60, color: Colors.blue[100]),
                        const SizedBox(height: 16),
                        const Text(
                          'Scanning for community needs...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final allDocs = matchSnapshot.data!.docs.toList();

                // Split into accepted/proof_submitted vs open
                final acceptedDocs = allDocs.where((d) {
                  final s =
                      (d.data() as Map<String, dynamic>)['status'] as String? ??
                      '';
                  return s == 'accepted' ||
                      s == 'proof_submitted' ||
                      s == 'proof_rejected';
                }).toList();

                final openDocs = allDocs.where((d) {
                  final s =
                      (d.data() as Map<String, dynamic>)['status'] as String? ??
                      '';
                  return s == 'open';
                }).toList();

                final approvedDocs = allDocs.where((d) {
                  final s =
                      (d.data() as Map<String, dynamic>)['status'] as String? ??
                      '';
                  return s == 'proof_approved';
                }).toList();

                // Sort both by matchScore descending
                acceptedDocs.sort((a, b) {
                  final aScore =
                      ((a.data() as Map<String, dynamic>)['matchScore'] as num?)
                          ?.toDouble() ??
                      0.0;
                  final bScore =
                      ((b.data() as Map<String, dynamic>)['matchScore'] as num?)
                          ?.toDouble() ??
                      0.0;
                  return bScore.compareTo(aScore);
                });
                openDocs.sort((a, b) {
                  final aScore =
                      ((a.data() as Map<String, dynamic>)['matchScore'] as num?)
                          ?.toDouble() ??
                      0.0;
                  final bScore =
                      ((b.data() as Map<String, dynamic>)['matchScore'] as num?)
                          ?.toDouble() ??
                      0.0;
                  return bScore.compareTo(aScore);
                });

                approvedDocs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime =
                      (aData['completedAt'] as Timestamp?)?.toDate() ??
                      (aData['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final bTime =
                      (bData['completedAt'] as Timestamp?)?.toDate() ??
                      (bData['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return bTime.compareTo(aTime);
                });

                return TabBarView(
                  children: [
                    // Tab 1: My Missions (accepted)
                    _buildMissionsList(acceptedDocs, isAccepted: true),
                    // Tab 2: Available (open)
                    _buildMissionsList(openDocs, isAccepted: false),
                    // Tab 3: History (approved)
                    _buildHistoryList(approvedDocs),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'No completed missions yet.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final match = Map<String, dynamic>.from(
          doc.data() as Map<String, dynamic>,
        );
        final taskId = match['taskId'] as String? ?? '';
        final impactStatement =
            (match['impactStatement'] as String?)?.trim() ?? '';
        final doneAt =
            (match['completedAt'] as Timestamp?)?.toDate() ??
            (match['createdAt'] as Timestamp?)?.toDate();

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('tasks')
              .doc(taskId)
              .get(),
          builder: (context, taskSnapshot) {
            if (taskSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 110, child: ListShimmer(itemCount: 1));
            }
            if (!taskSnapshot.hasData || !taskSnapshot.data!.exists) {
              return const SizedBox.shrink();
            }

            final taskData = taskSnapshot.data!.data() as Map<String, dynamic>;
            final description =
                taskData['description'] as String? ?? 'Volunteer Task';
            final ward = taskData['locationWard'] as String? ?? 'Unknown Ward';

            return Card(
              elevation: 1.5,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.verified,
                            color: Colors.green,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 13,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ward,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          doneAt == null
                              ? 'Completed'
                              : '${doneAt.year}-${doneAt.month.toString().padLeft(2, '0')}-${doneAt.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        impactStatement.isEmpty
                            ? 'You helped improve this community task outcome.'
                            : impactStatement,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMissionsList(
    List<QueryDocumentSnapshot> docs, {
    required bool isAccepted,
  }) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAccepted ? Icons.assignment_turned_in : Icons.search,
              size: 60,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isAccepted
                  ? 'No accepted missions yet.\nBrowse Available tasks to get started!'
                  : 'No recommended tasks right now.\nCheck back soon!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final matchMap = Map<String, dynamic>.from(
          doc.data() as Map<String, dynamic>,
        );
        matchMap['id'] = doc.id;

        return _MatchRecordCard(matchMap: matchMap, isAccepted: isAccepted);
      },
    );
  }
}

/// Individual card widget for a single MatchRecord.
/// Fetches the linked Task from Firestore to display details.
class _MatchRecordCard extends StatelessWidget {
  final Map<String, dynamic> matchMap;
  final bool isAccepted;

  const _MatchRecordCard({required this.matchMap, required this.isAccepted});

  @override
  Widget build(BuildContext context) {
    final String taskId = matchMap['taskId'] ?? '';
    final double matchScore =
        (matchMap['matchScore'] as num?)?.toDouble() ?? 0.0;
    final int scorePercent = (matchScore * 100).round();
    final String status = matchMap['status'] ?? 'open';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('tasks').doc(taskId).get(),
      builder: (context, taskSnapshot) {
        if (taskSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 120, child: ListShimmer(itemCount: 1));
        }
        if (!taskSnapshot.hasData || !taskSnapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final taskData = taskSnapshot.data!.data() as Map<String, dynamic>;
        final String description = taskData['description'] ?? 'Volunteer Task';
        final String ward = taskData['locationWard'] ?? 'Unknown Ward';
        final String taskType = (taskData['taskType'] ?? 'other')
            .toString()
            .replaceAll('_', ' ');

        Color statusColor;
        String statusLabel;
        IconData statusIcon;

        if (status == 'proof_submitted') {
          statusColor = Colors.orange;
          statusLabel = 'Proof Submitted';
          statusIcon = Icons.hourglass_top;
        } else if (status == 'proof_rejected') {
          statusColor = Colors.deepOrange;
          statusLabel = 'Revision Needed';
          statusIcon = Icons.restart_alt;
        } else if (isAccepted) {
          statusColor = Colors.green;
          statusLabel = 'Accepted';
          statusIcon = Icons.check_circle;
        } else {
          statusColor = Colors.blueAccent;
          statusLabel = '$scorePercent% Match';
          statusIcon = Icons.auto_awesome;
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isAccepted
                ? BorderSide(color: Colors.green.shade200, width: 1.5)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (status == 'proof_rejected') {
                _navigateToActiveTask(
                  context,
                  taskData,
                  autoOpenProofSheet: true,
                  rejectionReason: matchMap['adminReviewNote'] as String? ?? '',
                );
              } else if (isAccepted && status != 'proof_submitted') {
                // Go directly to ActiveTaskScreen for accepted missions
                _navigateToActiveTask(context, taskData);
              } else if (status == 'proof_submitted') {
                // Already submitted — show a message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Proof already submitted. Waiting for NGO review.',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              } else {
                // Open = go to Mission Briefing (view-only until they accept)
                _navigateToDetails(context, taskData, scorePercent);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isAccepted ? Icons.run_circle : Icons.assignment,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              description,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    ward,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Status pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Task type chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          taskType,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Action button
                      Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToActiveTask(
    BuildContext context,
    Map<String, dynamic> taskData, {
    bool autoOpenProofSheet = false,
    String? rejectionReason,
  }) async {
    final taskModel = TaskModel.fromJson(taskData);

    // Fetch NGO info
    String ngoName = 'NGO Coordinator';
    String ngoPhone = '';
    String ngoEmail = '';

    try {
      final pcDoc = await FirebaseFirestore.instance
          .collection('problem_cards')
          .doc(taskModel.problemCardId)
          .get();
      if (pcDoc.exists && pcDoc.data() != null) {
        final ngoId = pcDoc.data()!['ngoId'];
        if (ngoId != null) {
          final ngoDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(ngoId)
              .get();
          if (ngoDoc.exists && ngoDoc.data() != null) {
            ngoName = ngoDoc['name'] ?? ngoName;
            ngoPhone = ngoDoc['phone'] ?? ngoPhone;
            ngoEmail = ngoDoc['email'] ?? ngoEmail;
          }
        }
      }
    } catch (_) {}

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveTaskScreen(
          matchRecordId: matchMap['id'] ?? '',
          task: taskModel,
          ngoName: ngoName,
          ngoPhone: ngoPhone,
          ngoEmail: ngoEmail,
          autoOpenProofSheet: autoOpenProofSheet,
          rejectionReason: rejectionReason,
        ),
      ),
    );
  }

  void _navigateToDetails(
    BuildContext context,
    Map<String, dynamic> taskData,
    int scorePercent,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsScreen(
          taskId: matchMap['taskId'] ?? '',
          matchRecordId: matchMap['id'] ?? '',
          initialTask: TaskModel.fromJson(taskData),
          matchScore: scorePercent,
          isAlreadyAccepted: false,
          whatToBring:
              matchMap['whatToBring'] ??
              'Standard volunteering gear and water.',
        ),
      ),
    );
  }
}
