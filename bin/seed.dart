import 'dart:convert';
import 'package:http/http.dart' as http;

Map<String, dynamic> encodeValue(dynamic value) {
  if (value == null) return {'nullValue': null};
  if (value is String) return {'stringValue': value};
  if (value is int) return {'integerValue': value.toString()};
  if (value is double) return {'doubleValue': value};
  if (value is bool) return {'booleanValue': value};
  if (value is List) return {'arrayValue': {'values': value.map(encodeValue).toList()}};
  if (value is Map) {
    if (value.containsKey('latitude') && value.containsKey('longitude')) {
      return {'geoPointValue': {'latitude': value['latitude'], 'longitude': value['longitude']}};
    }
    return {'mapValue': {'fields': value.map((k, v) => MapEntry(k, encodeValue(v)))}};
  }
  if (value is DateTime) return {'timestampValue': value.toUtc().toIso8601String()};
  return {'nullValue': null};
}

Map<String, dynamic> encodeDocument(Map<String, dynamic> data) {
  return {'fields': data.map((k, v) => MapEntry(k, encodeValue(v)))};
}

Future<void> createDoc(String collectionId, String documentId, Map<String, dynamic> data) async {
  final url = Uri.parse('https://firestore.googleapis.com/v1/projects/sahaya-7df6d/databases/(default)/documents/$collectionId?documentId=$documentId');

  
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode(encodeDocument(data)),
  );
  if (response.statusCode >= 200 && response.statusCode < 300) {
    print('Inserted $collectionId/$documentId');
  } else {
    print('Failed to insert $documentId: ${response.statusCode} - ${response.body}');
    print(jsonEncode(encodeDocument(data)));
  }
}

void main() async {
  print('Starting Sahaya Emulator Seeder...');
  
  // 1. Two Test NGOs
  await createDoc('users', 'ngo_a_uid', {
    'uid': 'ngo_a_uid',
    'email': 'contact@ngoa.org',
    'name': 'NGO A - Relief Foundation',
    'role': 'ngo'
  });
  
  await createDoc('users', 'ngo_b_uid', {
    'uid': 'ngo_b_uid',
    'email': 'hello@ngob.org',
    'name': 'NGO B - Education Trust',
    'role': 'ngo'
  });

  // 2. Three ProblemCards
  await createDoc('problem_cards', 'pc_ambattur', {
    'id': 'pc_ambattur',
    'ngoId': 'ngo_a_uid',
    'issueType': 'water_access',
    'locationWard': 'Ward 7',
    'locationCity': 'Ambattur, Chennai',
    'severityLevel': 'critical',
    'affectedCount': 500,
    'description': 'Severe water pipe burst affecting 500 households, requires emergency tank distribution.',
    'confidenceScore': 0.95,
    'status': 'pending_review',
    'priorityScore': 0.99,
    'severityContrib': 0.40,
    'scaleContrib': 0.30,
    'recencyContrib': 0.20,
    'gapContrib': 0.10,
    'createdAt': DateTime.now(),
    'anonymized': false
  });

  await createDoc('problem_cards', 'pc_kodambakkam', {
    'id': 'pc_kodambakkam',
    'ngoId': 'ngo_b_uid',
    'issueType': 'education',
    'locationWard': 'Ward 12',
    'locationCity': 'Kodambakkam, Chennai',
    'severityLevel': 'medium',
    'affectedCount': 50,
    'description': 'Local corporation school requires volunteers to aid with high school enrollment processing.',
    'confidenceScore': 0.85,
    'status': 'approved',
    'priorityScore': 0.60,
    'severityContrib': 0.20,
    'scaleContrib': 0.10,
    'recencyContrib': 0.15,
    'gapContrib': 0.15,
    'createdAt': DateTime.now(),
    'anonymized': false
  });

  await createDoc('problem_cards', 'pc_adyar', {
    'id': 'pc_adyar',
    'ngoId': 'ngo_a_uid',
    'issueType': 'nutrition',
    'locationWard': 'Ward 3',
    'locationCity': 'Adyar, Chennai',
    'severityLevel': 'high',
    'affectedCount': 100,
    'description': 'Weekly community kitchen looking for resources and volunteers to serve 100 meals.',
    'confidenceScore': 0.92,
    'status': 'pending_review',
    'priorityScore': 0.75,
    'severityContrib': 0.30,
    'scaleContrib': 0.20,
    'recencyContrib': 0.15,
    'gapContrib': 0.10,
    'createdAt': DateTime.now(),
    'anonymized': false
  });

  // 3. Two Volunteer Profiles
  await createDoc('volunteer_profiles', 'vol_1_uid', {
    'id': 'vol_1_uid',
    'uid': 'vol_1_uid',
    'locationGeoPoint': {'latitude': 13.0827, 'longitude': 80.2707}, // Chennai Central
    'radiusKm': 10.0,
    'skillTags': ['logistics_coordination', 'first_aid', 'local_language'],
    'languagePref': 'Tamil',
    'availabilityWindowActive': true,
    'availabilityUpdatedAt': DateTime.now(),
    'fcmToken': 'dummy_fcm_token_1'
  });

  await createDoc('volunteer_profiles', 'vol_2_uid', {
    'id': 'vol_2_uid',
    'uid': 'vol_2_uid',
    'locationGeoPoint': {'latitude': 12.9675, 'longitude': 80.2582}, // Thiruvanmiyur
    'radiusKm': 15.0,
    'skillTags': ['education', 'teaching', 'awareness_session'],
    'languagePref': 'English, Tamil',
    'availabilityWindowActive': true,
    'availabilityUpdatedAt': DateTime.now(),
    'fcmToken': 'dummy_fcm_token_2'
  });
  
  print('Seeding completed successfully!');
}
