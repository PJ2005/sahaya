// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProofObject _$ProofObjectFromJson(Map<String, dynamic> json) => _ProofObject(
  photoUrls: (json['photoUrls'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  note: json['note'] as String,
  submittedAt: const TimestampConverter().fromJson(
    json['submittedAt'] as Timestamp,
  ),
);

Map<String, dynamic> _$ProofObjectToJson(_ProofObject instance) =>
    <String, dynamic>{
      'photoUrls': instance.photoUrls,
      'note': instance.note,
      'submittedAt': const TimestampConverter().toJson(instance.submittedAt),
    };

_MatchRecord _$MatchRecordFromJson(Map<String, dynamic> json) => _MatchRecord(
  id: json['id'] as String,
  taskId: json['taskId'] as String,
  volunteerId: json['volunteerId'] as String,
  matchScore: (json['matchScore'] as num).toDouble(),
  status: $enumDecode(_$MatchStatusEnumMap, json['status']),
  missionBriefing: json['missionBriefing'] as String,
  whatToBring: json['whatToBring'] as String,
  proof: json['proof'] == null
      ? null
      : ProofObject.fromJson(json['proof'] as Map<String, dynamic>),
  adminReviewNote: json['adminReviewNote'] as String?,
  completedAt: _$JsonConverterFromJson<Timestamp, DateTime>(
    json['completedAt'],
    const TimestampConverter().fromJson,
  ),
);

Map<String, dynamic> _$MatchRecordToJson(_MatchRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'taskId': instance.taskId,
      'volunteerId': instance.volunteerId,
      'matchScore': instance.matchScore,
      'status': _$MatchStatusEnumMap[instance.status]!,
      'missionBriefing': instance.missionBriefing,
      'whatToBring': instance.whatToBring,
      'proof': instance.proof,
      'adminReviewNote': instance.adminReviewNote,
      'completedAt': _$JsonConverterToJson<Timestamp, DateTime>(
        instance.completedAt,
        const TimestampConverter().toJson,
      ),
    };

const _$MatchStatusEnumMap = {
  MatchStatus.open: 'open',
  MatchStatus.accepted: 'accepted',
  MatchStatus.proof_submitted: 'proof_submitted',
  MatchStatus.proof_approved: 'proof_approved',
  MatchStatus.proof_rejected: 'proof_rejected',
  MatchStatus.completed: 'completed',
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
