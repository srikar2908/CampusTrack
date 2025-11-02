import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/home/student_dashboard_screen.dart';
import '../features/home/office_dashboard_screen.dart';
import '../features/items/add_item_screen.dart';
import '../providers/auth_provider.dart';
import '../core/app_constants.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/signup':
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case '/student-dashboard':
        return MaterialPageRoute(builder: (_) => const StudentDashboardScreen());
      case '/office-dashboard':
        return MaterialPageRoute(builder: (_) => const OfficeDashboardScreen());
      case '/add-item':
        return MaterialPageRoute(builder: (_) => const AddItemScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: const Center(child: Text('404 - Page Not Found')),
          ),
        );
    }
  }

  static void navigateToDashboard(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.appUser == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final role = authProvider.appUser!.role;
    Widget dashboard;

    if (role == AppConstants.userRole) {
      dashboard = const StudentDashboardScreen();
    } else if (role == AppConstants.officeAdminRole) {
      dashboard = const OfficeDashboardScreen();
    } else {
      dashboard = const LoginScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => dashboard),
    );
  }
}
