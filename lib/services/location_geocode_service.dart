import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class LocationGeocodeService {
  static const GeoPoint _indiaCenter = GeoPoint(22.5937, 78.9629);

  static Future<GeoPoint> approximateFromFields({
    required String ward,
    String? city,
  }) async {
    final normalizedWard = ward.trim();
    final normalizedCity = (city ?? '').trim();

    final queries = <String>[
      if (normalizedWard.isNotEmpty && normalizedCity.isNotEmpty)
        '$normalizedWard, $normalizedCity, India',
      if (normalizedWard.isNotEmpty) '$normalizedWard, India',
      if (normalizedCity.isNotEmpty) '$normalizedCity, India',
    ];

    for (final query in queries) {
      final point = await _lookup(query);
      if (point != null) return point;
    }

    final fallbackSeed = [
      normalizedWard.toLowerCase(),
      normalizedCity.toLowerCase(),
    ].where((value) => value.isNotEmpty).join('|');

    return _fallbackPoint(fallbackSeed);
  }

  static Future<GeoPoint?> _lookup(String query) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'limit': '1',
      });

      final response = await http
          .get(
            uri,
            headers: const {
              'User-Agent': 'Sahaya/1.0 (location lookup)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) return null;

      final first = decoded.first;
      final lat = double.tryParse('${first['lat'] ?? ''}');
      final lon = double.tryParse('${first['lon'] ?? ''}');
      if (lat == null || lon == null) return null;
      return GeoPoint(lat, lon);
    } catch (_) {
      return null;
    }
  }

  static GeoPoint _fallbackPoint(String seed) {
    if (seed.isEmpty) return _indiaCenter;

    final hash = seed.codeUnits.fold<int>(
      0,
      (value, code) => (value * 31 + code) & 0x7fffffff,
    );
    final latOffset = ((hash % 900) / 1000.0) - 0.45;
    final lonOffset = (((hash ~/ 900) % 900) / 1000.0) - 0.45;

    return GeoPoint(
      _clamp(_indiaCenter.latitude + latOffset, -90, 90),
      _clamp(_indiaCenter.longitude + lonOffset, -180, 180),
    );
  }

  static double _clamp(double value, double min, double max) {
    return math.max(min, math.min(value, max));
  }
}
