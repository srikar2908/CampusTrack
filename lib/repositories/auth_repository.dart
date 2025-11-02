import '../models/app_user.dart';
import '../services/auth_service.dart';
// ⚠️ Removed: import 'package:cloud_firestore/cloud_firestore.dart';
// All Firestore access should be delegated to a Service layer.

class AuthRepository {
  final AuthService _authService = AuthService();

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔑 AUTH OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// 🔹 Login with email/password and fetch AppUser data
  Future<AppUser?> login(String email, String password) async {
    try {
      // Assuming _authService.signIn returns the AppUser object if successful,
      // which includes the role and other Firestore data.
      final appUser = await _authService.signIn(email: email, password: password);
      
      // If the service layer only handles Firebase Auth and returns a Firebase User,
      // you must use: `return await _authService.getAppUser(firebaseUser.uid);`
      
      return appUser;
    } catch (e, st) {
      // Re-throw a standardized exception for the AuthProvider to handle.
      throw Exception('❌ Login failed: $e\n$st');
    }
  }

  /// 🔹 Register a new user and fetch the created AppUser data
  Future<AppUser?> register({
    required String name,
    required String email,
    required String password,
    required String phoneNumber,
    required String role,
    String? officeId,
  }) async {
    try {
      // Assuming _authService.signUp handles both Firebase Auth creation AND Firestore doc creation,
      // and returns the fully created AppUser object.
      final appUser = await _authService.signUp(
        name: name,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
        role: role,
        officeId: officeId,
      );
      
      return appUser;
    } catch (e, st) {
      throw Exception('❌ Registration failed: $e\n$st');
    }
  }

  /// 🔹 Google Sign-In and fetch AppUser data
  Future<AppUser?> signInWithGoogle() async {
    try {
      // Assuming _authService.signInWithGoogle handles the sign-in and subsequent
      // fetching/creation of the AppUser Firestore document.
      final appUser = await _authService.signInWithGoogle();
      
      return appUser;
    } catch (e, st) {
      throw Exception('❌ Google Sign-In failed: $e\n$st');
    }
  }

  /// 🔹 Logout (sign out from Firebase Auth)
  Future<void> logout() async {
    try {
      await _authService.signOut();
    } catch (e, st) {
      throw Exception('❌ Logout failed: $e\n$st');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 👤 USER DATA OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// 🔹 Fetch current user data safely
  Future<AppUser?> getCurrentUser() async {
    // 💡 FIX: Delegate the Firebase User check AND AppUser data fetch to the service.
    // This removes the need for two separate checks in the repository.
    try {
      // This method should handle: 1) Getting current Firebase User, 
      // 2) If exists, fetching AppUser data from Firestore.
      return await _authService
          .getAuthenticatedAppUser()
          .timeout(const Duration(seconds: 6), onTimeout: () => null);
    } catch (e, st) {
      throw Exception('❌ Fetch current user failed: $e\n$st');
    }
  }

  /// 🔹 Update user details in Firestore
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      // 💡 FIX: Delegate the Firestore update to the service layer.
      await _authService.updateAppUser(uid, data);
    } catch (e, st) {
      throw Exception('❌ Update user failed: $e\n$st');
    }
  }
}