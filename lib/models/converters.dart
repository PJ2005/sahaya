import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TimestampConverter implements JsonConverter<DateTime, Timestamp> {
  const TimestampConverter();

  @override
  DateTime fromJson(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return DateTime.now();
  }

  @override
  Timestamp toJson(DateTime date) => Timestamp.fromDate(date);
}

class OptionalTimestampConverter implements JsonConverter<DateTime?, Timestamp?> {
  const OptionalTimestampConverter();

  @override
  DateTime? fromJson(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return null;
  }

  @override
  Timestamp? toJson(DateTime? date) => date == null ? null : Timestamp.fromDate(date);
}

class GeoPointConverter implements JsonConverter<GeoPoint, GeoPoint> {
  const GeoPointConverter();

  @override
  GeoPoint fromJson(dynamic point) {
    if (point is GeoPoint) return point;
    return const GeoPoint(0, 0);
  }

  @override
  GeoPoint toJson(GeoPoint point) => point;
}

class OptionalGeoPointConverter implements JsonConverter<GeoPoint?, GeoPoint?> {
  const OptionalGeoPointConverter();

  @override
  GeoPoint? fromJson(dynamic point) {
    if (point is GeoPoint) return point;
    return null;
  }

  @override
  GeoPoint? toJson(GeoPoint? point) => point;
}
