import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bill_model.dart';
import '../models/user_model.dart';
import '../core/services/firestore_service.dart';

// ── Monthly grouping data classes (unchanged — UI depends on these) ───────────

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

// ── BillProvider ──────────────────────────────────────────────────────────────

class BillProvider extends ChangeNotifier {
  final FirestoreService _fs = FirestoreService();

  List<BillModel> _bills = List.from(MockBillData.bills);
  List<BillPayment> _payments = List.from(MockBillData.payments);
  StreamSubscription<List<BillModel>>? _billSub;
  StreamSubscription<List<BillPayment>>? _paymentSub;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  // ── Stream management ─────────────────────────────────────────────────────

  /// Subscribe to bills and payments for [aptId]. Call after login.
  void startListeningForApartment(String aptId) {
    _billSub?.cancel();
    _paymentSub?.cancel();

    _billSub = _fs.streamBillsForApartment(aptId).listen((bills) {
      _bills = bills;
      MockBillData.replaceAll(_bills, _payments);
      notifyListeners();
    }, onError: (_) {});

    _paymentSub =
        _fs.streamPaymentsForApartment(aptId).listen((payments) {
      _payments = payments;
      MockBillData.replaceAll(_bills, _payments);
      notifyListeners();
    }, onError: (_) {});
  }

