import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/sahaya_theme.dart';
import '../utils/translator.dart';

class VolunteerTeamList extends StatelessWidget {
  final List<String> volunteerIds;
  final String title;
  
  const VolunteerTeamList({
    super.key, 
    required this.volunteerIds, 
    this.title = 'Volunteer Team',
  });

  Future<Map<String, String>> _resolveVolunteerIdentity(String uid) async {
    // Primary source for volunteer identities.
    final profileDoc = await FirebaseFirestore.instance.collection('volunteer_profiles').doc(uid).get();
    if (profileDoc.exists && profileDoc.data() != null) {
      final data = profileDoc.data()!;
      final username = (data['username'] as String?)?.trim();
      final name = (data['name'] as String?)?.trim();
      final display = (username?.isNotEmpty == true)
          ? username!
          : ((name?.isNotEmpty == true) ? name! : 'Volunteer');
      return {'name': display, 'initials': _initialsFrom(display)};
    }

    // Backward compatibility fallback.
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      final data = userDoc.data()!;
      final name = ((data['username'] as String?) ?? (data['name'] as String?) ?? 'Volunteer').trim();
      final display = name.isEmpty ? 'Volunteer' : name;
      return {'name': display, 'initials': _initialsFrom(display)};
    }

    return {'name': 'Volunteer', 'initials': _initialsFrom(uid)};
  }

  String _initialsFrom(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.map((e) => e[0]).take(2).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (volunteerIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: T(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: cs.primary,
              letterSpacing: 1,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: volunteerIds.length,
            itemBuilder: (context, index) {
              final uid = volunteerIds[index];
              return FutureBuilder<Map<String, String>>(
                future: _resolveVolunteerIdentity(uid),
                builder: (context, snapshot) {
                  final resolved = snapshot.data;
                  final name = resolved?['name'] ?? '...';
                  final initials = resolved?['initials'] ?? '?';

                  return Container(
                    width: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: cs.primary.withValues(alpha: 0.1),
                          child: Text(
                            initials,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
