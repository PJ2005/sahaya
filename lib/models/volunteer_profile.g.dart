// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'volunteer_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VolunteerProfile _$VolunteerProfileFromJson(Map<String, dynamic> json) =>
    _VolunteerProfile(
      id: json['id'] as String,
      uid: json['uid'] as String,
      username: json['username'] as String,
      locationGeoPoint: const GeoPointConverter().fromJson(
        json['locationGeoPoint'] as GeoPoint,
      ),
      radiusKm: (json['radiusKm'] as num).toDouble(),
      skillTags: (json['skillTags'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      languagePref: json['languagePref'] as String,
      availabilityWindowActive: json['availabilityWindowActive'] as bool,
      isPartialAvailability: json['isPartialAvailability'] as bool? ?? false,
      availabilityUpdatedAt: const TimestampConverter().fromJson(
        json['availabilityUpdatedAt'] as Timestamp,
      ),
      fcmToken: json['fcmToken'] as String?,
      tasksCompleted: (json['tasksCompleted'] as num?)?.toInt() ?? 0,
      trustScore: (json['trustScore'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$VolunteerProfileToJson(_VolunteerProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'uid': instance.uid,
      'username': instance.username,
      'locationGeoPoint': const GeoPointConverter().toJson(
        instance.locationGeoPoint,
      ),
      'radiusKm': instance.radiusKm,
      'skillTags': instance.skillTags,
      'languagePref': instance.languagePref,
      'availabilityWindowActive': instance.availabilityWindowActive,
      'isPartialAvailability': instance.isPartialAvailability,
      'availabilityUpdatedAt': const TimestampConverter().toJson(
        instance.availabilityUpdatedAt,
      ),
      'fcmToken': instance.fcmToken,
      'tasksCompleted': instance.tasksCompleted,
      'trustScore': instance.trustScore,
    };
