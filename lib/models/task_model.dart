// ignore_for_file: constant_identifier_names
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'converters.dart';

part 'task_model.freezed.dart';
part 'task_model.g.dart';

enum TaskType {
  data_collection,
  community_outreach,
  logistics_coordination,
  technical_repair,
  awareness_session,
  physical_labor,
  other,
}

enum TaskStatus { open, filled, done }

@freezed
abstract class TaskModel with _$TaskModel {
  const TaskModel._();
  const factory TaskModel({
    required String id,
    required String problemCardId,
    @JsonKey(unknownEnumValue: TaskType.other) required TaskType taskType,
    @Default('No description provided') String description,
    required List<String> skillTags,
    required int estimatedVolunteers,
    required double estimatedDurationHours,
    @JsonKey(unknownEnumValue: TaskStatus.open) required TaskStatus status,
    required List<String> assignedVolunteerIds,
    @Default(false) bool isProofSubmitted,
    @Default('Unknown Ward') String locationWard,
    @OptionalGeoPointConverter() GeoPoint? locationGeoPoint,
  }) = _TaskModel;

  factory TaskModel.fromJson(Map<String, dynamic> json) =>
      _$TaskModelFromJson(json);
}
