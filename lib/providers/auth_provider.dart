import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../repositories/auth_repository.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepo = AuthRepository();

  AppUser? _appUser;
  AppUser? get appUser => _appUser;

  // 💡 FIX: Start as TRUE to show loading indicator during initial check.
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // ═══════════════════════════════════════════════════════════════════════════
  // 🚀 CONSTRUCTOR: Handles initial state check on startup (The Key Fix)
  // ═══════════════════════════════════════════════════════════════════════════
  AuthProvider() {
    // Check if a Firebase user is already logged in (from local storage)
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser != null) {
      // If a user is found, fetch the custom AppUser data (role, etc.)
      // The fetchCurrentUser call will set _isLoading to false when done.
      fetchCurrentUser(isInitialLoad: true);
    } else {
      // No logged-in user found, stop loading immediately and show WelcomeScreen.
      _isLoading = false;
    }
  }

  /// Safely update loading state and notify listeners
  void _setLoading(bool value) {
    _isLoading = value;
    // Using addPostFrameCallback ensures we notify listeners *after* the current
    // frame's build phase, avoiding common "setState during build" errors.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Fetch current user safely with defensive error handling
  // 💡 FIX: Added optional flag to handle initial load state slightly differently.
  Future<void> fetchCurrentUser({bool isInitialLoad = false}) async {
    // Only set loading if it's not part of the initial constructor run
    if (!isInitialLoad) {
      _setLoading(true);
    }

    try {
      // This call should fetch the custom AppUser object (including the role) from Firestore
      final user = await _authRepo
          .getCurrentUser()
          .timeout(const Duration(seconds: 6), onTimeout: () {
        debugPrint("⏰ Timeout while fetching current user");
        return null;
      });

      _appUser = user;
    } catch (e, st) {
      debugPrint('❌ Fetch current user failed: $e\n$st');
      _appUser = null;
    } finally {
      if (isInitialLoad) {
        // Must explicitly notify for the initial case if no error occurred
        _isLoading = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      } else {
        // For subsequent calls (e.g., after successful login)
        _setLoading(false);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔑 AUTH METHODS: Now set _appUser immediately upon successful operation
  // ═══════════════════════════════════════════════════════════════════════════

  /// Email/password login
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      final user = await _authRepo.login(email, password);
      if (user != null) {
        // 💡 CRITICAL: Set _appUser immediately here. Since _authRepo.login
        // likely returns the fully fetched AppUser, this update triggers
        // the Consumer in main.dart to route correctly.
        _appUser = user;
        return true;
      }
      return false;
    } catch (e, st) {
      debugPrint('❌ Login failed: $e\n$st');
      _appUser = null;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Register new user
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phoneNumber,
    required String role,
    String? officeId,
  }) async {
    _setLoading(true);
    try {
      final user = await _authRepo.register(
        name: name,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
        role: role,
        officeId: officeId,
      );
      if (user != null) {
        // 💡 CRITICAL: Set _appUser immediately here.
        _appUser = user;
        return true;
      }
      return false;
    } catch (e, st) {
      debugPrint('❌ Registration failed: $e\n$st');
      _appUser = null;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Google Sign-In
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      final user = await _authRepo.signInWithGoogle();
      if (user != null) {
        // 💡 CRITICAL: Set _appUser immediately here.
        _appUser = user;
        return true;
      }
      return false;
    } catch (e, st) {
      debugPrint('❌ Google Sign-In failed: $e\n$st');
      _appUser = null;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Logout user
  Future<void> logout() async {
    _setLoading(true);
    try {
      await _authRepo.logout();
      _appUser = null;
    } catch (e, st) {
      debugPrint('❌ Logout failed: $e\n$st');
    } finally {
      _setLoading(false);
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    try {
      final cleanedEmail = email.trim().toLowerCase();
      await FirebaseAuth.instance.sendPasswordResetEmail(email: cleanedEmail);
      debugPrint('✅ Password reset email sent to $cleanedEmail');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase error during password reset: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('❌ Password reset failed: $e');
      throw Exception(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// ✅ Update user details (name, phone, office, etc.)
  Future<void> updateUser(Map<String, dynamic> updatedFields) async {
    if (_appUser == null) {
      debugPrint('⚠️ No logged-in user to update.');
      return;
    }

    _setLoading(true);
    try {
      await _authRepo.updateUser(_appUser!.uid, updatedFields);

      // Update local model safely
      _appUser = _appUser!.copyWith(
        name: updatedFields['name'] ?? _appUser!.name,
        phoneNumber: updatedFields['phoneNumber'] ?? _appUser!.phoneNumber,
        officeId: updatedFields['officeId'] ?? _appUser!.officeId,
      );

      debugPrint('✅ User updated successfully: ${_appUser!.toMap()}');
      notifyListeners();
    } catch (e, st) {
      debugPrint('❌ Update user failed: $e\n$st');
    } finally {
      _setLoading(false);
    }
  }
}