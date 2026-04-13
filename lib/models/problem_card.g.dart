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
  IssueType.sdg1_no_poverty: 'sdg1_no_poverty',
  IssueType.sdg2_zero_hunger: 'sdg2_zero_hunger',
  IssueType.sdg3_good_health_and_well_being: 'sdg3_good_health_and_well_being',
  IssueType.sdg4_quality_education: 'sdg4_quality_education',
  IssueType.sdg5_gender_equality: 'sdg5_gender_equality',
  IssueType.sdg6_clean_water_and_sanitation: 'sdg6_clean_water_and_sanitation',
  IssueType.sdg7_affordable_and_clean_energy: 'sdg7_affordable_and_clean_energy',
  IssueType.sdg8_decent_work_and_economic_growth: 'sdg8_decent_work_and_economic_growth',
  IssueType.sdg9_industry_innovation_and_infrastructure: 'sdg9_industry_innovation_and_infrastructure',
  IssueType.sdg10_reduced_inequalities: 'sdg10_reduced_inequalities',
  IssueType.sdg11_sustainable_cities_and_communities: 'sdg11_sustainable_cities_and_communities',
  IssueType.sdg12_responsible_consumption_and_production: 'sdg12_responsible_consumption_and_production',
  IssueType.sdg13_climate_action: 'sdg13_climate_action',
  IssueType.sdg14_life_below_water: 'sdg14_life_below_water',
  IssueType.sdg15_life_on_land: 'sdg15_life_on_land',
  IssueType.sdg16_peace_justice_and_strong_institutions: 'sdg16_peace_justice_and_strong_institutions',
  IssueType.sdg17_partnerships_for_the_goals: 'sdg17_partnerships_for_the_goals',
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
