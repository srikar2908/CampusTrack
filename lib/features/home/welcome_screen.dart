import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import 'student_dashboard_screen.dart';
import 'office_dashboard_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _checkingLogin = true;

  @override
  void initState() {
    super.initState();
    // Ensure context is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserStatus();
    });
  }

  Future<void> _checkUserStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      debugPrint("🚀 Checking user status...");

      // Add timeout to prevent infinite waiting
      await authProvider
          .fetchCurrentUser()
          .timeout(const Duration(seconds: 6), onTimeout: () {
        throw Exception("⏰ Timeout while checking user session");
      });

      debugPrint("✅ Finished checking user status");

      if (!mounted) return;

      if (authProvider.appUser != null) {
        // Navigate if user session exists
        _navigateToDashboard(authProvider.appUser!.role);
      } else {
        // No session found, release UI
        setState(() => _checkingLogin = false);
      }
    } catch (e) {
      debugPrint('❌ User check failed: $e');
      if (!mounted) return;
      setState(() => _checkingLogin = false);
    }
  }

  void _navigateToDashboard(String role) {
    if (!mounted) return;

    Widget dashboard;
    if (role == 'student' || role == 'staff') {
      dashboard = const StudentDashboardScreen();
    } else if (role == 'office_admin') {
      dashboard = const OfficeDashboardScreen();
    } else {
      dashboard = const LoginScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => dashboard),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingLogin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome to CampusTrack!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text(
              'CampusTrack helps students and staff report, track, and manage lost & found items in a secure and organized way.',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            _WelcomeButton(),
          ],
        ),
      ),
    );
  }
}

class _WelcomeButton extends StatelessWidget {
  const _WelcomeButton();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      ),
      child: const Text(
        'Get Started',
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}