  /// For super admin: listen to ALL bills across all apartments.
  void startListeningAll() {
    _billSub?.cancel();
    _billSub = _fs.streamAllBills().listen((bills) {
      _bills = bills;
      MockBillData.replaceAll(_bills, _payments);
      notifyListeners();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _billSub?.cancel();
    _paymentSub?.cancel();
    super.dispose();
  }

  // ── Queries (identical signatures to original) ────────────────────────────

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

  List<UserBillView> userBillViews(String userId) {
    final userPayments = paymentsForUser(userId);
    final result = <UserBillView>[];
    for (final payment in userPayments) {
      try {
        final bill = _bills.firstWhere((b) => b.id == payment.billId);
        result.add(_UserBillView(bill: bill, payment: payment));
      } catch (_) {}
    }
    result.sort((a, b) => b.bill.createdAt.compareTo(a.bill.createdAt));
    return result;
  }

  double totalDueForUser(String userId) => userBillViews(userId)
      .where((v) => !v.payment.isPaid)
      .fold(0, (s, v) => s + v.bill.perFlatShare);

  double totalPaidForUser(String userId) => userBillViews(userId)
      .where((v) => v.payment.isPaid)
      .fold(0, (s, v) => s + v.bill.perFlatShare);

  double collectedForApartment(String aptId) {
    double total = 0;
    for (final bill in billsForApartment(aptId)) {
      final paid = paymentsForBill(bill.id).where((p) => p.isPaid).length;
      total += paid * bill.perFlatShare;
    }
    return total;
  }

  double pendingForApartment(String aptId) {
    double total = 0;
    for (final bill in billsForApartment(aptId)) {
      final unpaid =
          paymentsForBill(bill.id).where((p) => !p.isPaid).length;
      total += unpaid * bill.perFlatShare;
    }
    return total;
  }

  int paidFlatsForBill(String billId) =>
      paymentsForBill(billId).where((p) => p.isPaid).length;

  bool hasMonthlyBill(String aptId, String month) =>
      _bills.any((b) => b.apartmentId == aptId && b.month == month);

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

  Future<void> adminMarkPaid(String billId, String userId) async {
    _isLoading = true;
    notifyListeners();

    final paymentId = '${billId}_$userId';
    final now = DateTime.now();
    final txnId = 'TXN${now.millisecondsSinceEpoch}';

    await _fs.updatePayment(paymentId, {
      'status': BillStatus.paid,
      'paidDate': Timestamp.fromDate(now),
      'transactionId': txnId,
      'adminVerified': true,
    });

    // Optimistic local update
    final i =
        _payments.indexWhere((p) => p.billId == billId && p.userId == userId);
    if (i != -1) {
      _payments[i] = _payments[i].copyWith(
        status: BillStatus.paid,
        paidDate: now,
        transactionId: txnId,
        adminVerified: true,
      );
    }
    MockBillData.replaceAll(_bills, _payments);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> userReportPaid(String billId, String userId,
      {String? transactionId}) async {
    _isLoading = true;
    notifyListeners();

    final paymentId = '${billId}_$userId';
    final txnId =
        transactionId ?? 'SELF_${DateTime.now().millisecondsSinceEpoch}';

    await _fs.updatePayment(paymentId, {
      'transactionId': txnId,
      'adminVerified': false,
    });

    final i =
        _payments.indexWhere((p) => p.billId == billId && p.userId == userId);
    if (i != -1) {
      _payments[i] = _payments[i].copyWith(
        transactionId: txnId,
        adminVerified: false,
      );
    }
    MockBillData.replaceAll(_bills, _payments);
    _isLoading = false;
    notifyListeners();
  }

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

    final now = DateTime.now();
    for (int i = 0; i < lineItems.length; i++) {
      final item = lineItems[i];
      final billId =
          'bill_${now.millisecondsSinceEpoch}_${item.category}_$i';

      final billData = {
        'apartmentId': apartmentId,
        'createdByAdminId': adminId,
        'title': item.title,
        'totalAmount': item.amount,
        'totalFlats': totalFlats,
        'category': item.category,
        'month': month,
        'dueDate': Timestamp.fromDate(dueDate),
        'createdAt': Timestamp.fromDate(now),
      };
      await _fs.setBill(billId, billData);

      for (final resident in residents) {
        final paymentId = '${billId}_${resident.id}';
        await _fs.setPayment(paymentId, {
          'billId': billId,
          'userId': resident.id,
          'unitNumber': resident.unit,
          'status': BillStatus.pending,
          'paidDate': null,
          'transactionId': null,
          'adminVerified': false,
          'apartmentId': apartmentId,
        });
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> adminMarkMonthPaid(
      String month, String aptId, String userId) async {
    _isLoading = true;
    notifyListeners();

    final monthBills = _bills
        .where((b) => b.apartmentId == aptId && b.month == month)
        .toList();

    for (final bill in monthBills) {
      final paymentId = '${bill.id}_$userId';
      final payment = userPaymentForBill(bill.id, userId);
      if (payment != null && !payment.isPaid) {
        final now = DateTime.now();
        final txn = 'TXN${now.millisecondsSinceEpoch}';
        await _fs.updatePayment(paymentId, {
          'status': BillStatus.paid,
          'paidDate': Timestamp.fromDate(now),
          'transactionId': txn,
          'adminVerified': true,
        });
        final idx = _payments
            .indexWhere((p) => p.billId == bill.id && p.userId == userId);
        if (idx != -1) {
          _payments[idx] = _payments[idx].copyWith(
            status: BillStatus.paid,
            paidDate: now,
            transactionId: txn,
            adminVerified: true,
          );
        }
      }
    }
    MockBillData.replaceAll(_bills, _payments);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> userPayMonthlyBill(
      String month, String aptId, String userId) async {
    _isLoading = true;
    notifyListeners();

    final monthBills = _bills
        .where((b) => b.apartmentId == aptId && b.month == month)
        .toList();

    for (final bill in monthBills) {
      final payment = userPaymentForBill(bill.id, userId);
      if (payment != null && !payment.isPaid) {
        final paymentId = '${bill.id}_$userId';
        final now = DateTime.now();
        final txn = 'PAY${now.millisecondsSinceEpoch}';
        await _fs.updatePayment(paymentId, {
          'status': BillStatus.paid,
          'paidDate': Timestamp.fromDate(now),
          'transactionId': txn,
          'adminVerified': false,
        });
        final idx = _payments
            .indexWhere((p) => p.billId == bill.id && p.userId == userId);
        if (idx != -1) {
          _payments[idx] = _payments[idx].copyWith(
            status: BillStatus.paid,
            paidDate: now,
            transactionId: txn,
            adminVerified: false,
          );
        }
      }
    }
    MockBillData.replaceAll(_bills, _payments);
    _isLoading = false;
    notifyListeners();
  }
}

/// Convenience wrapper — unchanged public typedef.
class _UserBillView {
  final BillModel bill;
  final BillPayment payment;
  const _UserBillView({required this.bill, required this.payment});
}

typedef UserBillView = _UserBillView;
