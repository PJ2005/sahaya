import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/volunteer_profile.dart';
import '../../theme/sahaya_theme.dart';
import '../../utils/translator.dart';


class VolunteerOnboardingScreen extends StatefulWidget {
  const VolunteerOnboardingScreen({super.key});

  @override
  State<VolunteerOnboardingScreen> createState() => _VolunteerOnboardingScreenState();
}

class _VolunteerOnboardingScreenState extends State<VolunteerOnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _step = 0;

  // Step 0
  final TextEditingController _usernameCtrl = TextEditingController();

  // Step 1
  GeoPoint? _loc;
  double _radius = 10;
  bool _fetching = false;
  String? _locError;

  // Step 2
  final _skills = ['communication', 'data_entry', 'transport', 'technical', 'medical', 'education', 'physical_labor', 'community_outreach'];
  final Set<String> _picked = {};
  final TextEditingController _customSkillCtrl = TextEditingController();

  // Step 3
  final _languages = ['Tamil', 'Telugu', 'Hindi', 'English', 'Other'];
  String? _lang;

  bool _saving = false;

  Future<void> _next() async {
    if (_step == 0) {
      final username = _usernameCtrl.text.trim();
      if (username.isEmpty) { _snack('Choose a username to continue'); return; }
      
      setState(() => _fetching = true);
      try {
        final qs = await FirebaseFirestore.instance
            .collection('volunteer_profiles')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();
        if (qs.docs.isNotEmpty) {
          _snack('This username is already taken. Try another.');
          return;
        }
      } catch (e) {
        _snack('Error checking username: $e');
        return;
      } finally {
        setState(() => _fetching = false);
      }
    }

    if (_step == 1 && _loc == null) { _snack('Share your location to continue'); return; }
    if (_step == 2 && _picked.isEmpty) { _snack('Pick at least one skill'); return; }
    if (_step < 3) { 
      // If the user typed a custom skill but forgot to hit Add, auto-add it
      final text = _customSkillCtrl.text.trim().toLowerCase().replaceAll(' ', '_');
      if (_step == 2 && text.isNotEmpty && !_skills.contains(text)) {
        _skills.add(text);
        _picked.add(text);
        _customSkillCtrl.clear();
      }
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); 
    }
    else {
      if (_lang == null) { _snack('Select a language'); return; }
      _complete();
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: T(msg), backgroundColor: SahayaColors.amber));
  }

  Future<void> _getLocation() async {
    setState(() { _fetching = true; _locError = null; });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) throw Exception('Permission denied');
      if (perm == LocationPermission.deniedForever) throw Exception('Location permanently denied — enable in settings');
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      setState(() { _loc = GeoPoint(pos.latitude, pos.longitude); _fetching = false; });
    } catch (e) {
      setState(() { _fetching = false; _locError = e.toString(); });
    }
  }

  Future<void> _complete() async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Authentication lost. Please restart the app.');
      
      String? token;
      try {
        token = await FirebaseMessaging.instance.getToken();
      } catch (_) {}

      final profile = VolunteerProfile(
        id: user.uid, uid: user.uid, username: _usernameCtrl.text.trim(),
        locationGeoPoint: _loc ?? const GeoPoint(0, 0), radiusKm: _radius,
        skillTags: _picked.toList(), languagePref: _lang ?? 'English', availabilityWindowActive: true,
        availabilityUpdatedAt: DateTime.now(), fcmToken: token,
      );
      await FirebaseFirestore.instance.collection('volunteer_profiles').doc(user.uid).set(profile.toJson());
    } catch (e) {
      if (mounted) { setState(() => _saving = false); _snack('Failed: $e'); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: T('Join Sahaya', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_step + 1) / 4,
                minHeight: 5,
                backgroundColor: Theme.of(context).brightness == Brightness.dark ? SahayaColors.darkBorder : const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation(cs.primary),
              ),
            ),
          ),

          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _step = i),
              children: [_usernameStep(), _locationStep(), _skillsStep(), _languageStep()],
            ),
          ),

          // Bottom bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: () => _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      child: T('Back', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_saving || _fetching) ? null : _next,
                      child: (_saving || _fetching)
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : T(_step == 3 ? 'Complete' : 'Continue', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──── Step 1 ────
  Widget _locationStep() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24)),
            child: Icon(Icons.my_location_rounded, size: 40, color: cs.primary),
          ),
          const SizedBox(height: 28),
          T('Where are you?', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          T('We match you with tasks near your location.', style: GoogleFonts.inter(color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted, fontSize: 15)),
          const SizedBox(height: 32),

          if (_loc == null) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _fetching ? null : _getLocation,
                icon: _fetching ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2)) : const Icon(Icons.gps_fixed_rounded),
                label: T(_fetching ? 'Finding...' : 'Share Location'),
              ),
            ),
            if (_locError != null) Padding(padding: const EdgeInsets.only(top: 12), child: T(_locError!, style: GoogleFonts.inter(color: SahayaColors.coral, fontSize: 13), textAlign: TextAlign.center)),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: SahayaColors.emeraldMuted, borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_circle_rounded, color: SahayaColors.emerald),
                const SizedBox(width: 10),
                T('Location secured', style: GoogleFonts.inter(color: SahayaColors.emeraldDark, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 28),
            T('Match Radius', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            Slider(
              value: _radius, min: 5, max: 50, divisions: 9,
              label: '${_radius.round()} km',
              onChanged: (v) => setState(() => _radius = v),
              activeColor: cs.primary,
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              T('5 km', style: GoogleFonts.inter(fontSize: 12, color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted)),
              T('50 km', style: GoogleFonts.inter(fontSize: 12, color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted)),
            ]),
          ],
        ],
      ),
    );
  }

  // ──── Step 2 ────
  Widget _skillsStep() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          T('Your Skills', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          T('Pick what you\'re good at.', style: GoogleFonts.inter(color: Theme.of(context).brightness == Brightness.dark ? SahayaColors.darkMuted : SahayaColors.lightMuted, fontSize: 15)),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: _skills.map((s) {
              final on = _picked.contains(s);
              return FilterChip(
                label: T(s.replaceAll('_', ' '), style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: on ? Colors.white : cs.onSurface)),
                selected: on,
                onSelected: (v) => setState(() { v ? _picked.add(s) : _picked.remove(s); }),
                backgroundColor: Theme.of(context).brightness == Brightness.dark ? SahayaColors.darkSurface : const Color(0xFFF3F4F6),
                selectedColor: cs.primary,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: on ? cs.primary : (Theme.of(context).brightness == Brightness.dark ? SahayaColors.darkBorder : SahayaColors.lightBorder))),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customSkillCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add custom skill...',
                    hintStyle: GoogleFonts.inter(fontSize: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onPressed: () {
                  final text = _customSkillCtrl.text.trim().toLowerCase().replaceAll(' ', '_');
                  if (text.isNotEmpty) {
                    setState(() {
                      if (!_skills.contains(text)) _skills.add(text);
                      _picked.add(text);
                      _customSkillCtrl.clear();
                    });
                  }
                },
                child: const T('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──── Step 3 ────
  Widget _languageStep() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          T('Language', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          T('Preferred language for task briefings.', style: GoogleFonts.inter(color: Theme.of(context).brightness == Brightness.dark ? SahayaColors.darkMuted : SahayaColors.lightMuted, fontSize: 15)),
          const SizedBox(height: 28),
          ..._languages.map((l) => RadioListTile<String>(
            title: T(l, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            value: l, 
            groupValue: _lang, // ignore: deprecated_member_use
            onChanged: (v) => setState(() => _lang = v), // ignore: deprecated_member_use
            activeColor: cs.primary,
            contentPadding: EdgeInsets.zero,
          )),
        ],
      ),
    );
  }

  // ──── Step 0 ────
  Widget _usernameStep() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24)),
            child: Icon(Icons.face_rounded, size: 40, color: cs.primary),
          ),
          const SizedBox(height: 28),
          T('Create Identity', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          T('Choose a username so the team knows you.', style: GoogleFonts.inter(color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted, fontSize: 15)),
          const SizedBox(height: 32),
          TextField(
            controller: _usernameCtrl,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'e.g. superhero123',
              prefixIcon: Icon(Icons.alternate_email_rounded, color: cs.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: T(
              'Already have an account? Sign In',
              style: GoogleFonts.inter(color: cs.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
