import 'package:flutter/foundation.dart';
import '../models/office_model.dart';
import '../repositories/office_repository.dart';

class OfficeProvider with ChangeNotifier {
  final OfficeRepository _repository = OfficeRepository();

  List<OfficeModel> _offices = [];
  bool _isLoading = false;
  String? _error;

  List<OfficeModel> get offices => _offices;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchOffices() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _offices = await _repository.getOffices();
    } catch (e) {
      if (kDebugMode) print('Error fetching offices: $e');
      _offices = [];
      _error = 'Failed to fetch offices';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addOffice(OfficeModel office) async {
    try {
      await _repository.addOffice(office);
      await fetchOffices();
    } catch (e) {
      if (kDebugMode) print('Error adding office: $e');
      _error = 'Failed to add office';
      notifyListeners();
    }
  }
}
