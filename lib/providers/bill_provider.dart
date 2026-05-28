import 'package:flutter/material.dart';
import '../models/bill_model.dart';
import '../models/user_model.dart';

class BillProvider extends ChangeNotifier {
  final List<BillModel> _bills = List.from(MockBillData.bills);
  final List<BillPayment> _payments = List.from(MockBillData.payments);
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  // ── Queries ───────────────────────────────────────────────────────────────

  List<BillModel> billsForApartment(String aptId) =>
      _bills.where((b) => b.apartmentId == aptId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<BillPayment> paymentsForBill(String billId) =>
      _payments.where((p) => p.billId == billId).toList();

  List<BillPayment> paymentsForUser(String userId) =>
      _payments.where((p) => p.userId == userId).toList();

  BillPayment? userPaymentForBill(String billId, String userId) {
    try {
      return _payments
          .firstWhere((p) => p.billId == billId && p.userId == userId);
    } catch (_) {
      return null;
    }
  }

  /// Bills visible to a specific user (flattened as user-facing view).
  List<_UserBillView> userBillViews(String userId) {
    final userPayments = paymentsForUser(userId);
    return userPayments.map((payment) {
      final bill = _bills.firstWhere((b) => b.id == payment.billId,
          orElse: () => throw StateError('Bill not found'));
      return _UserBillView(bill: bill, payment: payment);
    }).toList()
      ..sort((a, b) => b.bill.createdAt.compareTo(a.bill.createdAt));
  }

  double totalDueForUser(String userId) {
    return userBillViews(userId)
        .where((v) => !v.payment.isPaid)
        .fold(0, (s, v) => s + v.bill.perFlatShare);
  }

  double totalPaidForUser(String userId) {
    return userBillViews(userId)
        .where((v) => v.payment.isPaid)
        .fold(0, (s, v) => s + v.bill.perFlatShare);
  }

  // ── Apartment-level aggregates (for Admin dashboard) ──────────────────────

  double collectedForApartment(String aptId) {
    final bills = billsForApartment(aptId);
    double total = 0;
    for (final bill in bills) {
      final paid =
          paymentsForBill(bill.id).where((p) => p.isPaid).length;
      total += paid * bill.perFlatShare;
    }
    return total;
  }

  double pendingForApartment(String aptId) {
    final bills = billsForApartment(aptId);
    double total = 0;
    for (final bill in bills) {
      final unpaid =
          paymentsForBill(bill.id).where((p) => !p.isPaid).length;
      total += unpaid * bill.perFlatShare;
    }
    return total;
  }

  int paidFlatsForBill(String billId) =>
      paymentsForBill(billId).where((p) => p.isPaid).length;

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Admin marks a specific flat's payment as paid.
  Future<void> adminMarkPaid(String billId, String userId) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 700));

    final i = _payments
        .indexWhere((p) => p.billId == billId && p.userId == userId);
    if (i != -1) {
      _payments[i] = _payments[i].copyWith(
        status: BillStatus.paid,
        paidDate: DateTime.now(),
        transactionId: 'TXN${DateTime.now().millisecondsSinceEpoch}',
        adminVerified: true,
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  /// User self-reports payment (pending admin verification).
  Future<void> userReportPaid(String billId, String userId,
      {String? transactionId}) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 900));

    final i = _payments
        .indexWhere((p) => p.billId == billId && p.userId == userId);
    if (i != -1) {
      _payments[i] = _payments[i].copyWith(
        status: BillStatus.pending, // still pending until admin verifies
        transactionId: transactionId ??
            'SELF_${DateTime.now().millisecondsSinceEpoch}',
        adminVerified: false,
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Admin creates a new bill and auto-generates payment records for all residents.
  Future<void> createBill({
    required String apartmentId,
    required String adminId,
    required String title,
    required double totalAmount,
    required int totalFlats,
    required String category,
    required String month,
    required DateTime dueDate,
    required List<UserModel> residents,
  }) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 900));

    final billId = 'bill_${DateTime.now().millisecondsSinceEpoch}';
    final bill = BillModel(
      id: billId,
      apartmentId: apartmentId,
      createdByAdminId: adminId,
      title: title,
      totalAmount: totalAmount,
      totalFlats: totalFlats,
      category: category,
      month: month,
      dueDate: dueDate,
      createdAt: DateTime.now(),
    );

    _bills.insert(0, bill);

    // Auto-generate one BillPayment record per resident flat.
    for (final resident in residents) {
      _payments.add(BillPayment(
        id: '${billId}_${resident.id}',
        billId: billId,
        userId: resident.id,
        unitNumber: resident.unit,
        status: BillStatus.pending,
      ));
    }

    _isLoading = false;
    notifyListeners();
  }
}

/// Convenience wrapper for a user's view of a bill + their payment status.
class _UserBillView {
  final BillModel bill;
  final BillPayment payment;
  const _UserBillView({required this.bill, required this.payment});
}

// Public exposure so screens can use this type.
typedef UserBillView = _UserBillView;
