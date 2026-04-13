import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/sahaya_theme.dart';
import '../../utils/translator.dart';

class VolunteerAuthScreen extends StatefulWidget {
  const VolunteerAuthScreen({super.key});

  @override
  State<VolunteerAuthScreen> createState() => _VolunteerAuthScreenState();
}

class _VolunteerAuthScreenState extends State<VolunteerAuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  Future<void> _authenticate(bool isLogin) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _snack('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        // Note: Profile creation happens in OnboardingScreen if no profile exists
      }
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Authentication failed');
    } catch (e) {
      _snack('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: T(msg), backgroundColor: SahayaColors.amber),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? SahayaColors.darkSurface : SahayaColors.lightSurface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [SahayaColors.emerald, SahayaColors.emeraldMuted],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: SahayaColors.emerald.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(height: 32),
                T(
                  'Join the\nMovement',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -1,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                T(
                  'Become a volunteer and change lives.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted,
                  ),
                ),
                const SizedBox(height: 40),

                // Email
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 16),

                // Password
                TextField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                if (_isLoading)
                  const Center(child: CircularProgressIndicator(color: SahayaColors.emerald))
                else ...[
                  SizedBox(
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () => _authenticate(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const T('Sign In'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 58,
                    child: OutlinedButton(
                      onPressed: () => _authenticate(false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: T('Create Account', style: TextStyle(color: cs.primary)),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
