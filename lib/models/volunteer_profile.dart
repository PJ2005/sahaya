import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'converters.dart';

part 'volunteer_profile.freezed.dart';
part 'volunteer_profile.g.dart';

@freezed
abstract class VolunteerProfile with _$VolunteerProfile {
  const VolunteerProfile._();
  const factory VolunteerProfile({
    required String id,
    required String uid,
    @GeoPointConverter() required GeoPoint locationGeoPoint,
    required double radiusKm,
    required List<String> skillTags,
    required String languagePref,
    required bool availabilityWindowActive,
    @TimestampConverter() required DateTime availabilityUpdatedAt,
    String? fcmToken,
  }) = _VolunteerProfile;

  factory VolunteerProfile.fromJson(Map<String, dynamic> json) => _$VolunteerProfileFromJson(json);
}
