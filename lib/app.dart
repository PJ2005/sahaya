import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'flavors.dart';
import 'pages/ngo_dashboard.dart';
import 'pages/volunteer/volunteer_gateway.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthGateway extends StatefulWidget {
  const AuthGateway({super.key});

  @override
  State<AuthGateway> createState() => _AuthGatewayState();
}

class _AuthGatewayState extends State<AuthGateway> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _authenticate(bool isLogin) async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailController.text.trim(), password: _passwordController.text.trim());
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _emailController.text.trim(), password: _passwordController.text.trim());
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Firebase Error: ${e.message}', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
           return NgoDashboard(ngoId: snapshot.data!.uid);
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF7F9FC),
          appBar: AppBar(title: const Text('Sahaya Field Node', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.blueAccent)), backgroundColor: Colors.white, centerTitle: true),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.security, size: 64, color: Colors.blueAccent),
                    const SizedBox(height: 24),
                    TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'NGO Email Identity', border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Secure Password', border: OutlineInputBorder())),
                    const SizedBox(height: 32),
                    _isLoading 
                      ? const CircularProgressIndicator()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                              onPressed: () => _authenticate(true),
                              child: const Text('Login Natively', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), foregroundColor: Colors.blueAccent),
                              onPressed: () => _authenticate(false),
                              child: const Text('Register Physical NGO Node', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
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

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    Widget initialScreen = F.appFlavor == Flavor.ngo 
        ? const AuthGateway() 
        : const VolunteerGateway();

    return MaterialApp(
      title: F.title,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: _flavorBanner(child: initialScreen, show: kDebugMode),
    );
  }

  Widget _flavorBanner({required Widget child, bool show = true}) => show
      ? Banner(
          location: BannerLocation.topStart,
          message: F.name,
          color: Colors.green.withAlpha(150),
          textStyle: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.0,
            letterSpacing: 1.0,
          ),
          textDirection: TextDirection.ltr,
          child: child,
        )
      : Container(child: child);
}
