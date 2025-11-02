import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item_model.dart';

class ItemRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collectionName = 'items'; // Define collection name once

  /// 🆕 Add or update an item
  Future<void> addItem(ItemModel item) async {
    final docRef = item.id.isEmpty
        ? _db.collection(_collectionName).doc() // auto-generate new id
        : _db.collection(_collectionName).doc(item.id); // use existing id for update

    final newItem = item.copyWith(id: docRef.id);

    // Use set with the item map
    await docRef.set(newItem.toMap());
  }

  /// 🔁 Update item status and associated verification/return fields
  Future<void> updateItemStatus({
    required String itemId,
    required String status,
    String? verifiedBy,
    String? verifiedOfficeId,
    String? returnedRequestId,
    DateTime? returnedAt,
  }) async {
    final docRef = _db.collection(_collectionName).doc(itemId);
    final updateData = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(), // Always update timestamp on change
    };

    // --- Verification Fields ---
    if (verifiedBy != null) {
      updateData['verifiedBy'] = verifiedBy;
    }
    if (verifiedOfficeId != null) {
      updateData['verifiedOfficeId'] = verifiedOfficeId;
    }

    // Ensure we set verifiedAt only when status becomes 'verified' and it hasn't been set before.
    if (status == 'verified') {
        // Fetch existing data to check if verifiedAt exists (avoids overwriting)
        final docSnap = await docRef.get();
        if (docSnap.exists && docSnap.data()?['verifiedAt'] == null) {
            updateData['verifiedAt'] = FieldValue.serverTimestamp();
        }
    }
    
    // --- Return Fields (Simplified Logic) ---
    if (status == 'returned') {
      // If status is returned, record the request ID and the return timestamp
      if (returnedRequestId != null) {
          updateData['returnedRequestId'] = returnedRequestId;
      }
      // Use the provided returnedAt, or serverTimestamp if null
      updateData['returnedAt'] = returnedAt != null 
          ? Timestamp.fromDate(returnedAt) 
          : FieldValue.serverTimestamp(); 
    }

    // Explicitly remove returned fields if status changes from 'returned'
    if (status != 'returned') {
        updateData['returnedRequestId'] = FieldValue.delete();
        updateData['returnedAt'] = FieldValue.delete();
    }

    // Perform the update
    await docRef.update(updateData);
  }
  
  // 🔑 NEW METHOD: Delete an item document
  /// 🗑️ Delete an item
  Future<void> deleteItem(String itemId) async {
    try {
      await _db.collection(_collectionName).doc(itemId).delete();
    } catch (e) {
      // Re-throw the exception for the calling service/provider to handle
      throw Exception('❌ Failed to delete item $itemId: $e');
    }
  }

  /// 📥 Get all items
  Future<List<ItemModel>> getAllItems() async {
    final snapshot = await _db.collection(_collectionName).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      // Ensure 'id' is correctly added to the map before conversion
      return ItemModel.fromMap({'id': doc.id, ...data});
    }).toList();
  }

  /// 👤 Get items by user
  Future<List<ItemModel>> getItemsByUser(String uid) async {
    final snapshot = await _db
        .collection(_collectionName)
        .where('userId', isEqualTo: uid)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      // Ensure 'id' is correctly added to the map before conversion
      return ItemModel.fromMap({'id': doc.id, ...data});
    }).toList();
  }

  /// 📌 Get items by office (optional)
  Future<List<ItemModel>> getItemsByOffice(String officeId) async {
    final snapshot = await _db
        .collection(_collectionName)
        .where('officeId', isEqualTo: officeId)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      // Ensure 'id' is correctly added to the map before conversion
      return ItemModel.fromMap({'id': doc.id, ...data});
    }).toList();
  }
}