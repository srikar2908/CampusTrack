import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreHelper {
  static Future<void> updateDocument({
    required String collection,
    required String docId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .update(updates);
    } on FirebaseException catch (e) {
      throw Exception('Firebase error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update document: $e');
    }
  }
}
