import 'package:flutter/material.dart';
import '../models/bill_model.dart';
import '../models/user_model.dart';

// ── Monthly grouping data classes ─────────────────────────────────────────────

/// Admin view: all bills in a month grouped together with all payment records.
class MonthlyBillSummary {
  final String month;
  final String apartmentId;
  final List<BillModel> bills;
  final List<BillPayment> allPayments;
  final int totalFlats;

  const MonthlyBillSummary({
    required this.month,
    required this.apartmentId,
    required this.bills,
    required this.allPayments,
    required this.totalFlats,
  });

  double get totalAmount => bills.fold(0.0, (s, b) => s + b.totalAmount);
  double get perFlatShare => bills.fold(0.0, (s, b) => s + b.perFlatShare);

  DateTime get dueDate => bills.isEmpty
      ? DateTime.now()
      : bills.map((b) => b.dueDate).reduce((a, b) => a.isAfter(b) ? a : b);

  /// Number of flats that paid ALL bills in this month.
  int get fullyPaidFlats {
    if (bills.isEmpty || totalFlats == 0) return 0;
    final userIds = allPayments.map((p) => p.userId).toSet();
    return userIds.where((uid) {
      return bills.every((bill) {
        final matches = allPayments
            .where((x) => x.billId == bill.id && x.userId == uid)
            .toList();
        return matches.isNotEmpty && matches.first.isPaid;
      });
    }).length;
  }

  int get pendingFlats => totalFlats - fullyPaidFlats;

  String get overallStatus {
    if (totalFlats == 0) return BillStatus.pending;
    if (fullyPaidFlats == totalFlats) return BillStatus.paid;
    if (fullyPaidFlats == 0) return BillStatus.pending;
    return BillStatus.partiallyPaid;
  }

  bool isUserFullyPaid(String userId) {
    if (bills.isEmpty) return false;
    return bills.every((bill) {
      final matches = allPayments
          .where((x) => x.billId == bill.id && x.userId == userId)
          .toList();
      return matches.isNotEmpty && matches.first.isPaid;
    });
  }

  DateTime? userPaidDate(String userId) {
    if (!isUserFullyPaid(userId)) return null;
    final dates = allPayments
        .where((p) => p.userId == userId && p.isPaid && p.paidDate != null)
        .map((p) => p.paidDate!)
        .toList();
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Unique flats (userId → unitNumber) from payment records.
  List<({String userId, String unitNumber})> get flatList {
    final seen = <String>{};
    final result = <({String userId, String unitNumber})>[];
    for (final p in allPayments) {
      if (seen.add(p.userId)) {
        result.add((userId: p.userId, unitNumber: p.unitNumber));
      }
    }
    result.sort((a, b) => a.unitNumber.compareTo(b.unitNumber));
    return result;
  }
}

/// User view: all bills in a month from the user's perspective.
class UserMonthlySummary {
  final String month;
  final String userId;
  final List<UserBillView> views;

  const UserMonthlySummary({
    required this.month,
    required this.userId,
    required this.views,
  });

  double get totalAmount =>
      views.fold(0.0, (s, v) => s + v.bill.perFlatShare);

  bool get isFullyPaid =>
      views.isNotEmpty && views.every((v) => v.payment.isPaid);

  bool get isPartiallyPaid =>
      views.any((v) => v.payment.isPaid) && !isFullyPaid;

  String get status {
    if (isFullyPaid) return BillStatus.paid;
    if (isPartiallyPaid) return BillStatus.partiallyPaid;
    if (views.any((v) => v.payment.isOverdue)) return BillStatus.overdue;
    return BillStatus.pending;
  }

  DateTime get dueDate => views.isEmpty
      ? DateTime.now()
      : views
          .map((v) => v.bill.dueDate)
          .reduce((a, b) => a.isAfter(b) ? a : b);

