import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../models/volunteer_profile.dart';

class VolunteerOnboardingScreen extends StatefulWidget {
  const VolunteerOnboardingScreen({super.key});

  @override
  State<VolunteerOnboardingScreen> createState() =>
      _VolunteerOnboardingScreenState();
}

class _VolunteerOnboardingScreenState extends State<VolunteerOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // Step 1: Location & Radius
  GeoPoint? _currentLocation;
  double _radiusKm = 10.0;
  bool _gettingLocation = false;
  String? _locationError;

  // Step 2: Skills
  final List<String> _availableSkills = [
    'communication',
    'data_entry',
    'transport',
    'technical',
    'medical',
    'education',
    'physical_labor',
    'community_outreach',
  ];
  final Set<String> _selectedSkills = {};

  // Step 3: Language
  final List<String> _languages = [
    'Tamil',
    'Telugu',
    'Hindi',
    'English',
    'Other',
  ];
  String? _selectedLanguage;

  bool _isSaving = false;

  void _nextPage() {
    if (_currentIndex == 0 && _currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please share your location to continue')),
      );
      return;
    }
    if (_currentIndex == 1 && _selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one skill')),
      );
      return;
    }

    if (_currentIndex < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (_selectedLanguage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a language preference')),
        );
        return;
      }
      _completeOnboarding();
    }
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _gettingLocation = true;
      _locationError = null;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permissions are permanently denied, we cannot request permissions. Please enable them in app settings.',
        );
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      setState(() {
        _currentLocation = GeoPoint(position.latitude, position.longitude);
        _gettingLocation = false;
      });
    } catch (e) {
      setState(() {
        _gettingLocation = false;
        _locationError = e.toString();
      });
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final fcmToken = await FirebaseMessaging.instance.getToken();

      final profile = VolunteerProfile(
        id: user.uid,
        uid: user.uid,
        locationGeoPoint: _currentLocation!,
        radiusKm: _radiusKm,
        skillTags: _selectedSkills.toList(),
        languagePref: _selectedLanguage!,
        availabilityWindowActive: true,
        availabilityUpdatedAt: DateTime.now(),
        fcmToken: fcmToken,
      );

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('volunteer_profiles')
          .doc(user.uid)
          .set(profile.toJson());
      // The gateway stream builder will automatically react to this document creation and route to VolunteerHome.
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Volunteer Profile',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.blueAccent,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentIndex + 1) / 3,
            backgroundColor: Colors.blue[50],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
          ),

          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              children: [
                _buildLocationStep(),
                _buildSkillsStep(),
                _buildLanguageStep(),
              ],
            ),
          ),

          // Bottom Bar Navigation
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentIndex > 0)
                  TextButton(
                    onPressed: () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),

                ElevatedButton(
                  onPressed: _isSaving ? null : _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _currentIndex == 2 ? 'Complete Profile' : 'Continue',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==== STEP 1: LOCATION ====
  Widget _buildLocationStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.my_location, size: 64, color: Colors.blueAccent),
          const SizedBox(height: 24),
          const Text(
            'Where are you?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'We need your location to find nearby community needs.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 32),

          if (_currentLocation == null) ...[
            ElevatedButton.icon(
              onPressed: _gettingLocation ? null : _fetchLocation,
              icon: _gettingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.blueAccent,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.gps_fixed),
              label: Text(
                _gettingLocation ? 'Finding you...' : 'Share My Location',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[50],
                foregroundColor: Colors.blueAccent,
                padding: const EdgeInsets.all(16),
                elevation: 0,
              ),
            ),
            if (_locationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _locationError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 12),
                  Text(
                    'Location secured',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Match Radius',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Slider(
              value: _radiusKm,
              min: 5,
              max: 50,
              divisions: 3,
              label: '${_radiusKm.round()} km',
              onChanged: (val) => setState(() => _radiusKm = val),
              activeColor: Colors.blueAccent,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('5km', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(
                  '50km',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==== STEP 2: SKILLS ====
  Widget _buildSkillsStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your Skills',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select tags that match your capabilities.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _availableSkills.map((skill) {
              final isSelected = _selectedSkills.contains(skill);
              return FilterChip(
                label: Text(
                  skill.replaceAll('_', ' '),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.blueAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedSkills.add(skill);
                    } else {
                      _selectedSkills.remove(skill);
                    }
                  });
                },
                backgroundColor: Colors.blue[50],
                selectedColor: Colors.blueAccent,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : Colors.blue[200]!,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ==== STEP 3: LANGUAGE ====
  Widget _buildLanguageStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Preferred Language',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Which language do you prefer to receive tasks in?',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          ..._languages.map((lang) {
            return RadioListTile<String>(
              title: Text(
                lang,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              value: lang,
              groupValue: _selectedLanguage,
              onChanged: (val) => setState(() => _selectedLanguage = val),
              activeColor: Colors.blueAccent,
              contentPadding: EdgeInsets.zero,
            );
          }),
        ],
      ),
    );
  }
}
