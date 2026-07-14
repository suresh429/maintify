import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/models/bill_model.dart';
import 'package:maintify/providers/bill_provider.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

BillModel makeBill({
  String id = 'b1',
  double totalAmount = 2000,
  int totalFlats = 10,
  DateTime? dueDate,
  List<BillCategory> categories = const [],
  List<String> excludedUserIds = const [],
}) =>
    BillModel(
      id: id,
      apartmentId: 'apt1',
      createdByAdminId: 'admin',
      title: 'Test Bill',
      totalAmount: totalAmount,
      totalFlats: totalFlats,
      category: '',
      month: 'Jun 2026',
      dueDate: dueDate ?? DateTime(2026, 6, 30),
      createdAt: DateTime(2026, 6, 1),
      categories: categories,
      excludedUserIds: excludedUserIds,
    );

BillPayment makePayment({
  required String id,
  required String billId,
  required String userId,
  String unitNumber = '101',
  String status = BillStatus.pending,
  DateTime? paidDate,
  double? amount,
}) =>
    BillPayment(
      id: id,
      billId: billId,
      userId: userId,
      unitNumber: unitNumber,
      status: status,
      paidDate: paidDate,
      amount: amount,
    );

// ── MonthlyBillSummary ────────────────────────────────────────────────────────

