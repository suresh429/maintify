import 'package:flutter/material.dart';
import '../models/apartment_model.dart';
import '../models/user_model.dart';

class ApartmentProvider extends ChangeNotifier {
  List<ApartmentModel> _apartments = List.from(MockApartments.all);
  bool _isLoading = false;

  List<ApartmentModel> get apartments => _apartments;
  bool get isLoading => _isLoading;

  ApartmentModel? findById(String id) {
    try {
      return _apartments.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Resolves the president's display name for an apartment.
  String presidentName(ApartmentModel apt) {
    if (!apt.hasPresident) return 'Unassigned';
    return MockUsers.findById(apt.presidentId!)?.name ?? 'Unassigned';
  }

  List<ApartmentModel> get withPresident =>
      _apartments.where((a) => a.hasPresident).toList();

  List<ApartmentModel> get withoutPresident =>
      _apartments.where((a) => !a.hasPresident).toList();

  /// Returns the current presidentId for an apartment, or null.
  String? currentPresidentId(String aptId) => findById(aptId)?.presidentId;

  /// Returns true if [userId] is already a president of any apartment other than [aptId].
  bool isPresidentElsewhere(String userId, {String? excludingAptId}) {
    return _apartments.any((a) =>
        a.presidentId == userId &&
        (excludingAptId == null || a.id != excludingAptId));
  }

  /// Assigns [adminUserId] as president of [aptId].
  /// Throws [StateError] if the user is already president of another apartment.
  Future<void> assignPresident(String aptId, String adminUserId) async {
    if (isPresidentElsewhere(adminUserId, excludingAptId: aptId)) {
      throw StateError('User is already president of another apartment');
    }

    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 700));

    final i = _apartments.indexWhere((a) => a.id == aptId);
    if (i != -1) {
      _apartments[i] = _apartments[i].copyWith(presidentId: adminUserId);
      // Sync to static mock so other providers reading MockApartments stay consistent.
      MockApartments.assignPresident(aptId, adminUserId);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Simulates creating a new apartment.
  /// [id] can be pre-generated so the admin user can be linked before calling this.
  /// [presidentId] sets the initial president on creation.
  Future<void> createApartment({
    String? id,
    required String name,
    required String address,
    required String city,
    required int totalFlats,
    List<String> amenities = const [],
    String? presidentId,
  }) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 800));

    final newApt = ApartmentModel(
      id: id ?? 'apt_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      address: address,
      city: city,
      totalFlats: totalFlats,
      presidentId: presidentId,
      amenities: amenities,
      createdAt: DateTime.now(),
    );

    _apartments.add(newApt);
    MockApartments.add(newApt);

    _isLoading = false;
    notifyListeners();
  }
}
