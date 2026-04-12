// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'problem_card.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProblemCard _$ProblemCardFromJson(Map<String, dynamic> json) => _ProblemCard(
  id: json['id'] as String,
  ngoId: json['ngoId'] as String,
  issueType: $enumDecode(_$IssueTypeEnumMap, json['issueType']),
  customIssueType: json['customIssueType'] as String?,
  locationWard: json['locationWard'] as String,
  locationCity: json['locationCity'] as String,
  locationGeoPoint: const GeoPointConverter().fromJson(
    json['locationGeoPoint'] as GeoPoint,
  ),
  severityLevel: $enumDecode(_$SeverityLevelEnumMap, json['severityLevel']),
  affectedCount: (json['affectedCount'] as num).toInt(),
  description: json['description'] as String,
  confidenceScore: (json['confidenceScore'] as num).toDouble(),
  status: $enumDecode(_$ProblemStatusEnumMap, json['status']),
  priorityScore: (json['priorityScore'] as num).toDouble(),
  severityContrib: (json['severityContrib'] as num).toDouble(),
  scaleContrib: (json['scaleContrib'] as num).toDouble(),
  recencyContrib: (json['recencyContrib'] as num).toDouble(),
  gapContrib: (json['gapContrib'] as num).toDouble(),
  createdAt: const TimestampConverter().fromJson(
    json['createdAt'] as Timestamp,
  ),
  anonymized: json['anonymized'] as bool,
);

Map<String, dynamic> _$ProblemCardToJson(_ProblemCard instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ngoId': instance.ngoId,
      'issueType': _$IssueTypeEnumMap[instance.issueType]!,
      'customIssueType': instance.customIssueType,
      'locationWard': instance.locationWard,
      'locationCity': instance.locationCity,
      'locationGeoPoint': const GeoPointConverter().toJson(
        instance.locationGeoPoint,
      ),
      'severityLevel': _$SeverityLevelEnumMap[instance.severityLevel]!,
      'affectedCount': instance.affectedCount,
      'description': instance.description,
      'confidenceScore': instance.confidenceScore,
      'status': _$ProblemStatusEnumMap[instance.status]!,
      'priorityScore': instance.priorityScore,
      'severityContrib': instance.severityContrib,
      'scaleContrib': instance.scaleContrib,
      'recencyContrib': instance.recencyContrib,
      'gapContrib': instance.gapContrib,
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
      'anonymized': instance.anonymized,
    };

const _$IssueTypeEnumMap = {
  IssueType.water_access: 'water_access',
  IssueType.sanitation: 'sanitation',
  IssueType.education: 'education',
  IssueType.nutrition: 'nutrition',
  IssueType.healthcare: 'healthcare',
  IssueType.livelihood: 'livelihood',
  IssueType.other: 'other',
};

const _$SeverityLevelEnumMap = {
  SeverityLevel.low: 'low',
  SeverityLevel.medium: 'medium',
  SeverityLevel.high: 'high',
  SeverityLevel.critical: 'critical',
};

const _$ProblemStatusEnumMap = {
  ProblemStatus.pending_review: 'pending_review',
  ProblemStatus.approved: 'approved',
  ProblemStatus.extraction_failed: 'extraction_failed',
};
