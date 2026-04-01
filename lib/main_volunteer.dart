import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'app.dart';
import 'flavors.dart';
import 'firebase_options_volunteer.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const bool useEmulator = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Continue without dotenv to keep app booting; feature code will show
    // clear configuration errors where env values are required.
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (useEmulator) {
    String host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  }

  F.appFlavor = Flavor.volunteer;
  runApp(const App());
}
