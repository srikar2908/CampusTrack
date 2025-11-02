class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phoneNumber;
  final String role; // 'student', 'admin', 'office_admin'
  final String officeId; // Optional for office admins
  final String? fcmToken; // ✅ New: Optional token field

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.role,
    this.officeId = '',
    this.fcmToken,
  });

  /// Create AppUser from Firestore document
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      role: map['role'] ?? 'student',
      officeId: map['officeId'] ?? '',
      fcmToken: map['fcmToken'], // ✅ safely read it if present
    );
  }

  /// Convert AppUser to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role,
      'officeId': officeId,
      if (fcmToken != null) 'fcmToken': fcmToken, // ✅ only add if available
    };
  }

  /// Copy AppUser with updated fields
  AppUser copyWith({
    String? name,
    String? email,
    String? phoneNumber,
    String? role,
    String? officeId,
    String? fcmToken,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      officeId: officeId ?? this.officeId,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  /// Role checks
  bool get isStudent => role == 'student';
  bool get isAdmin => role == 'admin';
  bool get isOfficeAdmin => role == 'office_admin';
}
