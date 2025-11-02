class RoleHelper {
  static const String student = 'student';
  static const String staff = 'staff';
  static const String admin = 'office_admin';

  /// Check if role is student
  static bool isStudent(String? role) {
    if (role == null) return false;
    return role.toLowerCase() == student;
  }

  /// Check if role is staff
  static bool isStaff(String? role) {
    if (role == null) return false;
    return role.toLowerCase() == staff;
  }

  /// Check if role is admin
  static bool isAdmin(String? role) {
    if (role == null) return false;
    return role.toLowerCase() == admin;
  }

  /// Get a friendly display label for UI
  static String getRoleLabel(String? role) {
    if (role == null) return 'Unknown';
    switch (role.toLowerCase()) {
      case student:
        return 'Student';
      case staff:
        return 'Staff';
      case admin:
        return 'Admin';
      default:
        return 'Unknown';
    }
  }
}
