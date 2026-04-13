import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/sahaya_theme.dart';
import 'volunteer_home_screen.dart';
import 'volunteer_onboarding_screen.dart';
import '../../utils/translator.dart';


import 'volunteer_auth_screen.dart';

class VolunteerGateway extends StatefulWidget {
  const VolunteerGateway({super.key});

  @override
  State<VolunteerGateway> createState() => _VolunteerGatewayState();
}

class _VolunteerGatewayState extends State<VolunteerGateway> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return _loading(cs);
        }

        final user = authSnapshot.data;

        // If no user, show the persistent Auth Screen (Email/Pass)
        if (user == null) {
          return const VolunteerAuthScreen();
        }

        final uid = user.uid;

        // Check if the volunteer has completed onboarding
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('volunteer_profiles')
              .doc(uid)
              .snapshots(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return _loading(cs);
            }
            if (profileSnapshot.hasData && profileSnapshot.data!.exists) {
              return VolunteerHomeScreen(uid: uid);
            }
            
            // Logged in but no profile document -> Go to onboarding
            return const VolunteerOnboardingScreen();
          },
        );
      },
    );
  }

  Widget _loading(ColorScheme cs) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.favorite_rounded, color: cs.primary, size: 32),
            ),
            const SizedBox(height: 24),
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2.5)),
            const SizedBox(height: 16),
            T('Connecting...', style: GoogleFonts.inter(color: Theme.of(context).brightness == Brightness.dark ? SahayaColors.darkMuted : SahayaColors.lightMuted)),
          ],
        ),
      ),
    );
  }
}
