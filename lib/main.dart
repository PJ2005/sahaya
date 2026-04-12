import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

import 'app.dart';
import 'flavors.dart';
import 'firebase_options_ngo.dart' as ngo_options;
import 'firebase_options_volunteer.dart' as volunteer_options;

const bool useEmulator = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // .env not bundled in release — app uses compile-time/native env values.
  }

  final String? flavorName = appFlavor;
  Flavor parsedFlavor = Flavor.volunteer; // fallback
  if (flavorName != null) {
    parsedFlavor = Flavor.values.firstWhere(
      (element) => element.name == flavorName,
      orElse: () => Flavor.volunteer,
    );
  }

  F.appFlavor = parsedFlavor;

  if (F.appFlavor == Flavor.ngo) {
    await Firebase.initializeApp(options: ngo_options.DefaultFirebaseOptions.currentPlatform);
  } else {
    await Firebase.initializeApp(options: volunteer_options.DefaultFirebaseOptions.currentPlatform);
  }

  if (useEmulator) {
    String host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  }

  runApp(const App());
}
