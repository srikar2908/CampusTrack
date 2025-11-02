class Validators {
  /// Validate name: cannot be empty and must be at least 2 characters
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name cannot be empty';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  /// Validate email format
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email cannot be empty';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  /// Validate password length
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password cannot be empty';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  /// Validate generic not empty field
  static String? validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName cannot be empty';
    return null;
  }

  /// Validate 10-digit phone number
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Phone cannot be empty';
    if (!RegExp(r'^\d{10}$').hasMatch(value)) return 'Enter a valid 10-digit phone number';
    return null;
  }
}
