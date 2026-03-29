// ignore_for_file: constant_identifier_names
import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_model.freezed.dart';
part 'task_model.g.dart';

enum TaskType { data_collection, community_outreach, logistics_coordination, technical_repair, awareness_session, other }
enum TaskStatus { open, filled, done }

@freezed
abstract class TaskModel with _$TaskModel {
  const TaskModel._();
  const factory TaskModel({
    required String id,
    required String problemCardId,
    required TaskType taskType,
    required List<String> skillTags,
    required int estimatedVolunteers,
    required double estimatedDurationHours,
    required TaskStatus status,
    required List<String> assignedVolunteerIds,
  }) = _TaskModel;

  factory TaskModel.fromJson(Map<String, dynamic> json) => _$TaskModelFromJson(json);
}
