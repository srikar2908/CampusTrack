import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart'; // ✨ FIX 1: ADD REQUIRED IMPORT

// Create a static Uuid generator instance
const _uuid = Uuid();

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'gs://campustracksahe.firebasestorage.app',
  );

  // ───────────────────────────────
  // 🔹 ITEM IMAGES
  // ───────────────────────────────

  Future<String> uploadItemImageBytes({
    required Uint8List bytes,
    required String itemId,
    required String fileName,
    required String contentType,
    Duration uploadTimeout = const Duration(seconds: 60),
    Duration urlTimeout = const Duration(seconds: 20),
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("User not authenticated");

    try {
      final ref = _storage.ref().child('items/$itemId/$fileName');
      final uploadTask = ref.putData(bytes, SettableMetadata(contentType: contentType));

      final snapshot = await uploadTask.timeout(uploadTimeout);
      return await snapshot.ref.getDownloadURL().timeout(urlTimeout);
    } on TimeoutException {
      throw Exception("⏱ Image upload timed out");
    } on FirebaseException catch (e) {
      throw Exception("🔥 Firebase Storage error: ${e.message}");
    } catch (e) {
      throw Exception("⚠ Unknown storage error: $e");
    }
  }

  String _detectContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  Future<String> uploadDetectedImage({
    required Uint8List bytes,
    required String itemId,
    required String originalFileName,
  }) async {
    final contentType = _detectContentType(originalFileName);
    final ext = originalFileName.split('.').last.toLowerCase();
    
    // ✨ FIX 2: Use the imported _uuid generator
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}.$ext'; 

    return uploadItemImageBytes(
      bytes: bytes,
      itemId: itemId,
      fileName: fileName,
      contentType: contentType,
    );
  }

  Future<List<String>> uploadMultipleItemImages({
    required List<Uint8List> imagesBytes,
    required List<String> originalFileNames,
    required String itemId,
  }) async {
    if (imagesBytes.length != originalFileNames.length) {
      throw Exception("Mismatch: imagesBytes and originalFileNames length must be equal");
    }

    final uploadFutures = <Future<String>>[];
    for (int i = 0; i < imagesBytes.length; i++) {
      uploadFutures.add(uploadDetectedImage(
        bytes: imagesBytes[i],
        itemId: itemId,
        originalFileName: originalFileNames[i],
      ));
    }
    
    return await Future.wait(uploadFutures);
  }

  // ✅ CORE METHOD FOR DELETION
  Future<void> deleteItemImages(String itemId) async {
    try {
      final folderRef = _storage.ref().child('items/$itemId');
      final listResult = await folderRef.listAll();

      final deleteFutures = <Future<void>>[];
      for (var itemRef in listResult.items) {
        deleteFutures.add(itemRef.delete());
      }
      await Future.wait(deleteFutures);
    } on FirebaseException catch (e) {
      throw Exception("🔥 Failed to delete item images: ${e.message}");
    } catch (e) {
      throw Exception("⚠ Unknown error deleting item images: $e");
    }
  }

  // ───────────────────────────────
  // 🔹 ID CARD IMAGE (RETURN VERIFICATION)
  // ───────────────────────────────

  Future<String> uploadIdCardImage({
    required Uint8List idImageBytes,
    required String requestId,
    String fileExtension = 'jpg',
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("User not authenticated");

    try {
      // ✨ FIX 3: Use the imported _uuid generator
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}.$fileExtension';
      final ref = _storage.ref().child('id_cards/$requestId/$fileName');

      final uploadTask = ref.putData(
        idImageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw Exception("🔥 Failed to upload ID card image: ${e.message}");
    } catch (e) {
      throw Exception("⚠ Unknown error uploading ID card: $e");
    }
  }

  Future<void> deleteIdCardImage(String requestId) async {
    try {
      final folderRef = _storage.ref().child('id_cards/$requestId');
      final listResult = await folderRef.listAll();

      final deleteFutures = <Future<void>>[];
      for (var fileRef in listResult.items) {
        deleteFutures.add(fileRef.delete());
      }
      await Future.wait(deleteFutures);
      
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        throw Exception("🔥 Failed to delete ID card: ${e.message}");
      }
    } catch (e) {
      throw Exception("⚠ Unknown error deleting ID card: $e");
    }
  }
}