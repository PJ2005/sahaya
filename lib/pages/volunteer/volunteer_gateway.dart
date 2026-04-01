import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/sahaya_theme.dart';
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        final cred = await FirebaseAuth.instance.signInAnonymously();
        _uid = cred.user!.uid;
      } else {
        _uid = user.uid;
      }
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auth failed: $e'), backgroundColor: SahayaColors.coral),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.favorite_rounded, color: cs.primary, size: 32),
              ),
              const SizedBox(height: 24),
              SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2.5)),
              const SizedBox(height: 16),
              Text('Connecting...', style: GoogleFonts.inter(color: Theme.of(context).brightness == Brightness.dark ? SahayaColors.darkMuted : SahayaColors.lightMuted)),
            ],
          ),
        ),
      );
    }

    if (_uid == null) {
      return const Scaffold(body: Center(child: Text('Authentication failed. Please restart.')));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('volunteer_profiles').doc(_uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator(color: cs.primary)));
        }
        if (snapshot.hasData && snapshot.data!.exists) {
          return VolunteerHomeScreen(uid: _uid!);
        }
        return const VolunteerOnboardingScreen();
      },
    );
  }
}
