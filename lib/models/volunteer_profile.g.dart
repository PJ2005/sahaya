// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'volunteer_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VolunteerProfile _$VolunteerProfileFromJson(Map<String, dynamic> json) =>
    _VolunteerProfile(
      id: json['id'] as String,
      uid: json['uid'] as String,
      locationGeoPoint: const GeoPointConverter().fromJson(
        json['locationGeoPoint'] as GeoPoint,
      ),
      radiusKm: (json['radiusKm'] as num).toDouble(),
      skillTags: (json['skillTags'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      languagePref: json['languagePref'] as String,
      availabilityWindowActive: json['availabilityWindowActive'] as bool,
      availabilityUpdatedAt: const TimestampConverter().fromJson(
        json['availabilityUpdatedAt'] as Timestamp,
      ),
      fcmToken: json['fcmToken'] as String?,
    );

Map<String, dynamic> _$VolunteerProfileToJson(_VolunteerProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'uid': instance.uid,
      'locationGeoPoint': const GeoPointConverter().toJson(
        instance.locationGeoPoint,
      ),
      'radiusKm': instance.radiusKm,
      'skillTags': instance.skillTags,
      'languagePref': instance.languagePref,
      'availabilityWindowActive': instance.availabilityWindowActive,
      'availabilityUpdatedAt': const TimestampConverter().toJson(
        instance.availabilityUpdatedAt,
      ),
      'fcmToken': instance.fcmToken,
    };