void main() {
  group('MonthlyBillSummary.totalAmount', () {
    test('sums totalAmount across all bills in the month', () {
      final bills = [makeBill(id: 'b1', totalAmount: 1000), makeBill(id: 'b2', totalAmount: 500)];
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: bills,
        allPayments: [],
        totalFlats: 10,
      );
      expect(summary.totalAmount, 1500.0);
    });

    test('returns 0 when no bills', () {
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: [],
        allPayments: [],
        totalFlats: 10,
      );
      expect(summary.totalAmount, 0.0);
    });
  });

  group('MonthlyBillSummary.dueDate', () {
    test('returns the latest due date across all bills', () {
      final bills = [
        makeBill(id: 'b1', dueDate: DateTime(2026, 6, 10)),
        makeBill(id: 'b2', dueDate: DateTime(2026, 6, 25)),
        makeBill(id: 'b3', dueDate: DateTime(2026, 6, 20)),
      ];
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: bills,
        allPayments: [],
        totalFlats: 10,
      );
      expect(summary.dueDate, DateTime(2026, 6, 25));
    });
  });

  group('MonthlyBillSummary.fullyPaidFlats', () {
    test('counts users who have paid ALL bills in the month', () {
      final b1 = makeBill(id: 'b1');
      final b2 = makeBill(id: 'b2');
      final payments = [
        // u1 paid both bills → fully paid
        makePayment(id: 'p1', billId: 'b1', userId: 'u1', status: BillStatus.paid),
        makePayment(id: 'p2', billId: 'b2', userId: 'u1', status: BillStatus.paid),
        // u2 only paid b1 → not fully paid
        makePayment(id: 'p3', billId: 'b1', userId: 'u2', status: BillStatus.paid),
        makePayment(id: 'p4', billId: 'b2', userId: 'u2', status: BillStatus.pending),
        // u3 paid nothing
        makePayment(id: 'p5', billId: 'b1', userId: 'u3', status: BillStatus.pending),
        makePayment(id: 'p6', billId: 'b2', userId: 'u3', status: BillStatus.pending),
      ];
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: [b1, b2],
        allPayments: payments,
        totalFlats: 3,
      );
      expect(summary.fullyPaidFlats, 1);
    });

    test('returns 0 when no bills', () {
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: [],
        allPayments: [],
        totalFlats: 5,
      );
      expect(summary.fullyPaidFlats, 0);
    });
  });

  group('MonthlyBillSummary.pendingFlats', () {
    test('eligibleFlats minus fullyPaidFlats', () {
      final bill = makeBill(id: 'b1', totalFlats: 3);
      final payments = [
        makePayment(id: 'p1', billId: 'b1', userId: 'u1', status: BillStatus.paid),
        makePayment(id: 'p2', billId: 'b1', userId: 'u2', status: BillStatus.pending),
        makePayment(id: 'p3', billId: 'b1', userId: 'u3', status: BillStatus.pending),
      ];
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: [bill],
        allPayments: payments,
        totalFlats: 3,
      );
      expect(summary.fullyPaidFlats, 1);
      expect(summary.pendingFlats, 2);
    });
  });

  group('MonthlyBillSummary.overallStatus', () {
    test('Paid when all eligible flats have paid', () {
      final bill = makeBill(id: 'b1', totalFlats: 2);
      final payments = [
        makePayment(id: 'p1', billId: 'b1', userId: 'u1', status: BillStatus.paid),
        makePayment(id: 'p2', billId: 'b1', userId: 'u2', status: BillStatus.paid),
      ];
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: [bill],
        allPayments: payments,
        totalFlats: 2,
      );
      expect(summary.overallStatus, BillStatus.paid);
    });

    test('Pending when nobody has paid', () {
      final bill = makeBill(id: 'b1', totalFlats: 2);
      final payments = [
        makePayment(id: 'p1', billId: 'b1', userId: 'u1', status: BillStatus.pending),
        makePayment(id: 'p2', billId: 'b1', userId: 'u2', status: BillStatus.pending),
      ];
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: [bill],
        allPayments: payments,
        totalFlats: 2,
      );
      expect(summary.overallStatus, BillStatus.pending);
    });

    test('Partial when some (not all) flats have paid', () {
      final bill = makeBill(id: 'b1', totalFlats: 3);
      final payments = [
        makePayment(id: 'p1', billId: 'b1', userId: 'u1', status: BillStatus.paid),
        makePayment(id: 'p2', billId: 'b1', userId: 'u2', status: BillStatus.pending),
        makePayment(id: 'p3', billId: 'b1', userId: 'u3', status: BillStatus.pending),
      ];
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: [bill],
        allPayments: payments,
        totalFlats: 3,
      );
      expect(summary.overallStatus, BillStatus.partiallyPaid);
    });
  });

  group('MonthlyBillSummary.isUserFullyPaid', () {
    test('true when user has paid all bills', () {
      final b1 = makeBill(id: 'b1');
      final b2 = makeBill(id: 'b2');
      final payments = [
        makePayment(id: 'p1', billId: 'b1', userId: 'u1', status: BillStatus.paid),
        makePayment(id: 'p2', billId: 'b2', userId: 'u1', status: BillStatus.paid),
      ];
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: [b1, b2],
        allPayments: payments,
        totalFlats: 1,
      );
      expect(summary.isUserFullyPaid('u1'), isTrue);
    });

    test('false when user has not paid some bills', () {
      final b1 = makeBill(id: 'b1');
      final b2 = makeBill(id: 'b2');
      final payments = [
        makePayment(id: 'p1', billId: 'b1', userId: 'u1', status: BillStatus.paid),
        makePayment(id: 'p2', billId: 'b2', userId: 'u1', status: BillStatus.pending),
      ];
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: [b1, b2],
        allPayments: payments,
        totalFlats: 1,
      );
      expect(summary.isUserFullyPaid('u1'), isFalse);
    });

    test('false for user with no payments', () {
      final bill = makeBill(id: 'b1');
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: [bill],
        allPayments: [],
        totalFlats: 1,
      );
      expect(summary.isUserFullyPaid('u_ghost'), isFalse);
    });
  });

  group('MonthlyBillSummary.userPaidDate', () {
    test('returns latest paidDate when user is fully paid', () {
      final bill = makeBill(id: 'b1');
      final early = DateTime(2026, 6, 5);
      final late = DateTime(2026, 6, 10);
      final payments = [
        makePayment(id: 'p1', billId: 'b1', userId: 'u1',
            status: BillStatus.paid, paidDate: early),
        makePayment(id: 'p2', billId: 'b1', userId: 'u1',
            status: BillStatus.paid, paidDate: late),
      ];
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: [bill],
        allPayments: payments,
        totalFlats: 1,
      );
      expect(summary.userPaidDate('u1'), late);
    });

    test('returns null when user has not fully paid', () {
      final bill = makeBill(id: 'b1');
      final payments = [
        makePayment(id: 'p1', billId: 'b1', userId: 'u1', status: BillStatus.pending),
      ];
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: [bill],
        allPayments: payments,
        totalFlats: 1,
      );
      expect(summary.userPaidDate('u1'), isNull);
    });
  });

  group('MonthlyBillSummary.flatList', () {
    test('returns unique users sorted by unitNumber', () {
      final bill = makeBill(id: 'b1');
      final payments = [
        makePayment(id: 'p1', billId: 'b1', userId: 'u3', unitNumber: '301'),
        makePayment(id: 'p2', billId: 'b1', userId: 'u1', unitNumber: '101'),
        makePayment(id: 'p3', billId: 'b1', userId: 'u2', unitNumber: '201'),
      ];
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: [bill],
        allPayments: payments,
        totalFlats: 3,
      );
      final flat = summary.flatList;
      expect(flat.length, 3);
      expect(flat[0].unitNumber, '101');
      expect(flat[1].unitNumber, '201');
      expect(flat[2].unitNumber, '301');
    });

    test('deduplicates users appearing in multiple payment records', () {
      final b1 = makeBill(id: 'b1');
      final b2 = makeBill(id: 'b2');
      final payments = [
        makePayment(id: 'p1', billId: 'b1', userId: 'u1', unitNumber: '101'),
        makePayment(id: 'p2', billId: 'b2', userId: 'u1', unitNumber: '101'),
      ];
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: [b1, b2],
        allPayments: payments,
        totalFlats: 1,
      );
      expect(summary.flatList.length, 1);
    });
  });

  // ── MonthlyBillSummary.eligibleFlats / allExcludedUserIds ─────────────────

  group('MonthlyBillSummary.eligibleFlats', () {
    test('subtracts excluded users from totalFlats', () {
      final bill = makeBill(id: 'b1', totalFlats: 10, excludedUserIds: ['u8', 'u9']);
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: [bill],
        allPayments: [],
        totalFlats: 10,
      );
      expect(summary.eligibleFlats, 8);
    });

    test('falls back to totalFlats when all would be excluded', () {
      final bill = makeBill(id: 'b1', totalFlats: 2, excludedUserIds: ['u1', 'u2']);
      final summary = MonthlyBillSummary(
        month: 'Jun 2026',
        apartmentId: 'apt1',
        bills: [bill],
        allPayments: [],
        totalFlats: 2,
      );
      expect(summary.eligibleFlats, 2);
    });
  });

  // ── UserMonthlySummary ─────────────────────────────────────────────────────

  group('UserMonthlySummary', () {
    UserBillView makeView(BillModel bill, BillPayment payment) =>
        UserBillView(bill: bill, payment: payment);

    test('totalAmount sums userAmount across all views', () {
      final bill1 = makeBill(id: 'b1', totalFlats: 10, totalAmount: 1000);
      final bill2 = makeBill(id: 'b2', totalFlats: 10, totalAmount: 500);
      final p1 = makePayment(id: 'p1', billId: 'b1', userId: 'u1', status: BillStatus.pending);
      final p2 = makePayment(id: 'p2', billId: 'b2', userId: 'u1', status: BillStatus.pending);
      final summary = UserMonthlySummary(
        month: 'Jun 2026',
        userId: 'u1',
        views: [makeView(bill1, p1), makeView(bill2, p2)],
      );
      // 1000/10 + 500/10 = 100 + 50 = 150
      expect(summary.totalAmount, 150.0);
    });

    test('isFullyPaid when all payments are paid', () {
      final bill = makeBill(id: 'b1', totalFlats: 10);
      final payment = makePayment(id: 'p1', billId: 'b1', userId: 'u1', status: BillStatus.paid);
      final summary = UserMonthlySummary(
        month: 'Jun 2026',
        userId: 'u1',
        views: [makeView(bill, payment)],
      );
      expect(summary.isFullyPaid, isTrue);
    });

    test('isFullyPaid false when any payment is pending', () {
      final b1 = makeBill(id: 'b1', totalFlats: 10);
      final b2 = makeBill(id: 'b2', totalFlats: 10);
      final p1 = makePayment(id: 'p1', billId: 'b1', userId: 'u1', status: BillStatus.paid);
      final p2 = makePayment(id: 'p2', billId: 'b2', userId: 'u1', status: BillStatus.pending);
      final summary = UserMonthlySummary(
        month: 'Jun 2026',
        userId: 'u1',
        views: [makeView(b1, p1), makeView(b2, p2)],
      );
      expect(summary.isFullyPaid, isFalse);
    });

    test('isPartiallyPaid when some paid and some not', () {
      final b1 = makeBill(id: 'b1', totalFlats: 10);
      final b2 = makeBill(id: 'b2', totalFlats: 10);
      final p1 = makePayment(id: 'p1', billId: 'b1', userId: 'u1', status: BillStatus.paid);
      final p2 = makePayment(id: 'p2', billId: 'b2', userId: 'u1', status: BillStatus.pending);
      final summary = UserMonthlySummary(
        month: 'Jun 2026',
        userId: 'u1',
        views: [makeView(b1, p1), makeView(b2, p2)],
      );
      expect(summary.isPartiallyPaid, isTrue);
    });

    test('status is Overdue when any payment is overdue and not fully paid', () {
      final bill = makeBill(id: 'b1', totalFlats: 10);
      final payment = makePayment(id: 'p1', billId: 'b1', userId: 'u1', status: BillStatus.overdue);
      final summary = UserMonthlySummary(
        month: 'Jun 2026',
        userId: 'u1',
        views: [makeView(bill, payment)],
      );
      expect(summary.status, BillStatus.overdue);
    });

    test('status is Pending when all payments are pending', () {
      final bill = makeBill(id: 'b1', totalFlats: 10);
      final payment = makePayment(id: 'p1', billId: 'b1', userId: 'u1', status: BillStatus.pending);
      final summary = UserMonthlySummary(
        month: 'Jun 2026',
        userId: 'u1',
        views: [makeView(bill, payment)],
      );
      expect(summary.status, BillStatus.pending);
    });

    test('dueDate returns latest due date across bills', () {
      final b1 = makeBill(id: 'b1', totalFlats: 10, dueDate: DateTime(2026, 6, 10));
      final b2 = makeBill(id: 'b2', totalFlats: 10, dueDate: DateTime(2026, 6, 25));
      final p1 = makePayment(id: 'p1', billId: 'b1', userId: 'u1', status: BillStatus.pending);
      final p2 = makePayment(id: 'p2', billId: 'b2', userId: 'u1', status: BillStatus.pending);
      final summary = UserMonthlySummary(
        month: 'Jun 2026',
        userId: 'u1',
        views: [makeView(b1, p1), makeView(b2, p2)],
      );
      expect(summary.dueDate, DateTime(2026, 6, 25));
    });

    test('paidDate is null when not fully paid', () {
      final bill = makeBill(id: 'b1', totalFlats: 10);
      final payment = makePayment(id: 'p1', billId: 'b1', userId: 'u1', status: BillStatus.pending);
      final summary = UserMonthlySummary(
        month: 'Jun 2026',
        userId: 'u1',
        views: [makeView(bill, payment)],
      );
      expect(summary.paidDate, isNull);
    });

    test('paidDate returns latest payment date when fully paid', () {
      final b1 = makeBill(id: 'b1', totalFlats: 10);
      final b2 = makeBill(id: 'b2', totalFlats: 10);
      final early = DateTime(2026, 6, 5);
      final late = DateTime(2026, 6, 10);
      final p1 = makePayment(id: 'p1', billId: 'b1', userId: 'u1',
          status: BillStatus.paid, paidDate: early);
      final p2 = makePayment(id: 'p2', billId: 'b2', userId: 'u1',
          status: BillStatus.paid, paidDate: late);
      final summary = UserMonthlySummary(
        month: 'Jun 2026',
        userId: 'u1',
        views: [makeView(b1, p1), makeView(b2, p2)],
      );
      expect(summary.paidDate, late);
    });
  });
}
