// session_controller.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class SessionController {
  // Singleton Pattern
  SessionController._internal();
  static final SessionController _instance = SessionController._internal();
  static SessionController get instance => _instance;

  // Global State Variables
  String? userId;
  String? token; // Firebase Auth token/ID token (optional to store explicitly)
  // NOTE: We don't need expiryDate since Firebase handles token expiration/refresh

  // Keys for Secure Storage
  static const String _keyUserId = 'userId';
  static const String _keyToken = 'token'; // Using the 'token' key for the auth flag

  // ---------------------------------------------------------------------------
  // 🚀 WRITE/SET SESSION
  // ---------------------------------------------------------------------------

  /// Saves the essential user ID and a flag to secure storage.
  Future<void> setSession(String uid) async {
    userId = uid;
    // We store the userId and a simple flag ('true') indicating a session exists
    const storage = FlutterSecureStorage();
    await Future.wait([
      storage.write(key: _keyUserId, value: uid),
      storage.write(key: _keyToken, value: 'true'), // Using token key as simple existence flag
    ]);
    debugPrint('🔐 Session data saved for UID: $uid');
  }

  // ---------------------------------------------------------------------------
  // 🔄 LOAD SESSION (Check on App Startup)
  // ---------------------------------------------------------------------------

  /// Loads the session data from secure storage into the global variables.
  /// Returns true if a valid user ID was found.
  Future<bool> loadSession() async {
    const storage = FlutterSecureStorage();
    
    final response = await Future.wait([
      storage.read(key: _keyUserId),
      storage.read(key: _keyToken), // Read the existence flag
    ]);

    final storedUserId = response[0];
    final storedTokenFlag = response[1];

    if (storedUserId != null && storedTokenFlag == 'true') {
      userId = storedUserId;
      // Note: We don't store the actual Firebase token, as Firebase SDK handles it.
      debugPrint('✅ Session loaded from storage. UID: $userId');
      return true;
    }
    
    // Clear global state if any piece is missing
    clearSession();
    return false;
  }

  // ---------------------------------------------------------------------------
  // 🗑️ CLEAR SESSION (Logout)
  // ---------------------------------------------------------------------------
  
  /// Clears the global variables and deletes data from secure storage.
  Future<void> clearSession() async {
    userId = null;
    token = null; 

    const storage = FlutterSecureStorage();
    await Future.wait([
      storage.delete(key: _keyUserId),
      storage.delete(key: _keyToken),
    ]);
    debugPrint('🗑️ Local session data cleared.');
  }
  
  // ---------------------------------------------------------------------------
  // ❓ SESSION STATUS CHECK
  // ---------------------------------------------------------------------------

  /// Simple getter to check if the global state has a user ID.
  bool get isSessionActive {
    return userId != null;
  }
}