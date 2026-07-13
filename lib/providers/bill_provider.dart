import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bill_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../core/services/firestore_service.dart';
import 'notification_provider.dart';

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

  /// All excluded user IDs across all bills in this month.
  Set<String> get allExcludedUserIds =>
      bills.expand((b) => b.excludedUserIds).toSet();

  /// Eligible flats = total - excluded.
  int get eligibleFlats {
    final n = totalFlats - allExcludedUserIds.length;
    return n > 0 ? n : totalFlats;
  }

  int get pendingFlats => eligibleFlats - fullyPaidFlats;

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

  // Uses precomputed per-category amount when available, else payment.amount
  // or bill.perFlatShare for legacy bills.
  double get totalAmount =>
      views.fold(0.0, (s, v) => s + v.userAmount);

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

  // Start empty — server is the only source of truth.
  // Mock data is intentionally not used here; it only exists for DashboardProvider.
  List<BillModel> _bills = [];
  List<BillPayment> _payments = [];
  StreamSubscription<List<BillModel>>? _billSub;
  StreamSubscription<List<BillPayment>>? _paymentSub;

  // True from the moment startListening* is called until the first
  // server snapshot arrives. Drives shimmer loading in screens.
  bool _isInitialLoading = false;
  // True only during write mutations (createBill, markPaid, etc.).
  bool _isLoading = false;

  // Independent per-stream flags so _isInitialLoading is cleared only once
  // both streams have responded (data or error). Avoids depending on ordering.
  bool _billsLoaded = false;
  bool _paymentsLoaded = false;

  bool get isInitialLoading => _isInitialLoading;
  bool get isLoading => _isLoading;

  // Clears _isInitialLoading once both streams have fired at least once.
  // Does NOT call notifyListeners — callers do that immediately after.
  void _checkInitialLoadDone() {
    if (_billsLoaded && _paymentsLoaded) {
      _isInitialLoading = false;
    }
  }

  // ── Stream management ─────────────────────────────────────────────────────

  /// Subscribe to bills and payments for [aptId]. Call after login.
  ///
  /// Pass [userId] for the `user` role — payments are then scoped to that
  /// user's own records only (`streamPaymentsForUser`), which is both faster
  /// and avoids loading every resident's payment data unnecessarily.
  /// Omit [userId] (admin role) to load all apartment payments.
  ///
  /// Performs a hard reset first — never shows stale data from a previous session.
  /// Both streams run independently; _isInitialLoading clears once each has
  /// fired at least once (data or error), so ordering never matters.
  void startListeningForApartment(String aptId, {String? userId}) {
    _billSub?.cancel();
    _paymentSub?.cancel();

    // Hard reset: clear local lists, flags, and mock statics before any data arrives.
    _bills = [];
    _payments = [];
    _billsLoaded = false;
    _paymentsLoaded = false;
    _isInitialLoading = true;
    MockBillData.replaceAll([], []);
    notifyListeners();

    // ── Bills stream ──────────────────────────────────────────────────────────
    _billSub = _fs.streamBillsForApartment(aptId).listen((bills) {
      debugPrint('[REALTIME] Bills updated: ${bills.length} doc(s) for apt $aptId');
      _bills = bills;
      _billsLoaded = true;
      MockBillData.replaceAll(_bills, _payments);
      _checkInitialLoadDone();
      notifyListeners();
    }, onError: (e) {
      // Almost always a missing Firestore composite index.
      // Fix: firebase deploy --only firestore:indexes
      debugPrint('[REALTIME] Bills stream ERROR (apt $aptId): $e');
      _billsLoaded = true; // treat error as "responded" so shimmer can clear
      _checkInitialLoadDone();
      notifyListeners();
    });

    // ── Payments stream ───────────────────────────────────────────────────────
    // User role: stream only this user's own payment docs.
    // Admin role (userId == null): stream all apartment payments.
    final paymentStream = userId != null
        ? _fs.streamPaymentsForUser(userId)
        : _fs.streamPaymentsForApartment(aptId);

    _paymentSub = paymentStream.listen((payments) {
      debugPrint('[REALTIME] Payments updated: ${payments.length} doc(s)'
          '${userId != null ? " for user $userId" : " for apt $aptId"}');
      _payments = payments;
      _paymentsLoaded = true;
      MockBillData.replaceAll(_bills, _payments);
      _checkInitialLoadDone();
      notifyListeners();
    }, onError: (e) {
      debugPrint('[REALTIME] Payments stream ERROR: $e');
      _paymentsLoaded = true; // treat error as "responded" so shimmer can clear
      _checkInitialLoadDone();
      notifyListeners();
    });
  }

  /// For super admin: listen to ALL bills across all apartments.
  void startListeningAll() {
    _billSub?.cancel();

    _bills = [];
    _payments = [];
    _isInitialLoading = true;
    MockBillData.replaceAll([], []);
    notifyListeners();

    _billSub = _fs.streamAllBills().listen((bills) {
      debugPrint('[REALTIME] All-bills updated: ${bills.length} doc(s)');
      _bills = bills;
      _isInitialLoading = false;
      MockBillData.replaceAll(_bills, _payments);
      notifyListeners();
    }, onError: (e) {
      debugPrint('[REALTIME] All-bills stream ERROR: $e');
      _isInitialLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _billSub?.cancel();
    _paymentSub?.cancel();
    super.dispose();
  }

  // ── Queries ────────────────────────────────────────────────────────────────

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

  /// Expands a multi-category bill into one synthetic BillModel per category.
  /// All synthetic bills share the same [id] so payment lookups remain correct.
  /// Legacy bills (no categories) are returned as-is in a single-element list.
  List<BillModel> _expandBillToSyntheticList(BillModel bill) {
    if (bill.categories.isEmpty) return [bill];
    return bill.categories
        .map((cat) => BillModel(
              id: bill.id,
              apartmentId: bill.apartmentId,
              createdByAdminId: bill.createdByAdminId,
              title: cat.name,
              totalAmount: cat.totalAmount,
              totalFlats: bill.totalFlats,
              category: cat.type,
              month: bill.month,
              dueDate: bill.dueDate,
              createdAt: bill.createdAt,
              billType: cat.type,
              categories: const [],
              excludedUserIds: bill.excludedUserIds,
            ))
        .toList();
  }

  /// Returns one [UserBillView] per billing line-item (category) the user owes.
  /// Multi-category bills are expanded into N synthetic views sharing one payment.
  List<UserBillView> userBillViews(String userId) {
    final userPayments = paymentsForUser(userId);
    final result = <UserBillView>[];
    for (final payment in userPayments) {
      try {
        final bill = _bills.firstWhere((b) => b.id == payment.billId);
        if (bill.categories.isNotEmpty) {
          for (final cat in bill.categories) {
            final synthetic = BillModel(
              id: bill.id,
              apartmentId: bill.apartmentId,
              createdByAdminId: bill.createdByAdminId,
              title: cat.name,
              totalAmount: cat.totalAmount,
              totalFlats: bill.totalFlats,
              category: cat.type,
              month: bill.month,
              dueDate: bill.dueDate,
              createdAt: bill.createdAt,
              billType: cat.type,
              categories: const [],
              excludedUserIds: bill.excludedUserIds,
            );
            result.add(_UserBillView(
              bill: synthetic,
              payment: payment,
              precomputedAmount: bill.excludedUserIds.contains(userId)
                  ? 0
                  : cat.amountForUser(userId, bill.eligibleCount),
            ));
          }
        } else {
          result.add(_UserBillView(bill: bill, payment: payment));
        }
      } catch (_) {
        debugPrint('[REALTIME] userBillViews: payment ${payment.billId} has no matching bill in cache (${_bills.length} bills loaded)');
      }
    }
    result.sort((a, b) => b.bill.createdAt.compareTo(a.bill.createdAt));
    return result;
  }

  /// Sum of all unpaid amounts for this user (across all bill categories).
  double totalDueForUser(String userId) {
    return userBillViews(userId)
        .where((v) => !v.payment.isPaid)
        .fold(0.0, (s, v) => s + v.userAmount);
  }

  /// Sum of all paid amounts for this user (across all bill categories).
  double totalPaidForUser(String userId) {
    return userBillViews(userId)
        .where((v) => v.payment.isPaid)
        .fold(0.0, (s, v) => s + v.userAmount);
  }

  /// Count of unpaid bills (by unique bill document, not category expansions).
  int pendingUserBillsCount(String userId) {
    final seenBillIds = <String>{};
    return userBillViews(userId).where((v) {
      return !v.payment.isPaid && seenBillIds.add(v.bill.id);
    }).length;
  }

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

  /// Server-authoritative duplicate check — bypasses the Firestore offline
  /// cache. Always call this before creating a bill; the stream cache can be
  /// stale after console deletions or across sessions.
  Future<bool> checkMonthlyBillFresh(String aptId, String month) =>
      _fs.monthlyBillExistsOnServer(aptId, month);

  /// Returns the raw (non-synthetic) bill document by id, or null.
  BillModel? rawBillById(String id) {
    try {
      return _bills.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

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

  /// Groups bills by month, expanding multi-category bills into synthetic
  /// per-category BillModel entries so the admin detail screen can iterate
  /// each category as a separate line item.
  List<MonthlyBillSummary> monthlyBillsForApartment(String aptId) {
    final bills = billsForApartment(aptId);
    final grouped = <String, List<BillModel>>{};
    for (final b in bills) {
      grouped.putIfAbsent(b.month, () => []).addAll(_expandBillToSyntheticList(b));
    }
    final summaries = grouped.entries.map((e) {
      // Payments are keyed by bill.id; synthetic bills share the same id as
      // their parent, so deduplication via Set identity is necessary.
      final monthPayments = e.value
          .expand((b) => paymentsForBill(b.id))
          .toSet()
          .toList();
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

  /// Creates ONE Firestore bill document with embedded [categories] for [month].
  /// Each resident gets a single payment record whose [amount] equals the sum
  /// of their per-category amounts (category-aware: common / hybrid / individual).
  Future<void> createBillForMonth({
    required String apartmentId,
    required String adminId,
    required String month,
    required DateTime dueDate,
    required List<BillCategory> categories,
    required int totalFlats,
    required List<UserModel> residents,
    required NotificationProvider notificationProvider,
    List<String> excludedUserIds = const [],
  }) async {
    _isLoading = true;
    notifyListeners();

    final now = DateTime.now();
    final billId = 'bill_${now.millisecondsSinceEpoch}';
    final totalAmount = categories.fold(0.0, (s, c) => s + c.totalAmount);

    debugPrint('[FLOW] Creating bill for $month: ${categories.length} categories, ${residents.length} residents');

    await _fs.setBill(billId, {
      'apartmentId': apartmentId,
      'createdByAdminId': adminId,
      'title': categories.isNotEmpty ? categories.first.name : '',
      'totalAmount': totalAmount,
      'totalFlats': totalFlats,
      'category': '',
      'month': month,
      'dueDate': Timestamp.fromDate(dueDate),
      'createdAt': Timestamp.fromDate(now),
      'billType': 'common',
      'categories': categories.map((c) => c.toMap()).toList(),
      if (excludedUserIds.isNotEmpty) 'excludedUserIds': excludedUserIds,
    });
    debugPrint('[FLOW] Bill doc created: $billId, total=₹${totalAmount.toStringAsFixed(0)}');

    // eligibleCount must match BillModel.eligibleCount so stored amounts are consistent.
    final eligibleCount = (totalFlats - excludedUserIds.length).clamp(1, totalFlats);

    // ── Step 1: compute amounts synchronously (pure Dart, no I/O) ────────────
    final Map<String, double> userAmounts = {};
    for (final resident in residents) {
      if (excludedUserIds.contains(resident.id)) continue;
      userAmounts[resident.id] = categories.fold(
          0.0, (s, c) => s + c.amountForUser(resident.id, eligibleCount));
    }
    debugPrint('[FLOW] Computed amounts for ${userAmounts.length} residents');

    // ── Step 2: write all payment docs in parallel ────────────────────────────
    await Future.wait(
      userAmounts.entries.map((entry) {
        final resident = residents.firstWhere((r) => r.id == entry.key);
        return _fs.setPayment('${billId}_${entry.key}', {
          'billId': billId,
          'userId': entry.key,
          'unitNumber': resident.unit,
          'status': BillStatus.pending,
          'amount': entry.value,
          'paidDate': null,
          'transactionId': null,
          'adminVerified': false,
          'apartmentId': apartmentId,
        });
      }),
    );
    debugPrint('[FLOW] All ${userAmounts.length} payment docs written');

    // ── Step 3: write all notification docs in parallel ───────────────────────
    final dueDateStr = '${dueDate.day}/${dueDate.month}/${dueDate.year}';
    try {
      await Future.wait(
        userAmounts.entries.map((entry) => _fs.addNotification({
              'userId': entry.key,
              'apartmentId': apartmentId,
              'title': 'New Bill for $month',
              'body': 'Your due amount is ₹${entry.value.toStringAsFixed(0)} — due by $dueDateStr.',
              'type': NotificationType.bill,
              'createdAt': FieldValue.serverTimestamp(),
              'isRead': false,
            })),
      );
      debugPrint('[FLOW] All ${userAmounts.length} notifications written');
    } catch (e) {
      debugPrint('[WARN] Bill notifications partially failed: $e');
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

  /// Updates the bill document with new [categories] and [dueDate].
  /// Re-calculates and updates payment amounts for residents who have NOT yet paid.
  Future<void> adminEditBill({
    required String billId,
    required List<BillCategory> categories,
    required DateTime dueDate,
    required List<UserModel> residents,
    required List<String> excludedUserIds,
  }) async {
    _isLoading = true;
    notifyListeners();

    final totalAmount = categories.fold(0.0, (s, c) => s + c.totalAmount);
    final bill = rawBillById(billId);
    final totalFlats = bill?.totalFlats ?? residents.length;

    await _fs.updateBill(billId, {
      'title': categories.isNotEmpty ? categories.first.name : '',
      'totalAmount': totalAmount,
      'dueDate': Timestamp.fromDate(dueDate),
      'categories': categories.map((c) => c.toMap()).toList(),
      'excludedUserIds': excludedUserIds,
    });

    // Update amounts only for unpaid payments
    for (final resident in residents) {
      final payment = userPaymentForBill(billId, resident.id);
      if (excludedUserIds.contains(resident.id)) {
        // No payment should exist for excluded user; skip
        continue;
      }
      if (payment != null && !payment.isPaid) {
        final userAmount = categories.fold(
            0.0, (s, c) => s + c.amountForUser(resident.id, totalFlats));
        final paymentId = '${billId}_${resident.id}';
        await _fs.updatePayment(paymentId, {'amount': userAmount});
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Deletes the bill document and all associated payment documents.
  Future<void> adminDeleteBill(String billId) async {
    _isLoading = true;
    notifyListeners();

    await _fs.deleteAllPaymentsForBill(billId);
    await _fs.deleteBill(billId);

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
  final double? _precomputedAmount;

  const _UserBillView({
    required this.bill,
    required this.payment,
    double? precomputedAmount,
  }) : _precomputedAmount = precomputedAmount;

  /// Category-expanded bills: uses precomputed per-category amount.
  /// Individual (legacy) bills: payment.amount holds the per-user amount.
  /// Common (legacy) bills: falls back to bill.perFlatShare.
  double get userAmount => _precomputedAmount ?? payment.amount ?? bill.perFlatShare;
}

typedef UserBillView = _UserBillView;
