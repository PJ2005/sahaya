// ignore_for_file: constant_identifier_names
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'converters.dart';

part 'problem_card.freezed.dart';
part 'problem_card.g.dart';

enum IssueType { water_access, sanitation, education, nutrition, healthcare, livelihood, other }
enum SeverityLevel { low, medium, high, critical }
enum ProblemStatus { pending_review, approved, extraction_failed }

@freezed
abstract class ProblemCard with _$ProblemCard {
  const ProblemCard._();
  const factory ProblemCard({
    required String id,
    required String ngoId,
    required IssueType issueType,
    required String locationWard,
    required String locationCity,
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

  factory ProblemCard.fromJson(Map<String, dynamic> json) => _$ProblemCardFromJson(json);
}
