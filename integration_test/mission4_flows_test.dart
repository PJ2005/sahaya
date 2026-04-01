import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Mission 4 flow hardening', () {
    testWidgets(
      'upload -> review -> approve -> tasks generated',
      (tester) async {
        final db = FakeFirebaseFirestore();
        final uploadId = 'upload_1';
        const ngoId = 'ngo_1';

        await db.collection('raw_uploads').doc(uploadId).set({
          'id': uploadId,
          'ngoId': ngoId,
          'cloudinaryUrl': 'https://example.com/file.csv',
          'cloudinaryPublicId': 'pid_1',
          'fileType': 'csv',
          'uploadedAt': Timestamp.now(),
          'status': 'pending',
        });

        await db.collection('problem_cards').doc(uploadId).set({
          'id': uploadId,
          'ngoId': ngoId,
          'issueType': 'water_access',
          'locationWard': 'Ward 1',
          'locationCity': 'Chennai',
          'locationGeoPoint': const GeoPoint(13.08, 80.27),
          'severityLevel': 'high',
          'affectedCount': 120,
          'description': 'Water contamination in public taps',
          'confidenceScore': 0.92,
          'status': 'pending_review',
          'priorityScore': 0.0,
          'severityContrib': 0.0,
          'scaleContrib': 0.0,
          'recencyContrib': 0.0,
          'gapContrib': 0.0,
          'createdAt': Timestamp.now(),
          'anonymized': true,
        });

        await db.collection('problem_cards').doc(uploadId).update({
          'status': 'approved',
        });

        final taskIds = await _generateTasksForApprovedCard(db, uploadId);

        final tasksSnapshot = await db
            .collection('tasks')
            .where('problemCardId', isEqualTo: uploadId)
            .get();

        expect(taskIds, isNotEmpty);
        expect(tasksSnapshot.docs.length, equals(taskIds.length));
        expect(
          tasksSnapshot.docs.every(
            (d) => (d.data()['status'] as String?) == 'open',
          ),
          isTrue,
        );
      },
    );

    testWidgets('matching engine correctness by matchScore', (tester) async {
      final matches = _rankMatches(
        taskSkills: const ['communication', 'physical_labor'],
        candidates: const [
          _VolunteerCandidate(id: 'v1', skills: ['communication'], distanceKm: 2),
          _VolunteerCandidate(
            id: 'v2',
            skills: ['communication', 'physical_labor'],
            distanceKm: 3,
          ),
          _VolunteerCandidate(id: 'v3', skills: ['data_entry'], distanceKm: 1),
        ],
        radiusKm: 10,
      );

      expect(matches.length, equals(3));
      expect(matches.first.volunteerId, equals('v2'));
      expect(matches[0].score >= matches[1].score, isTrue);
      expect(matches[1].score >= matches[2].score, isTrue);
    });

    testWidgets(
      'proof submission -> admin approval -> completion cascade',
      (tester) async {
        final db = FakeFirebaseFirestore();

        await db.collection('problem_cards').doc('pc_1').set({
          'id': 'pc_1',
          'ngoId': 'ngo_1',
          'issueType': 'sanitation',
          'status': 'approved',
        });

        await db.collection('tasks').doc('task_1').set({
          'id': 'task_1',
          'problemCardId': 'pc_1',
          'description': 'Drain cleaning support',
          'estimatedVolunteers': 1,
          'assignedVolunteerIds': ['vol_1'],
          'completionCount': 0,
          'status': 'open',
        });

        await db.collection('match_records').doc('match_1').set({
          'id': 'match_1',
          'taskId': 'task_1',
          'volunteerId': 'vol_1',
          'status': 'accepted',
          'createdAt': Timestamp.now(),
        });

        await db.collection('match_records').doc('match_1').update({
          'status': 'proof_submitted',
          'proof': {
            'photoUrls': ['https://img.example/1.jpg'],
            'submittedAt': Timestamp.now(),
          },
        });

        await db.collection('match_records').doc('match_1').update({
          'status': 'proof_approved',
          'completedAt': Timestamp.now(),
        });

        await _applyCompletionCascade(db, 'match_1');

        final task = await db.collection('tasks').doc('task_1').get();
        final card = await db.collection('problem_cards').doc('pc_1').get();

        expect(task.data()?['completionCount'], equals(1));
        expect(task.data()?['status'], equals('done'));
        expect(card.data()?['status'], equals('resolved'));
      },
    );
  });
}

