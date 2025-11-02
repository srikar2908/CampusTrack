class AppConstants {
  // Roles
  static const String userRole = 'user'; // Students & Staff
  static const String officeAdminRole = 'office_admin';

  // Item Status
  static const String pendingStatus = 'pending';
  static const String verifiedStatus = 'verified';
  static const String returnedStatus = 'returned';
  static const String rejectedStatus = 'rejected';

  // Item Type
  static const String lostType = 'lost';
  static const String foundType = 'found';
  static const String allType = 'all'; // For feed filtering

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String itemsCollection = 'items';
  static const String officesCollection = 'offices';
  static const String collectionRequestsCollection = 'collection_requests';



  // Firebase Fields
  static const String userIdField = 'userId';
  static const String officeIdField = 'officeId';
  static const String verifiedByField = 'verifiedBy';
  static const String verifiedOfficeIdField = 'verifiedOfficeId';
  static const String officeNameField = 'officeName';
  static const String imagePathField = 'imagePath';
  static const String dateTimeField = 'dateTime';
}
