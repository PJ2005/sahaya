import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';

class SeedService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> seedData() async {
    final tasks = await _db.collection('tasks').limit(1).get();
    if (tasks.docs.isNotEmpty) {
      print('Data already seeded!');
      return;
    }

    try {
      final task1 = TaskModel(
        id: 'seed_task_1',
        problemCardId: 'seed_problem_1',
        taskType: TaskType.community_outreach,
        skillTags: ['communication', 'local_language'],
        estimatedVolunteers: 5,
        estimatedDurationHours: 4.5,
        status: TaskStatus.open,
        assignedVolunteerIds: [],
      );

      await _db.collection('tasks').doc(task1.id).set(task1.toJson());

      print('Successfully seeded initial test task!');
    } catch (e) {
      print('Failed to seed data: $e');
    }
  }
}
