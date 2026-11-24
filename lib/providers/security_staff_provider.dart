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
  bool _disposed = false;
  String? _aptId;
  bool _salariesEnabled = false;
  int _streamRetryCount = 0;
  static const int _maxStreamRetries = 5;
  // Retry delays: 2s, 5s, 10s, 20s, 30s
  static const List<int> _streamRetryDelays = [2, 5, 10, 20, 30];

  // ── Getters ────────────────────────────────────────────────────────────────

  /// All active staff (employmentStatus == 'active').
  List<SecurityStaffModel> get activeStaff =>
      _staff.where((s) => s.isActive).toList();

  /// All staff (active + inactive), useful for management screens.
  List<SecurityStaffModel> get allStaff => List.unmodifiable(_staff);

  /// staffId → salary. Populated after [loadSalaries] is called.
  Map<String, SecurityStaffSalary> get salaries => Map.unmodifiable(_salaries);

  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Stream lifecycle ───────────────────────────────────────────────────────

  /// Starts the real-time stream for the given apartment.
  /// Idempotent — calling multiple times with the same aptId is safe.
  /// Auto-retries on error with exponential backoff.
  void startListening(String aptId) {
    if (_started) return;
    _started = true;
    _aptId = aptId;
    _subscribeStream(aptId);
  }

  void _subscribeStream(String aptId) {
    _staffSub?.cancel();
    _staffSub = _service.streamSecurityStaff(aptId).listen(
      (list) {
        _streamRetryCount = 0; // reset on successful data
        _staff = list;
        _error = null;
        notifyListeners();
        // Auto-fetch salaries for any staff not yet cached
        if (_salariesEnabled) {
          for (final s in list) {
            if (!_salaries.containsKey(s.id)) {
              _fetchSalary(aptId, s.id);
            }
          }
        }
      },
      onError: (e) {
        _error = e.toString();
        debugPrint('[SecurityStaffProvider] stream error (retry $_streamRetryCount/$_maxStreamRetries): $e');
        notifyListeners();
        _scheduleStreamRetry(aptId);
      },
    );
  }

  void _scheduleStreamRetry(String aptId) {
    if (_streamRetryCount >= _maxStreamRetries) {
      debugPrint('[SecurityStaffProvider] max stream retries reached');
      return;
    }
    final delay = _streamRetryDelays[_streamRetryCount];
    _streamRetryCount++;
    debugPrint('[SecurityStaffProvider] retrying stream in ${delay}s (attempt $_streamRetryCount)');
    Future.delayed(Duration(seconds: delay), () {
      if (_disposed) return;
      _subscribeStream(aptId);
    });
  }

  /// Manual retry — called when the user taps "Retry" in the error UI.
  void retry() {
    final aptId = _aptId;
    if (aptId == null) return;
    _streamRetryCount = 0;
    _error = null;
    notifyListeners();
    _subscribeStream(aptId);
  }

  /// Enables salary loading and fetches salaries for all current staff.
  /// Call this for both president and resident roles after [startListening].
  Future<void> loadSalaries(String aptId) async {
    _salariesEnabled = true;
    _aptId = aptId;
    for (final staff in _staff) {
      if (!_salaries.containsKey(staff.id)) {
        await _fetchSalary(aptId, staff.id);
      }
    }
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
    _disposed = true;
    _staffSub?.cancel();
    super.dispose();
  }
}
