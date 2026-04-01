// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TaskModel _$TaskModelFromJson(Map<String, dynamic> json) => _TaskModel(
  id: json['id'] as String,
  problemCardId: json['problemCardId'] as String,
  taskType: $enumDecode(_$TaskTypeEnumMap, json['taskType']),
  description: json['description'] as String? ?? 'No description provided',
  skillTags: (json['skillTags'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  estimatedVolunteers: (json['estimatedVolunteers'] as num).toInt(),
  estimatedDurationHours: (json['estimatedDurationHours'] as num).toDouble(),
  status: $enumDecode(_$TaskStatusEnumMap, json['status']),
  assignedVolunteerIds: (json['assignedVolunteerIds'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  locationWard: json['locationWard'] as String? ?? 'Unknown Ward',
  locationGeoPoint: const OptionalGeoPointConverter().fromJson(
    json['locationGeoPoint'] as GeoPoint?,
  ),
);

Map<String, dynamic> _$TaskModelToJson(_TaskModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'problemCardId': instance.problemCardId,
      'taskType': _$TaskTypeEnumMap[instance.taskType]!,
      'description': instance.description,
      'skillTags': instance.skillTags,
      'estimatedVolunteers': instance.estimatedVolunteers,
      'estimatedDurationHours': instance.estimatedDurationHours,
      'status': _$TaskStatusEnumMap[instance.status]!,
      'assignedVolunteerIds': instance.assignedVolunteerIds,
      'locationWard': instance.locationWard,
      'locationGeoPoint': const OptionalGeoPointConverter().toJson(
        instance.locationGeoPoint,
      ),
    };

const _$TaskTypeEnumMap = {
  TaskType.data_collection: 'data_collection',
  TaskType.community_outreach: 'community_outreach',
  TaskType.logistics_coordination: 'logistics_coordination',
  TaskType.technical_repair: 'technical_repair',
  TaskType.awareness_session: 'awareness_session',
  TaskType.other: 'other',
};

const _$TaskStatusEnumMap = {
  TaskStatus.open: 'open',
  TaskStatus.filled: 'filled',
  TaskStatus.done: 'done',
};
