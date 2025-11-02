import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Import the modular Notification Service
import 'services/notification_service.dart';

// Import your custom services
import 'services/firestore_service.dart';
import 'providers/auth_provider.dart' as my_auth;
import 'providers/items_provider.dart';
import 'providers/office_provider.dart';

import 'core/app_router.dart';
import 'core/app_theme.dart';
import 'core/app_constants.dart'; // <--- ASSUMED IMPORT FOR ROLE CONSTANTS
import 'features/home/welcome_screen.dart';

// --- NEW/UPDATED IMPORTS ---
import 'features/home/office_dashboard_screen.dart';
import 'features/home/student_dashboard_screen.dart';
import 'features/home/notifications_screen.dart'; 
import 'firebase_options.dart';

/// Global navigator key for navigation from notification taps
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Flutter local notifications plugin (REQUIRED FOR TOP-LEVEL BACKGROUND HANDLERS)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ═══════════════════════════════════════════════════════════════════════════
// ⚙️ BACKGROUND HANDLERS & HELPERS
// ═══════════════════════════════════════════════════════════════════════════

/// Background message handler - MUST be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Re-initialize Firebase for the background isolate (always required)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('🔔 Background message received: ${message.messageId}');
}

/// Helper to save/update the FCM token in Firestore using FirestoreService
Future<void> _updateTokenInFirestore(String? uid, String? token) async {
  if (uid != null && token != null) {
    try {
      // ✅ FIX: Use the generic `updateUser` method from FirestoreService
      // which handles merging data (e.g., {'fcmToken': token}).
      await FirestoreService().updateUser(uid, {'fcmToken': token});
      debugPrint('✅ FCM token saved for user: $uid');
    } catch (e) {
      debugPrint('❌ Failed to save FCM token: $e');
    }
  }
}

/// Handle notification taps (deep linking)
void _handleNotificationTap(String? itemId) {
  if (itemId != null && itemId.isNotEmpty) {
    debugPrint('🔗 Navigating to item: $itemId');
    
    // Use WidgetsBinding to ensure navigation happens after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState != null) {
        // Use pushReplacement to ensure a clean navigation stack
        navigatorKey.currentState!.pushReplacement( 
          MaterialPageRoute(
            builder: (_) => NotificationsScreen(highlightItemId: itemId),
          ),
        );
      }
    });
  }
}

/// Handle notification taps (required @pragma for local background taps)
@pragma('vm:entry-point')
void _notificationTapBackground(NotificationResponse response) {
  debugPrint('🔔 Background local notification tapped: ${response.payload}');
  _handleNotificationTap(response.payload);
}


// ═══════════════════════════════════════════════════════════════════════════
// 🚀 MAIN ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveBackgroundNotificationResponse: _notificationTapBackground,
    onDidReceiveNotificationResponse: (NotificationResponse response) { 
      _handleNotificationTap(response.payload); 
    },
  );
  
  await NotificationService().initialize(navigatorKey);

  runApp(const CampusTrackApp());
}

// ═══════════════════════════════════════════════════════════════════════════
// 📱 APP WIDGET (FIXED AUTH ROUTING)
// ═══════════════════════════════════════════════════════════════════════════

class CampusTrackApp extends StatefulWidget {
  const CampusTrackApp({super.key});

  @override
  State<CampusTrackApp> createState() => _CampusTrackAppState();
}

class _CampusTrackAppState extends State<CampusTrackApp> {
  
  @override
  void initState() {
    super.initState();
    // 🗑️ DELETED: The `_setupFCMTokenListener()` call is removed.
    _setupFCMTokenRefreshListener();
  }
  
  void _setupFCMTokenRefreshListener() {
    // 1. Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _updateTokenInFirestore(currentUser.uid, newToken);
      }
    });
    
    // 2. Update FCM token upon login/role fetch
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        final token = await FirebaseMessaging.instance.getToken();
        await _updateTokenInFirestore(user.uid, token);
      }
    });
  }

  /// 🔑 Function to determine which dashboard to show based on role. (No change needed here)
  Widget _getDashboard(BuildContext context) {
    // Get the AppUser from the AuthProvider
    final appUser = Provider.of<my_auth.AuthProvider>(context).appUser;

    if (appUser == null) {
      return const WelcomeScreen(); 
    }

    if (appUser.role == AppConstants.officeAdminRole) {
      return const OfficeDashboardScreen();
    } else if (appUser.role == AppConstants.userRole) {
      return const StudentDashboardScreen();
    } else {
      // Default or unknown role, redirect to a safe screen
      return const WelcomeScreen(); 
    }
  }


  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // CRITICAL: Initialize AuthProvider first
        ChangeNotifierProvider<my_auth.AuthProvider>(
          create: (context) => my_auth.AuthProvider(),
        ),
        ChangeNotifierProvider<ItemsProvider>(
          create: (_) => ItemsProvider(),
        ),
        ChangeNotifierProvider<OfficeProvider>(
          create: (_) => OfficeProvider(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'CampusTrack',
        theme: AppTheme.lightTheme,
        
        // ✅ FIX: Replace StreamBuilder with Consumer to rely on AuthProvider state
        home: Consumer<my_auth.AuthProvider>(
          builder: (context, authProvider, child) {
            
            // 1. Initial State: AuthProvider is checking Firebase Auth + Firestore
            if (authProvider.isLoading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            // 2. User is LOGGED IN (AppUser data is successfully fetched)
            if (authProvider.appUser != null) {
              // AppUser data (including role) is ready. Route based on role.
              return _getDashboard(context);
            }
            
            // 3. User is NOT logged in. Show the login/welcome screen.
            return const WelcomeScreen();
          },
        ),
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}