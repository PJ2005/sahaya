import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../components/list_shimmer.dart';

class ProofReviewScreen extends StatelessWidget {
  final String ngoId;

  const ProofReviewScreen({super.key, required this.ngoId});

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _ownedPendingProofsStream() {
    final matchStream = FirebaseFirestore.instance
        .collection('match_records')
        .where('status', isEqualTo: 'proof_submitted')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        )
        .snapshots();

    return matchStream.asyncMap((snapshot) async {
      final taskToProblemCard = <String, String?>{};
      final cardOwnership = <String, bool>{};
      final filtered = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      for (final doc in snapshot.docs) {
        final taskId = doc.data()['taskId'] as String? ?? '';
        if (taskId.isEmpty) continue;

        String? problemCardId;
        if (taskToProblemCard.containsKey(taskId)) {
          problemCardId = taskToProblemCard[taskId];
        } else {
          final taskDoc =
              await FirebaseFirestore.instance.collection('tasks').doc(taskId).get();
          if (!taskDoc.exists) {
            taskToProblemCard[taskId] = null;
            continue;
          }
          problemCardId = taskDoc.data()?['problemCardId'] as String?;
          taskToProblemCard[taskId] = problemCardId;
        }

        if (problemCardId == null || problemCardId.isEmpty) continue;

        bool ownedByNgo;
        if (cardOwnership.containsKey(problemCardId)) {
          ownedByNgo = cardOwnership[problemCardId] ?? false;
        } else {
          final cardDoc = await FirebaseFirestore.instance
              .collection('problem_cards')
              .doc(problemCardId)
              .get();
          ownedByNgo = cardDoc.exists &&
              (cardDoc.data()?['ngoId'] as String? ?? '') == ngoId;
          cardOwnership[problemCardId] = ownedByNgo;
        }

        if (ownedByNgo) {
          filtered.add(doc);
        }
      }

      return filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Pending Proof Reviews',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _ownedPendingProofsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListShimmer(itemCount: 6);
          }

          final allDocs = snapshot.data ?? [];

          if (allDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, size: 80, color: Colors.green[200]),
                  const SizedBox(height: 16),
                  const Text(
                    'All caught up!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No pending proof submissions to review.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allDocs.length,
            itemBuilder: (context, index) {
              final matchDoc = allDocs[index];
              final matchData = matchDoc.data() as Map<String, dynamic>;
              return _ProofReviewCard(
                key: ValueKey(matchDoc.id),
                matchRecordId: matchDoc.id,
                matchData: matchData,
                ngoId: ngoId,
              );
            },
          );
        },
      ),
    );
  }
}

class _ProofReviewCard extends StatefulWidget {
  final String matchRecordId;
  final Map<String, dynamic> matchData;
  final String ngoId;

  const _ProofReviewCard({
    super.key,
    required this.matchRecordId,
    required this.matchData,
    required this.ngoId,
  });

  @override
  State<_ProofReviewCard> createState() => _ProofReviewCardState();
}

class _ProofReviewCardState extends State<_ProofReviewCard> {
  bool _isProcessing = false;
  String? _taskDescription;
  String? _volunteerId;
  List<String> _photoUrls = [];
  String _note = '';
  DateTime? _submittedAt;

  @override
  void initState() {
    super.initState();
    _parseData();
    _fetchTaskDescription();
  }

  @override
  void didUpdateWidget(covariant _ProofReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.matchRecordId != widget.matchRecordId ||
        oldWidget.matchData != widget.matchData) {
      _parseData();
      _taskDescription = null;
      _fetchTaskDescription();
    }
  }

  void _parseData() {
    _volunteerId = 'Anonymous';
    _photoUrls = [];
    _note = '';
    _submittedAt = null;

    _volunteerId = widget.matchData['volunteerId'] as String? ?? 'Anonymous';
    final proof = widget.matchData['proof'] as Map<String, dynamic>?;
    if (proof != null) {
      _photoUrls = List<String>.from(proof['photoUrls'] ?? proof['secureUrls'] ?? []);
      _note = proof['note'] as String? ?? '';
      final ts = proof['submittedAt'];
      if (ts is Timestamp) {
        _submittedAt = ts.toDate();
      }
    }
  }

  Future<void> _fetchTaskDescription() async {
    final taskId = widget.matchData['taskId'] as String? ?? '';
    if (taskId.isEmpty) return;
    try {
      final taskDoc = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .get();
      if (taskDoc.exists && mounted) {
        setState(() {
          _taskDescription = taskDoc.data()?['description'] as String? ?? 'Task';
        });
      }
    } catch (_) {}
  }

  Future<void> _approveProof() async {
    setState(() => _isProcessing = true);
    try {
      // 1. Update MatchRecord
      await FirebaseFirestore.instance
          .collection('match_records')
          .doc(widget.matchRecordId)
          .update({
        'status': 'proof_approved',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // 2. Call /complete-task endpoint
      final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:5000';
      try {
        await http.post(
          Uri.parse('$backendUrl/complete-task'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'matchRecordId': widget.matchRecordId}),
        );
      } catch (e) {
        debugPrint('Warning: complete-task call failed: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proof approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showRejectDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Proof'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide a reason for rejection:',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLength: 100,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. Photos are blurry, task not completed',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Reason is required to reject.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              _rejectProof(reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectProof(String reason) async {
    setState(() => _isProcessing = true);
    try {
      // 1. Update MatchRecord
      await FirebaseFirestore.instance
          .collection('match_records')
          .doc(widget.matchRecordId)
          .update({
        'status': 'proof_rejected',
        'adminReviewNote': reason,
      });

      // 2. Call /notify-proof-rejected
      final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:5000';
      try {
        await http.post(
          Uri.parse('$backendUrl/notify-proof-rejected'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'matchRecordId': widget.matchRecordId}),
        );
      } catch (e) {
        debugPrint('Warning: notify-proof-rejected call failed: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proof rejected. Volunteer notified.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortVolId = (_volunteerId ?? 'N/A').length > 8
        ? '${_volunteerId!.substring(0, 8)}…'
        : _volunteerId ?? 'N/A';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.fact_check, color: Colors.orange.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _taskDescription ?? 'Loading task...',
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
                          Icon(Icons.person_outline,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Volunteer: $shortVolId',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (_submittedAt != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.access_time,
                                size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(_submittedAt!),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Photo strip
            if (_photoUrls.isNotEmpty) ...[
              const Text(
                'Submitted Photos',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photoUrls.length,
                  itemBuilder: (context, idx) {
                    return GestureDetector(
                      onTap: () => _showFullScreenImage(context, _photoUrls[idx]),
                      child: Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(_photoUrls[idx]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Note
            if (_note.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Volunteer Note',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _note,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _approveProof,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle, size: 20),
                    label: const Text('Approve',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _showRejectDialog,
                    icon: const Icon(Icons.cancel, size: 20),
                    label: const Text('Reject',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showFullScreenImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
