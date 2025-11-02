import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../features/home/notifications_screen.dart'; // Make sure this path is correct

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  // Define the channel details here for consistency
  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    // 🔑 CRITICAL: Must match the ID sent from your server ('high_importance_channel')
    'high_importance_channel', 
    'High Importance Notifications',
    description: 'Important notifications for CampusTrack',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Initialize FCM and local notifications
  /// **CRITICAL:** The GlobalKey is needed for navigation when the app is in the background/terminated.
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    // 1. Request Android 13+ POST_NOTIFICATIONS permission at runtime
    if (await Permission.notification.request().isDenied) {
      debugPrint('⚠️ Notification permission denied on Android 13+.');
    }

    // 2. Request permission for iOS & Web (FCM method is concise)
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 3. Create Android notification channel explicitly (required API 26+)
    // 🔑 FIX: This ensures the channel exists BEFORE any notification is received.
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
    
    // 4. Local notification initialization setup
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);

    // 5. Initialize local notifications with onTap handler
    await _local.initialize(
      settings,
      // Handler for local notifications tapped while app is in the FOREGROUND
      onDidReceiveNotificationResponse: (NotificationResponse? response) {
        final payload = response?.payload;
        if (payload != null && payload.isNotEmpty && navigatorKey.currentState != null) {
          // Navigation to the correct screen
          navigatorKey.currentState!.pushReplacement(
            MaterialPageRoute(
              builder: (_) => NotificationsScreen(highlightItemId: payload),
            ),
          );
        }
      },
    );

    // 6. Listen for **FOREGROUND** FCM messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('--- 🔔 FOREGROUND MESSAGE RECEIVED ---');
      final notification = message.notification;
      
      // 🔑 FIX: Programmatically show the notification when app is in the foreground
      if (notification != null || message.data.isNotEmpty) { 
        _showLocal(notification?.title, notification?.body, message.data);
      }
    });

    // 7. Handle FCM tap when app is in **BACKGROUND**
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final payload = message.data['itemId'] ?? message.data['reqId'];
      if (payload != null && navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushReplacement(
          MaterialPageRoute(
            builder: (_) => NotificationsScreen(highlightItemId: payload.toString()),
          ),
        );
      }
    });

    // 8. Handle initial message if app was **TERMINATED**
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      final payload = initialMessage.data['itemId'] ?? initialMessage.data['reqId'];
      if (payload != null) {
        // Delay navigation to ensure the widget tree is fully built (safer startup)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (navigatorKey.currentState != null) {
            navigatorKey.currentState!.pushReplacement(
              MaterialPageRoute(
                builder: (_) => NotificationsScreen(highlightItemId: payload.toString()),
              ),
            );
          }
        });
      }
    }
  }

  /// Get device FCM token
  Future<String?> getDeviceToken() async => _fcm.getToken();

  /// Show local notification (used for foreground messages)
  Future<void> _showLocal(
      String? title, String? body, Map<String, dynamic> data) async {
    
    // Fallback logic using the data payload sent from the server
    final finalTitle = title ?? data['title'] ?? 'CampusTrack';
    final finalBody = body ?? data['body'] ?? '';

    // 🔑 FIX: Ensure AndroidDetails uses the properties of the static channel
    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id, 
      _androidChannel.name, 
      channelDescription: _androidChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      // The icon must be defined in your Android project: @mipmap/ic_launcher or @drawable/notification_icon
    );

    const iosDetails = DarwinNotificationDetails();

    final platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _local.show(
      // Use millisecondsSinceEpoch for a unique ID to prevent collisions
      DateTime.now().millisecondsSinceEpoch ~/ 1000, 
      finalTitle,
      finalBody,
      platformDetails,
      // Payload is used for navigation on tap (check both ID types)
      payload: data['itemId']?.toString() ?? data['reqId']?.toString() ?? '',
    );
  }
}