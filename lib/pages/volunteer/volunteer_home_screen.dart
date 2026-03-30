import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/volunteer_profile.dart';

class VolunteerHomeScreen extends StatefulWidget {
  final String uid;

  const VolunteerHomeScreen({super.key, required this.uid});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Setup pulse animation for the "Yes" CTA
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _updateAvailability(bool isActive, bool isPartial) async {
    try {
      await FirebaseFirestore.instance.collection('volunteer_profiles').doc(widget.uid).update({
        'availabilityWindowActive': isActive,
        'isPartialAvailability': isPartial,
        'availabilityUpdatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Availability updated successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sahaya Volunteer', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.blueAccent)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.blueAccent),
            onPressed: () {},
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('volunteer_profiles').doc(widget.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Profile not found.'));
          }

          final profileMap = snapshot.data!.data() as Map<String, dynamic>;
          final profile = VolunteerProfile.fromJson(profileMap);

          // Evaluation for check-in prompt
          final bool windowActive = profile.availabilityWindowActive;
          final DateTime updatedAt = profile.availabilityUpdatedAt;
          
          final bool isStale = DateTime.now().difference(updatedAt).inDays >= 7;

          if (!windowActive || isStale) {
            return _buildCheckInPrompt(context);
          } else {
            return _buildDashboard(profile);
          }
        },
      ),
    );
  }

  Widget _buildCheckInPrompt(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF7F9FC),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_available, size: 80, color: Colors.blueAccent),
          const SizedBox(height: 24),
          const Text(
            'Available this weekend?',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Let us know if you can help with community tasks recently matched to your location and skillset.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // Primary Yes 
          ScaleTransition(
            scale: _pulseAnimation,
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => _updateAvailability(true, false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: Colors.blueAccent.withValues(alpha: 0.5),
                ),
                child: const Text('Yes, I am available!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Partially
          SizedBox(
            width: double.infinity,
            height: 60,
            child: OutlinedButton(
              onPressed: () => _updateAvailability(true, true),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.blueAccent, width: 2),
                foregroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Partially (A few hours)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),

          // Not this time
          SizedBox(
            width: double.infinity,
            height: 60,
            child: TextButton(
              onPressed: () => _updateAvailability(false, false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Not this time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(VolunteerProfile profile) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.lightBlue]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(profile.isPartialAvailability ? 'Partially Active' : 'Fully Active', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                const Text('You are checked in!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('We are matching you with nearby tasks based on your skills.', style: TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('Recommended Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.radar, size: 60, color: Colors.blue[100]),
                  const SizedBox(height: 16),
                  const Text('Scanning for community needs...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