  DateTime? get paidDate {
    if (!isFullyPaid) return null;
    final dates = views
        .where((v) => v.payment.paidDate != null)
        .map((v) => v.payment.paidDate!)
        .toList();
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isAfter(b) ? a : b);
  }
}

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

  // ── Monthly grouping ──────────────────────────────────────────────────────

  static DateTime _parseMonthYear(String month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final parts = month.split(' ');
    if (parts.length != 2) return DateTime(2000);
    final m = months.indexOf(parts[0]) + 1;
    final y = int.tryParse(parts[1]) ?? 2000;
    return DateTime(y, m < 1 ? 1 : m);
  }

  bool hasMonthlyBill(String aptId, String month) =>
      _bills.any((b) => b.apartmentId == aptId && b.month == month);

  List<MonthlyBillSummary> monthlyBillsForApartment(String aptId) {
    final bills = billsForApartment(aptId);
    final grouped = <String, List<BillModel>>{};
    for (final b in bills) {
      grouped.putIfAbsent(b.month, () => []).add(b);
    }
    final summaries = grouped.entries.map((e) {
      final monthPayments =
          e.value.expand((b) => paymentsForBill(b.id)).toList();
      return MonthlyBillSummary(
        month: e.key,
        apartmentId: aptId,
        bills: e.value,
        allPayments: monthPayments,
        totalFlats: e.value.isEmpty ? 0 : e.value.first.totalFlats,
      );
    }).toList();
    summaries.sort((a, b) =>
        _parseMonthYear(b.month).compareTo(_parseMonthYear(a.month)));
    return summaries;
  }

  List<UserMonthlySummary> userMonthlySummaries(String userId) {
    final views = userBillViews(userId);
    final grouped = <String, List<UserBillView>>{};
    for (final v in views) {
      grouped.putIfAbsent(v.bill.month, () => []).add(v);
    }
    final summaries = grouped.entries
        .map((e) => UserMonthlySummary(
              month: e.key,
              userId: userId,
              views: e.value,
            ))
        .toList();
    summaries.sort((a, b) =>
        _parseMonthYear(b.month).compareTo(_parseMonthYear(a.month)));
    return summaries;
  }

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

  /// Admin creates a monthly bill with multiple category line items.
  Future<void> createMonthlyBill({
    required String apartmentId,
    required String adminId,
    required String month,
    required DateTime dueDate,
    required List<({String title, String category, double amount})> lineItems,
    required int totalFlats,
    required List<UserModel> residents,
  }) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 900));

    for (int i = 0; i < lineItems.length; i++) {
      final item = lineItems[i];
      final billId =
          'bill_${DateTime.now().millisecondsSinceEpoch}_${item.category}_$i';
      final bill = BillModel(
        id: billId,
        apartmentId: apartmentId,
        createdByAdminId: adminId,
        title: item.title,
        totalAmount: item.amount,
        totalFlats: totalFlats,
        category: item.category,
        month: month,
        dueDate: dueDate,
        createdAt: DateTime.now(),
      );
      _bills.insert(0, bill);
      for (final resident in residents) {
        _payments.add(BillPayment(
          id: '${billId}_${resident.id}',
          billId: billId,
          userId: resident.id,
          unitNumber: resident.unit,
          status: BillStatus.pending,
        ));
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Admin marks all unpaid bills in a month as paid for a specific flat.
  Future<void> adminMarkMonthPaid(
      String month, String aptId, String userId) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 700));

    final monthBills = _bills
        .where((b) => b.apartmentId == aptId && b.month == month)
        .toList();
    for (final bill in monthBills) {
      final i =
          _payments.indexWhere((p) => p.billId == bill.id && p.userId == userId);
      if (i != -1 && !_payments[i].isPaid) {
        _payments[i] = _payments[i].copyWith(
          status: BillStatus.paid,
          paidDate: DateTime.now(),
          transactionId: 'TXN${DateTime.now().millisecondsSinceEpoch}',
          adminVerified: true,
        );
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// User pays all bills in a month (instant payment for mock).
  Future<void> userPayMonthlyBill(
      String month, String aptId, String userId) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 900));

    final monthBills = _bills
        .where((b) => b.apartmentId == aptId && b.month == month)
        .toList();
    for (final bill in monthBills) {
      final i =
          _payments.indexWhere((p) => p.billId == bill.id && p.userId == userId);
      if (i != -1 && !_payments[i].isPaid) {
        _payments[i] = _payments[i].copyWith(
          status: BillStatus.paid,
          paidDate: DateTime.now(),
          transactionId: 'PAY${DateTime.now().millisecondsSinceEpoch}',
          adminVerified: false,
        );
      }
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
