import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/services/firestore_service.dart';
import '../models/security_staff_model.dart';

/// Manages security staff for an apartment.
///
/// Call [startListening(aptId)] from DashboardRouter after login.
/// President additionally calls [loadSalaries(aptId)] to fetch private salary data.
class SecurityStaffProvider extends ChangeNotifier {
  final _service = FirestoreService();

  List<SecurityStaffModel> _staff = [];
  final Map<String, SecurityStaffSalary> _salaries = {};

  bool _isLoading = false;
  String? _error;

  StreamSubscription<List<SecurityStaffModel>>? _staffSub;
  bool _started = false;

  // ── Getters ────────────────────────────────────────────────────────────────

  /// All active staff (employmentStatus == 'active').
  List<SecurityStaffModel> get activeStaff =>
      _staff.where((s) => s.isActive).toList();

  /// All staff (active + inactive), useful for management screens.
  List<SecurityStaffModel> get allStaff => List.unmodifiable(_staff);

  /// staffId → salary, loaded by president only.
  Map<String, SecurityStaffSalary> get salaries => Map.unmodifiable(_salaries);

  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Stream lifecycle ───────────────────────────────────────────────────────

  /// Starts the real-time stream for the given apartment.
  /// Idempotent — calling multiple times with the same aptId is safe.
  void startListening(String aptId) {
    if (_started) return;
    _started = true;

    _staffSub = _service.streamSecurityStaff(aptId).listen(
      (list) {
        _staff = list;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  /// Fetches salary for every staff member in [aptId].
  /// Should only be called for the president role.
  Future<void> loadSalaries(String aptId) async {
    for (final staff in _staff) {
      await _fetchSalary(aptId, staff.id);
    }
    // Listen for new staff after the initial load.
    // We piggy-back on the stream — when _staff changes (via startListening)
    // we should re-fetch salaries for any newly added staff.
  }

  Future<void> _fetchSalary(String aptId, String staffId) async {
    try {
      final salary = await _service.getSecurityStaffSalary(aptId, staffId);
      if (salary != null) {
        _salaries[staffId] = salary;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[SecurityStaffProvider] salary fetch error for $staffId: $e');
    }
  }

  // ── Write operations ───────────────────────────────────────────────────────

  /// Creates a new staff member with public info and private salary.
  /// Returns null on success, an error message on failure.
  Future<String?> addStaff(
    SecurityStaffModel staff,
    int monthlySalaryPaise,
    String presidentId,
  ) async {
    _setLoading(true);
    try {
      final salary = SecurityStaffSalary(
        staffId:            staff.id,
        monthlySalaryPaise: monthlySalaryPaise,
        updatedAt:          DateTime.now(),
        updatedBy:          presidentId,
      );
      await _service.addSecurityStaff(staff, salary);
      // Cache salary immediately
      _salaries[staff.id] = salary;
      _setLoading(false);
      return null;
    } catch (e) {
      _setLoading(false);
      return e.toString();
    }
  }

  /// Updates an existing staff member's public info and optionally salary.
  /// Returns null on success, an error message on failure.
  Future<String?> updateStaff(
    SecurityStaffModel staff, {
    int? monthlySalaryPaise,
    required String presidentId,
  }) async {
    _setLoading(true);
    try {
      SecurityStaffSalary? salaryUpdate;
      if (monthlySalaryPaise != null) {
        salaryUpdate = SecurityStaffSalary(
          staffId:            staff.id,
          monthlySalaryPaise: monthlySalaryPaise,
          updatedAt:          DateTime.now(),
          updatedBy:          presidentId,
        );
      }
      await _service.updateSecurityStaff(staff, salary: salaryUpdate);
      if (salaryUpdate != null) {
        _salaries[staff.id] = salaryUpdate;
      }
      _setLoading(false);
      return null;
    } catch (e) {
      _setLoading(false);
      return e.toString();
    }
  }

  /// Soft-deletes a staff member by setting employmentStatus to 'inactive'.
  /// Returns null on success, an error message on failure.
  Future<String?> deactivateStaff(
    String staffId,
    String aptId,
    String presidentId,
  ) async {
    _setLoading(true);
    try {
      await _service.deactivateSecurityStaff(aptId, staffId, presidentId);
      _setLoading(false);
      return null;
    } catch (e) {
      _setLoading(false);
      return e.toString();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _staffSub?.cancel();
    super.dispose();
  }
}
