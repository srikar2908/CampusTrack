class AppUser {
  final String uid;
  final String email;
  final String phoneNumber;
  final String role;
  final String officeId; // Added for office admins

  AppUser({
    required this.uid,
    required this.email,
    required this.phoneNumber,
    required this.role,
    this.officeId = '',
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      role: map['role'] ?? '',
      officeId: map['officeId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role,
      'officeId': officeId,
    };
  }
}
