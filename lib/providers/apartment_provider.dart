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

  /// Simulates assigning a president to an apartment.
  Future<void> assignPresident(String aptId, String adminUserId) async {
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
  Future<void> createApartment({
    required String name,
    required String address,
    required String city,
    required int totalFlats,
    List<String> amenities = const [],
  }) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 800));

    final newApt = ApartmentModel(
      id: 'apt_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      address: address,
      city: city,
      totalFlats: totalFlats,
      amenities: amenities,
      createdAt: DateTime.now(),
    );

    _apartments.add(newApt);
    MockApartments.add(newApt);

    _isLoading = false;
    notifyListeners();
  }
}
