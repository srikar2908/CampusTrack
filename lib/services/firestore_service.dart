// firestore_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
// Excel package for reports
import 'package:syncfusion_flutter_xlsio/xlsio.dart'; 
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; 

// Ensure these imports match your actual file paths
import '../models/item_model.dart';
import '../models/app_user.dart';
import 'storage_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService(); 

  // ───────────────────────────────
  // 🔹 USERS
  // ───────────────────────────────
  
  // No change needed: Used for initial sign-up
  Future<void> saveUser(AppUser user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toMap());
    } catch (e) {
      throw Exception('❌ Failed to save user: $e');
    }
  }

  // No change needed: Used to fetch AppUser by UID
  Future<AppUser?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.data()!);
    } catch (e) {
      throw Exception('❌ Failed to fetch user: $e');
    }
  }

  // No change needed: Used as a fallback for Google sign-in
  Future<AppUser?> getUserByEmail(String email) async {
    try {
      if (email.isEmpty) return null;
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      return AppUser.fromMap(query.docs.first.data());
    } catch (e) {
      throw Exception('❌ Failed to fetch user by email: $e');
    }
  }

  // ✅ CORRECTION: Changed from `update` to `set(data, merge: true)` 
  // to safely update fields like FCM tokens and handle cases where 
  // the document might not exist yet (though it usually should).
  // This method is the generic user update for all services.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('❌ Failed to update user: $e');
    }
  }

  // 🗑️ DELETION/MERGE: The logic for this method is now safely inside
  // the corrected `updateUser` above by using `SetOptions(merge: true)`.
  // Therefore, this method is no longer needed.
  // Future<void> updateUserFcmToken(String uid, String fcmToken) async { ... }


  // ───────────────────────────────
  // 🔹 ITEMS (No change needed here)
  // ───────────────────────────────
  
  DocumentReference<Map<String, dynamic>> createItemDocRef() {
    return _firestore.collection('items').doc();
  }

  Future<ItemModel> addItem(ItemModel item) async {
    try {
      final docRef = _firestore.collection('items').doc(
          item.id.isEmpty ? _firestore.collection('items').doc().id : item.id,
        );
      final now = DateTime.now();
      final itemToSave = item.copyWith(
        id: docRef.id,
        createdAt: now,
        dateTime: now,
        status: item.status.isNotEmpty ? item.status : 'pending',
      );
      await docRef.set(itemToSave.toMap());
      final saved = await docRef.get();
      return ItemModel.fromMap({'id': saved.id, ...saved.data()!});
    } catch (e) {
      throw Exception('❌ Failed to add item: $e');
    }
  }

  Future<void> updateItemStatus({
    required String itemId,
    required String status,
    String? verifiedBy,
    String? verifiedOfficeId,
    DateTime? returnedAt,
    String? returnedRequestId,
  }) async {
    try {
      final docRef = _firestore.collection('items').doc(itemId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) throw Exception('Item not found');

      final data = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (verifiedBy != null) data['verifiedBy'] = verifiedBy;
      if (verifiedOfficeId != null) data['verifiedOfficeId'] = verifiedOfficeId;

      if (status == 'verified' && docSnap.data()?['verifiedAt'] == null) {
        data['verifiedAt'] = FieldValue.serverTimestamp();
      }

      if (status == 'returned') {
        data['returnedAt'] =
            returnedAt != null ? Timestamp.fromDate(returnedAt) : FieldValue.serverTimestamp();
        if (returnedRequestId != null) data['returnedRequestId'] = returnedRequestId;
      }

      await docRef.update(data);
    } catch (e) {
      throw Exception('❌ Failed to update item status: $e');
    }
  }

  Future<List<ItemModel>> getAllItems() async {
    try {
      final snapshot =
          await _firestore.collection('items').orderBy('createdAt', descending: true).get();
      return snapshot.docs.map((doc) => ItemModel.fromMap({'id': doc.id, ...doc.data()})).toList();
    } catch (e) {
      throw Exception('❌ Failed to fetch items: $e');
    }
  }

  Future<List<ItemModel>> getItemsByUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('items')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => ItemModel.fromMap({'id': doc.id, ...doc.data()})).toList();
    } catch (e) {
      throw Exception('❌ Failed to fetch user items: $e');
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      // Deletes associated images before deleting the Firestore document
      await _storageService.deleteItemImages(itemId); 
      await _firestore.collection('items').doc(itemId).delete();
    } catch (e) {
      throw Exception('❌ Failed to delete item: $e');
    }
  }

  Stream<ItemModel> streamItem(String itemId) {
    return _firestore.collection('items').doc(itemId).snapshots().map((doc) {
      final data = doc.data() ?? {};
      return ItemModel.fromMap({'id': doc.id, ...data});
    });
  }

  Stream<List<ItemModel>> streamAllItems() {
    return _firestore
        .collection('items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ItemModel.fromMap({'id': doc.id, ...doc.data()})).toList());
  }

  // ───────────────────────────────
  // 🔹 COLLECTION REQUESTS (No change needed here)
  // ───────────────────────────────
  
  Future<String> addCollectionRequest({
    required String itemId,
    required String requesterId,
    required String verifiedOfficeId,
    String notes = '',
  }) async {
    try {
      final docRef = await _firestore.collection('collectionRequests').add({
        'itemId': itemId,
        'requesterId': requesterId,
        'verifiedOfficeId': verifiedOfficeId,
        'status': 'requested',
        'pickupTime': null,
        'notes': notes,
        'requestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('❌ Failed to add collection request: $e');
    }
  }

  Future<void> updateCollectionRequestStatus({
    required String requestId,
    required String status,
    DateTime? pickupTime,
    String? notes,
  }) async {
    try {
      final ref = _firestore.collection('collectionRequests').doc(requestId);
      final snap = await ref.get();
      if (!snap.exists) throw Exception('Request not found');

      final data = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (pickupTime != null) data['pickupTime'] = Timestamp.fromDate(pickupTime);
      if (notes != null) data['notes'] = notes;

      await ref.update(data);
    } catch (e) {
      throw Exception('❌ Failed to update collection request: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> streamRequestsForUser(String userId) {
    return _firestore
        .collection('collectionRequests')
        .where('requesterId', isEqualTo: userId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Stream<List<Map<String, dynamic>>> streamRequestsForOffice(String verifiedOfficeId) {
    return _firestore
        .collection('collectionRequests')
        .where('verifiedOfficeId', isEqualTo: verifiedOfficeId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<Map<String, dynamic>?> getLatestRequestByItemAndUser({
    required String itemId,
    required String requesterId,
  }) async {
    try {
      final snap = await _firestore
          .collection('collectionRequests')
          .where('itemId', isEqualTo: itemId)
          .where('requesterId', isEqualTo: requesterId)
          .orderBy('requestedAt', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return {'id': doc.id, ...doc.data()};
    } catch (e) {
      throw Exception('❌ Failed to fetch request: $e');
    }
  }

  // ───────────────────────────────
  // 🔹 ID CARD UPLOAD (RETURN VERIFICATION) (No change needed here)
  // ───────────────────────────────
  
  Future<void> markRequestAsReturnedWithId({
    required String requestId,
    required String itemId,
    required Uint8List idImageBytes,
  }) async {
    try {
      // 1. Upload ID card image via StorageService
      final idUrl = await _storageService.uploadIdCardImage(
        idImageBytes: idImageBytes,
        requestId: requestId,
      );

      // 2. Update collection request status and link to image
      await _firestore.collection('collectionRequests').doc(requestId).update({
        'status': 'returned',
        'idCardUrl': idUrl,
        'returnedAt': FieldValue.serverTimestamp(),
      });

      // 3. Update the associated item status
      await updateItemStatus(
        itemId: itemId,
        status: 'returned',
        returnedAt: DateTime.now(),
        returnedRequestId: requestId,
      );
    } catch (e) {
      throw Exception('❌ Failed to mark as returned with ID card: $e');
    }
  }

  // ───────────────────────────────
  // 🔹 EXCEL EXPORT (FIXED & OPTIMIZED with syncfusion_flutter_xlsio) (No change needed here)
  // ───────────────────────────────
  
  // Helper for safe timestamp formatting
  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      return ts.toDate().toLocal().toIso8601String().split('.')[0];
    }
    return '';
  }
  
  // Helper to populate a row using 1-based indexing for rows and columns
  void _populateRow(Worksheet sheet, int rowIndex, List<dynamic> data) {
    for (int colIndex = 0; colIndex < data.length; colIndex++) {
      final value = data[colIndex];
      final cell = sheet.getRangeByIndex(rowIndex, colIndex + 1); // RowIndex is 1-based
      
      if (value is num) {
        cell.setNumber(value.toDouble());
      } else {
        // All other types (String, bool, null) are converted to text
        cell.setText(value?.toString() ?? '');
      }
    }
  }

  /// 🔒 Private method to generate the Excel file locally using syncfusion_flutter_xlsio.
  Future<File?> _generateExcelFile() async {
    // 1. Create a new Excel workbook
    final Workbook workbook = Workbook();

    try {
      // 2. USERS SHEET
      final usersSheet = workbook.worksheets[0]; // First sheet is automatically created
      usersSheet.name = 'Users';
      int userRow = 1; // Start row index at 1 (1-based indexing)
      
      // Headers (Row 1)
      _populateRow(usersSheet, userRow++, ['UID', 'Name', 'Email', 'Role', 'Office ID', 'Phone', 'FCM Token']);
      
      final usersSnap = await _firestore.collection('users').get();
      for (var doc in usersSnap.docs) {
        final d = doc.data();
        _populateRow(usersSheet, userRow++, [
          d['uid'] ?? doc.id,
          d['name'] ?? '',
          d['email'] ?? '',
          d['role'] ?? '',
          d['officeId'] ?? '',
          d['phoneNumber'] ?? '',
          d['fcmToken'] ?? '',
        ]);
      }

      // 3. ITEMS SHEET
      final itemsSheet = workbook.worksheets.addWithName('Items');
      int itemRow = 1;

      // Headers (Row 1)
      _populateRow(itemsSheet, itemRow++, [
        'ID', 'Title', 'Description', 'Type', 'Status', 'Location', 'Office ID', 'User ID',
        'Verified By', 'Verified Office', 'Created At', 'Verified At', 'Returned At'
      ]);

      final itemsSnap = await _firestore.collection('items').get();
      for (var doc in itemsSnap.docs) {
        final d = doc.data();
        _populateRow(itemsSheet, itemRow++, [
          d['id'] ?? doc.id,
          d['title'] ?? '',
          d['description'] ?? '',
          d['type'] ?? '',
          d['status'] ?? '',
          d['location'] ?? '',
          d['officeId'] ?? '',
          d['userId'] ?? '',
          d['verifiedBy'] ?? '',
          d['verifiedOfficeId'] ?? '',
          _formatTimestamp(d['createdAt']),
          _formatTimestamp(d['verifiedAt']),
          _formatTimestamp(d['returnedAt']),
        ]);
      }

      // 4. COLLECTION REQUESTS SHEET
      final reqSheet = workbook.worksheets.addWithName('CollectionRequests');
      int reqRow = 1;

      // Headers (Row 1)
      _populateRow(reqSheet, reqRow++, [
        'Item ID', 'Requester ID', 'Verified Office ID', 'Status',
        'Pickup Time', 'Requested At', 'Returned At', 'Notes'
      ]);

      final reqSnap = await _firestore.collection('collectionRequests').get();
      for (var doc in reqSnap.docs) {
        final d = doc.data();
        _populateRow(reqSheet, reqRow++, [
          d['itemId'] ?? '',
          d['requesterId'] ?? '',
          d['verifiedOfficeId'] ?? '',
          d['status'] ?? '',
          _formatTimestamp(d['pickupTime']),
          _formatTimestamp(d['requestedAt']),
          _formatTimestamp(d['returnedAt']),
          d['notes'] ?? '',
        ]);
      }

      // 5. SAVE FILE LOCALLY
      final List<int> bytes = workbook.saveAsStream(); // Save to bytes
      
      if (bytes.isEmpty) throw Exception('Failed to encode Excel file: File bytes were empty.');

      final dir = await getTemporaryDirectory(); // Safest place for temporary file sharing
      final filePath = '${dir.path}/CampusTrack_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('Failed to create or save Excel file to disk.');
      }

      return file;
    } catch (e) {
      // Re-throw all specific errors for the UI to handle.
      throw Exception('Failed to generate Excel file: $e'); 
    } finally {
      // Ensure the workbook is disposed regardless of success or failure
      workbook.dispose(); 
    }
  }

  /// 📤 Public method to generate the report and trigger the native share dialog. (No change needed here)
  Future<void> exportAndShareExcel() async {
    File? file;
    try {
      file = await _generateExcelFile();
      
      if (file == null) {
          throw Exception('File creation failed for unknown reason.'); 
      }

      // Trigger native share dialog using share_plus
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '📊 CampusTrack Database Report',
        subject: 'CampusTrack Report - ${DateTime.now().year}',
      );

    } catch (e) {
      rethrow;
    } finally {
      // Ensure the temporary file is deleted after sharing or failure
      if (file != null && await file.exists()) {
        // Use try-catch to safely delete the file without crashing if it fails
        try {
          await file.delete();
        } catch (_) {
          // Ignore error during file deletion
        }
      }
    }
  }
}