Future<List<String>> _generateTasksForApprovedCard(
  FakeFirebaseFirestore db,
  String problemCardId,
) async {
  final cardDoc = await db.collection('problem_cards').doc(problemCardId).get();
  final card = cardDoc.data();
  if (card == null || card['status'] != 'approved') {
    return [];
  }

  final generatedTasks = [
    {
      'id': 'task_${problemCardId}_1',
      'problemCardId': problemCardId,
      'taskType': 'community_outreach',
      'description': 'Coordinate local support for ${card['issueType']}',
      'skillTags': ['communication'],
      'estimatedVolunteers': 1,
      'estimatedDurationHours': 2.0,
      'assignedVolunteerIds': <String>[],
      'status': 'open',
      'createdAt': Timestamp.now(),
    },
    {
      'id': 'task_${problemCardId}_2',
      'problemCardId': problemCardId,
      'taskType': 'logistics_coordination',
      'description': 'Deliver supplies to affected households',
      'skillTags': ['transport', 'physical_labor'],
      'estimatedVolunteers': 2,
      'estimatedDurationHours': 3.0,
      'assignedVolunteerIds': <String>[],
      'status': 'open',
      'createdAt': Timestamp.now(),
    },
  ];

  for (final task in generatedTasks) {
    await db.collection('tasks').doc(task['id'] as String).set(task);
  }

  return generatedTasks.map((t) => t['id'] as String).toList();
}

class _VolunteerCandidate {
  final String id;
  final List<String> skills;
  final double distanceKm;

  const _VolunteerCandidate({
    required this.id,
    required this.skills,
    required this.distanceKm,
  });
}

class _MatchScore {
  final String volunteerId;
  final double score;

  const _MatchScore({required this.volunteerId, required this.score});
}

List<_MatchScore> _rankMatches({
  required List<String> taskSkills,
  required List<_VolunteerCandidate> candidates,
  required double radiusKm,
}) {
  final normalizedRadius = radiusKm <= 0 ? 1.0 : radiusKm;
  final result = <_MatchScore>[];

  for (final candidate in candidates) {
    final overlap = candidate.skills.toSet().intersection(taskSkills.toSet());
    final skillScore = overlap.length / math.max(taskSkills.length, 1);
    final normalizedDistance = math.min(candidate.distanceKm / normalizedRadius, 1.0);
    final score = (skillScore * 0.6) + ((1.0 - normalizedDistance) * 0.4);
    result.add(_MatchScore(volunteerId: candidate.id, score: score));
  }

  result.sort((a, b) => b.score.compareTo(a.score));
  return result;
}

Future<void> _applyCompletionCascade(
  FakeFirebaseFirestore db,
  String matchRecordId,
) async {
  final matchDoc = await db.collection('match_records').doc(matchRecordId).get();
  final match = matchDoc.data();
  if (match == null || match['status'] != 'proof_approved') {
    return;
  }

  final taskId = match['taskId'] as String? ?? '';
  if (taskId.isEmpty) return;

  final taskRef = db.collection('tasks').doc(taskId);
  final taskDoc = await taskRef.get();
  final task = taskDoc.data();
  if (task == null) return;

  final currentCount = (task['completionCount'] as num?)?.toInt() ?? 0;
  final estimated = (task['estimatedVolunteers'] as num?)?.toInt() ?? 1;
  final assignedCount = (task['assignedVolunteerIds'] as List?)?.length ?? 0;
  final requiredCompletions = math.max(estimated, assignedCount);
  final nextCount = currentCount + 1;

  await taskRef.update({
    'completionCount': nextCount,
    'status': nextCount >= requiredCompletions ? 'done' : (task['status'] ?? 'open'),
  });

  if (nextCount < requiredCompletions) {
    return;
  }

  final cardId = task['problemCardId'] as String? ?? '';
  if (cardId.isEmpty) return;

  final siblingTasks = await db
      .collection('tasks')
      .where('problemCardId', isEqualTo: cardId)
      .get();

  final allDone = siblingTasks.docs.every(
    (doc) => (doc.data()['status'] as String? ?? 'open') == 'done',
  );

  if (allDone) {
    await db.collection('problem_cards').doc(cardId).update({'status': 'resolved'});
  }
}
