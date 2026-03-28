import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'converters.dart';

part 'raw_upload.freezed.dart';
part 'raw_upload.g.dart';

enum UploadStatus { pending, processing, done, extraction_failed }

@freezed
class RawUpload with _$RawUpload {
  const factory RawUpload({
    required String id,
    required String ngoId,
    required String cloudinaryUrl,
    required String cloudinaryPublicId,
    required String fileType,
    @TimestampConverter() required DateTime uploadedAt,
    required UploadStatus status,
  }) = _RawUpload;

  factory RawUpload.fromJson(Map<String, dynamic> json) => _$RawUploadFromJson(json);
}
