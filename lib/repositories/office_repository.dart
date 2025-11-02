import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_constants.dart';
import '../models/office_model.dart';

class OfficeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<OfficeModel>> getOffices() async {
    final snapshot = await _firestore.collection(AppConstants.officesCollection).get();
    return snapshot.docs.map((doc) => OfficeModel.fromMap(doc.data())).toList();
  }

  Future<void> addOffice(OfficeModel office) async {
    await _firestore.collection(AppConstants.officesCollection).doc(office.id).set(office.toMap());
  }
}
