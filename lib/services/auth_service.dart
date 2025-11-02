import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firestore_service.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestore = FirestoreService();

  /// 🔹 Get the currently signed-in Firebase user
  User? get currentUser => _auth.currentUser;

  // ===========================================================================
  // 🟢 SIGN IN WITH EMAIL & PASSWORD
  // 💡 FIX: Return AppUser? instead of User?
  // ===========================================================================
  Future<AppUser?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) return null;

      await _saveFcmToken(uid);
      
      // ✅ Fetch the AppUser data from Firestore immediately after successful login
      return await getAppUser(uid);
      
    } on FirebaseAuthException catch (e) {
      throw Exception('Firebase sign-in failed: ${e.message}');
    } catch (e, st) {
      debugPrint('❌ Sign-in error: $e\n$st');
      throw Exception('Unexpected error during sign-in.');
    }
  }

  // ===========================================================================
  // 🟢 SIGN UP WITH EMAIL & PASSWORD
  // 💡 FIX: Return AppUser? instead of User?
  // ===========================================================================
  Future<AppUser?> signUp({
    required String name,
    required String email,
    required String password,
    required String phoneNumber,
    required String role,
    String? officeId,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) return null;

      final appUser = AppUser(
        uid: user.uid,
        name: name.trim(),
        email: email.trim(),
        phoneNumber: phoneNumber.trim(),
        role: role,
        officeId: officeId ?? '',
      );

      // Save user in Firestore
      await _firestore.saveUser(appUser);
      await _saveFcmToken(user.uid);

      // ✅ Return the fully created AppUser object
      return appUser;
      
    } on FirebaseAuthException catch (e) {
      throw Exception('Firebase sign-up failed: ${e.message}');
    } catch (e, st) {
      debugPrint('❌ Sign-up error: $e\n$st');
      throw Exception('Unexpected error during registration.');
    }
  }

  // ===========================================================================
  // 🟢 GOOGLE SIGN-IN
  // 💡 FIX: Return AppUser? instead of User?
  // ===========================================================================
  Future<AppUser?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return null; // user cancelled

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      final user = userCredential.user;
      if (user == null) return null;

      // Check Firestore for existing user data
      AppUser? appUser = await _firestore.getUser(user.uid).timeout(
            const Duration(seconds: 6),
            onTimeout: () => null,
          );

      // ⚠️ Note: Checking by email as a fallback is generally risky due to security concerns, 
      // but keeping it for now since it was in your original code.
      if (appUser == null && user.email != null) {
         appUser = await _firestore
            .getUserByEmail(user.email!)
            .timeout(const Duration(seconds: 6), onTimeout: () => null);
      }

      // If no existing record, create one
      if (appUser == null) {
        appUser = AppUser(
          uid: user.uid,
          name: user.displayName ?? '',
          email: user.email ?? '',
          phoneNumber: user.phoneNumber ?? '',
          role: 'user', // Default role for Google users
          officeId: '',
        );
        await _firestore.saveUser(appUser);
      }

      await _saveFcmToken(user.uid);
      
      // ✅ Return the AppUser object
      return appUser;
      
    } catch (e, st) {
      debugPrint('❌ Google Sign-In failed: $e\n$st');
      throw Exception('Google Sign-In failed. Please try again.');
    }
  }

  // ===========================================================================
  // 🟢 SIGN OUT (No change needed here)
  // ===========================================================================
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      if (!kIsWeb) await GoogleSignIn().signOut();
    } catch (e, st) {
      debugPrint('❌ Sign-out failed: $e\n$st');
      throw Exception('Logout failed. Please try again.');
    }
  }

  // ===========================================================================
  // 🟢 GET AUTHENTICATED APP USER DATA (New method for AuthProvider)
  // 💡 NEW: Used by AuthProvider to fetch AppUser (role) on startup
  // ===========================================================================
  Future<AppUser?> getAuthenticatedAppUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      return await getAppUser(user.uid);
    }
    return null;
  }

  // ===========================================================================
  // 🟢 GET APP USER DATA FROM FIRESTORE (No change needed here)
  // ===========================================================================
  Future<AppUser?> getAppUser(String uid) async {
    try {
      return await _firestore.getUser(uid).timeout(
            const Duration(seconds: 6),
            onTimeout: () => null,
          );
    } catch (e, st) {
      debugPrint('❌ getAppUser failed: $e\n$st');
      return null;
    }
  }

  // ===========================================================================
  // 🟢 UPDATE APP USER DATA IN FIRESTORE (New method for AuthRepository)
  // 💡 NEW: Used by AuthRepository to update user details
  // ===========================================================================
  Future<void> updateAppUser(String uid, Map<String, dynamic> data) async {
    try {
      // Assuming _firestore.updateUser(uid, data) exists and handles the Firestore call
      await _firestore.updateUser(uid, data);
    } catch (e, st) {
      debugPrint('❌ updateAppUser failed: $e\n$st');
      throw Exception('Failed to update user profile.');
    }
  }

  // ===========================================================================
  // 🟢 SAVE FCM TOKEN TO FIRESTORE (Updated to use updateAppUser for consistency)
  // ===========================================================================
  Future<void> _saveFcmToken(String? uid) async {
    if (uid == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        // 💡 Update to use the new updateAppUser method for consistency
        await updateAppUser(uid, {'fcmToken': token}); 
        debugPrint('✅ FCM token saved for user: $uid');
      }
    } catch (e, st) {
      debugPrint('❌ Failed to save FCM token: $e\n$st');
    }
  }

  // ===========================================================================
  // 🟢 SEND PASSWORD RESET EMAIL (No change needed here)
  // ===========================================================================
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final cleanedEmail = email.trim();
      await _auth.sendPasswordResetEmail(email: cleanedEmail);
      debugPrint('✅ Password reset email sent to $cleanedEmail');
    } on FirebaseAuthException catch (e) {
      throw Exception('Password reset failed: ${e.message}');
    } catch (e, st) {
      debugPrint('❌ Password reset error: $e\n$st');
      throw Exception('Unexpected error during password reset.');
    }
  }
}