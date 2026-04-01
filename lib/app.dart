import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'flavors.dart';
import 'pages/ngo_dashboard.dart';
import 'pages/volunteer/volunteer_gateway.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'components/offline_banner_wrapper.dart';
import 'theme/sahaya_theme.dart';
import 'theme/theme_provider.dart';

// Global theme provider so any screen can toggle dark mode
final themeProvider = ThemeProvider();

class AuthGateway extends StatefulWidget {
  const AuthGateway({super.key});

  @override
  State<AuthGateway> createState() => _AuthGatewayState();
}

class _AuthGatewayState extends State<AuthGateway> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  Future<void> _authenticate(bool isLogin) async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Authentication failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: cs.primary),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return NgoDashboard(ngoId: snapshot.data!.uid);
        }

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── Logo area ───
                    const SizedBox(height: 40),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cs.primary, cs.primary.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Welcome to\nSahaya',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -1,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Community impact starts here.',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ─── Email ───
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── Password ───
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

                    // ─── Buttons ───
                    _isLoading
                        ? Center(child: CircularProgressIndicator(color: cs.primary))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () => _authenticate(true),
                                  child: const Text('Sign In'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 56,
                                child: OutlinedButton(
                                  onPressed: () => _authenticate(false),
                                  child: const Text('Create Account'),
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    themeProvider.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget initialScreen = F.appFlavor == Flavor.ngo
        ? const AuthGateway()
        : const VolunteerGateway();

    return MaterialApp(
      title: F.title,
      debugShowCheckedModeBanner: false,
      theme: SahayaTheme.light(),
      darkTheme: SahayaTheme.dark(),
      themeMode: themeProvider.mode,
      home: OfflineBannerWrapper(
        child: _flavorBanner(child: initialScreen, show: kDebugMode),
      ),
    );
  }

  Widget _flavorBanner({required Widget child, bool show = true}) => show
      ? Banner(
          location: BannerLocation.topStart,
          message: F.name,
          color: SahayaColors.emerald.withValues(alpha: 0.8),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 1,
            color: Colors.white,
          ),
          textDirection: TextDirection.ltr,
          child: child,
        )
      : child;
}
