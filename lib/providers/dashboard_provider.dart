import 'package:flutter/material.dart';
import '../core/theme/role_theme.dart';
import '../models/apartment_model.dart';
import '../models/user_model.dart';
import '../models/bill_model.dart';

class DashboardProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _initialized = false;

  bool get isLoading => _isLoading;
  bool get initialized => _initialized;

  // ── Global stats (Super Admin) ────────────────────────────────────────────

  int get totalApartments => MockApartments.all.length;
  int get totalResidents =>
      MockUsers.all.where((u) => u.role == UserRole.user).length;
  int get totalAdmins =>
      MockUsers.all.where((u) => u.role == UserRole.admin).length;

  int get totalBills => MockBillData.bills.length;

  int get paidBills => MockBillData.bills.where((bill) {
        final payments = MockBillData.paymentsForBill(bill.id);
        return payments.isNotEmpty && payments.every((p) => p.isPaid);
      }).length;

  int get pendingBills => MockBillData.bills.where((bill) {
        final payments = MockBillData.paymentsForBill(bill.id);
        if (payments.isEmpty) return true;
        return !payments.every((p) => p.isPaid) &&
            !payments.any((p) => p.isOverdue);
      }).length;

  int get overdueBills => MockBillData.bills.where((bill) {
        final payments = MockBillData.paymentsForBill(bill.id);
        return payments.any((p) => p.isOverdue);
      }).length;

  double get totalRevenue {
    double total = 0;
    for (final bill in MockBillData.bills) {
      final paid =
          MockBillData.paymentsForBill(bill.id).where((p) => p.isPaid).length;
      total += paid * bill.perFlatShare;
    }
    return total;
  }

  double get pendingRevenue {
    double total = 0;
    for (final bill in MockBillData.bills) {
      final unpaid =
          MockBillData.paymentsForBill(bill.id).where((p) => !p.isPaid).length;
      total += unpaid * bill.perFlatShare;
    }
    return total;
  }

  // ── Per-apartment stats (Admin) ───────────────────────────────────────────

  Map<String, dynamic> adminStats(String aptId) {
    final bills = MockBillData.billsForApartment(aptId);
    final residents = MockUsers.residentsForApartment(aptId);
    double collected = 0;
    double pending = 0;
    int paidPayments = 0;
    int totalPayments = 0;
    int paidBillsCount = 0;
    int pendingBillsCount = 0;
    int overdueBillsCount = 0;

    for (final bill in bills) {
      final payments = MockBillData.paymentsForBill(bill.id);
      final allPaid = payments.isNotEmpty && payments.every((p) => p.isPaid);
      final anyOverdue = payments.any((p) => p.isOverdue);

      if (allPaid) {
        paidBillsCount++;
      } else if (anyOverdue) {
        overdueBillsCount++;
      } else {
        pendingBillsCount++;
      }

      for (final p in payments) {
        totalPayments++;
        if (p.isPaid) {
          paidPayments++;
          collected += bill.perFlatShare;
        } else {
          pending += bill.perFlatShare;
        }
      }
    }

    return {
      'totalResidents': residents.length,
      'totalBills': bills.length,
      'collected': collected,
      'pending': pending,
      'paidPayments': paidPayments,
      'totalPayments': totalPayments,
      'collectionRate': totalPayments == 0 ? 0.0 : paidPayments / totalPayments,
      'paidBills': paidBillsCount,
      'pendingBills': pendingBillsCount,
      'overdueBills': overdueBillsCount,
    };
  }

  double collectionRate(String aptId) {
    final stats = adminStats(aptId);
    return stats['collectionRate'] as double;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 1200));
    _initialized = true;
    _isLoading = false;
    notifyListeners();
  }

  void refresh() {
    _initialized = false;
    initialize();
  }
}
