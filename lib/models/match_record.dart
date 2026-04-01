// ignore_for_file: constant_identifier_names
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'converters.dart';

part 'match_record.freezed.dart';
part 'match_record.g.dart';

enum MatchStatus {
  open,
  accepted,
  proof_submitted,
  proof_approved,
  proof_rejected,
  completed,
}

@freezed
abstract class ProofObject with _$ProofObject {
  const ProofObject._();
  const factory ProofObject({
    required List<String> photoUrls,
    required String note,
    @TimestampConverter() required DateTime submittedAt,
  }) = _ProofObject;

  factory ProofObject.fromJson(Map<String, dynamic> json) =>
      _$ProofObjectFromJson(json);
}

@freezed
abstract class MatchRecord with _$MatchRecord {
  const MatchRecord._();
  const factory MatchRecord({
    required String id,
    required String taskId,
    required String volunteerId,
    required double matchScore,
    required MatchStatus status,
    @Default('') String missionBriefing,
    @Default('') String whatToBring,
    ProofObject? proof,
    String? adminReviewNote,
    @OptionalTimestampConverter() DateTime? completedAt,
  }) = _MatchRecord;

  factory MatchRecord.fromJson(Map<String, dynamic> json) =>
      _$MatchRecordFromJson(json);
}
