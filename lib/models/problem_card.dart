// ignore_for_file: constant_identifier_names
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'converters.dart';

part 'problem_card.freezed.dart';
part 'problem_card.g.dart';

enum IssueType {
  sdg1_no_poverty,
  sdg2_zero_hunger,
  sdg3_good_health_and_well_being,
  sdg4_quality_education,
  sdg5_gender_equality,
  sdg6_clean_water_and_sanitation,
  sdg7_affordable_and_clean_energy,
  sdg8_decent_work_and_economic_growth,
  sdg9_industry_innovation_and_infrastructure,
  sdg10_reduced_inequalities,
  sdg11_sustainable_cities_and_communities,
  sdg12_responsible_consumption_and_production,
  sdg13_climate_action,
  sdg14_life_below_water,
  sdg15_life_on_land,
  sdg16_peace_justice_and_strong_institutions,
  sdg17_partnerships_for_the_goals,
}

extension IssueTypeX on IssueType {
  String get sdgTag {
    final n = index + 1;
    return 'SDG $n';
  }

  String get label {
    switch (this) {
      case IssueType.sdg1_no_poverty:
        return 'SDG 1 - No Poverty';
      case IssueType.sdg2_zero_hunger:
        return 'SDG 2 - Zero Hunger';
      case IssueType.sdg3_good_health_and_well_being:
        return 'SDG 3 - Good Health and Well-being';
      case IssueType.sdg4_quality_education:
        return 'SDG 4 - Quality Education';
      case IssueType.sdg5_gender_equality:
        return 'SDG 5 - Gender Equality';
      case IssueType.sdg6_clean_water_and_sanitation:
        return 'SDG 6 - Clean Water and Sanitation';
      case IssueType.sdg7_affordable_and_clean_energy:
        return 'SDG 7 - Affordable and Clean Energy';
      case IssueType.sdg8_decent_work_and_economic_growth:
        return 'SDG 8 - Decent Work and Economic Growth';
      case IssueType.sdg9_industry_innovation_and_infrastructure:
        return 'SDG 9 - Industry, Innovation and Infrastructure';
      case IssueType.sdg10_reduced_inequalities:
        return 'SDG 10 - Reduced Inequalities';
      case IssueType.sdg11_sustainable_cities_and_communities:
        return 'SDG 11 - Sustainable Cities and Communities';
      case IssueType.sdg12_responsible_consumption_and_production:
        return 'SDG 12 - Responsible Consumption and Production';
      case IssueType.sdg13_climate_action:
        return 'SDG 13 - Climate Action';
      case IssueType.sdg14_life_below_water:
        return 'SDG 14 - Life Below Water';
      case IssueType.sdg15_life_on_land:
        return 'SDG 15 - Life on Land';
      case IssueType.sdg16_peace_justice_and_strong_institutions:
        return 'SDG 16 - Peace, Justice and Strong Institutions';
      case IssueType.sdg17_partnerships_for_the_goals:
        return 'SDG 17 - Partnerships for the Goals';
    }
  }

  static IssueType fromString(String raw) {
    final key = raw.trim().toLowerCase();
    for (final value in IssueType.values) {
      if (value.name == key) return value;
    }

    // Legacy mapping for previously saved issue types.
    switch (key) {
      case 'water_access':
      case 'sanitation':
        return IssueType.sdg6_clean_water_and_sanitation;
      case 'education':
        return IssueType.sdg4_quality_education;
      case 'nutrition':
        return IssueType.sdg2_zero_hunger;
      case 'healthcare':
        return IssueType.sdg3_good_health_and_well_being;
      case 'livelihood':
        return IssueType.sdg8_decent_work_and_economic_growth;
      default:
        return IssueType.sdg11_sustainable_cities_and_communities;
    }
  }
}

enum SeverityLevel { low, medium, high, critical }

enum ProblemStatus { pending_review, approved, extraction_failed }

@freezed
abstract class ProblemCard with _$ProblemCard {
  const ProblemCard._();
  const factory ProblemCard({
    required String id,
    required String ngoId,
    required IssueType issueType,
    String? customIssueType,
    required String locationWard,
    required String locationCity,
    @GeoPointConverter() required GeoPoint locationGeoPoint,
    required SeverityLevel severityLevel,
    required int affectedCount,
    required String description,
    required double confidenceScore,
    required ProblemStatus status,
    required double priorityScore,
    required double severityContrib,
    required double scaleContrib,
    required double recencyContrib,
    required double gapContrib,
    @TimestampConverter() required DateTime createdAt,
    required bool anonymized,
  }) = _ProblemCard;

  factory ProblemCard.fromJson(Map<String, dynamic> json) =>
      _$ProblemCardFromJson(json);
}
