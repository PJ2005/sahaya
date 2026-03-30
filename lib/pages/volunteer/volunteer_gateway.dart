import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'volunteer_home_screen.dart';
import 'volunteer_onboarding_screen.dart';

class VolunteerGateway extends StatefulWidget {
  const VolunteerGateway({super.key});

  @override
  State<VolunteerGateway> createState() => _VolunteerGatewayState();
}

class _VolunteerGatewayState extends State<VolunteerGateway> {
  bool _isLoading = true;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _startAuthFlow();
  }

  Future<void> _startAuthFlow() async {
    try {
      final userFallback = FirebaseAuth.instance.currentUser;
      UserCredential? credential;
      
      if (userFallback == null) {
        credential = await FirebaseAuth.instance.signInAnonymously();
        _uid = credential.user!.uid;
      } else {
        _uid = userFallback.uid;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auth failed: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to Sahaya...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_uid == null) {
      return const Scaffold(body: Center(child: Text('Authentication failed. Please restart.')));
    }

    return StreamBuilder<DocumentSnapshot>(
      // Listen to the volunteer profile
      stream: FirebaseFirestore.instance.collection('volunteer_profiles').doc(_uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Database Error: ${snapshot.error}')));
        }

        // If the document doesn't exist, route to onboarding.
        // If it does, route to home.
        if (snapshot.hasData && snapshot.data!.exists) {
           // We pass the uid so the home screen can load user-specific data
           return VolunteerHomeScreen(uid: _uid!);
        } else {
           return const VolunteerOnboardingScreen();
        }
      },
    );
  }
}
