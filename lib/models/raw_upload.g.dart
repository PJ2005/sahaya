// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'raw_upload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RawUpload _$RawUploadFromJson(Map<String, dynamic> json) => _RawUpload(
  id: json['id'] as String,
  ngoId: json['ngoId'] as String,
  cloudinaryUrl: json['cloudinaryUrl'] as String,
  cloudinaryPublicId: json['cloudinaryPublicId'] as String,
  fileType: json['fileType'] as String,
  uploadedAt: const TimestampConverter().fromJson(
    json['uploadedAt'] as Timestamp,
  ),
  status: $enumDecode(_$UploadStatusEnumMap, json['status']),
);

Map<String, dynamic> _$RawUploadToJson(_RawUpload instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ngoId': instance.ngoId,
      'cloudinaryUrl': instance.cloudinaryUrl,
      'cloudinaryPublicId': instance.cloudinaryPublicId,
      'fileType': instance.fileType,
      'uploadedAt': const TimestampConverter().toJson(instance.uploadedAt),
      'status': _$UploadStatusEnumMap[instance.status]!,
    };

const _$UploadStatusEnumMap = {
  UploadStatus.pending: 'pending',
  UploadStatus.processing: 'processing',
  UploadStatus.done: 'done',
  UploadStatus.extraction_failed: 'extraction_failed',
};
