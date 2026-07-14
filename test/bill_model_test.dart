import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/models/bill_model.dart';

void main() {
  // ── BillCategory.amountForUser ─────────────────────────────────────────────

  group('BillCategory.amountForUser', () {
    test('common: splits totalAmount equally across eligible flats', () {
      final cat = BillCategory(
        name: 'Lift',
        type: 'common',
        totalAmount: 2000,
      );
      expect(cat.amountForUser('u1', 10), 200.0);
    });

    test('common: returns 0 when eligibleCount is 0', () {
      final cat = BillCategory(
        name: 'Lift',
        type: 'common',
        totalAmount: 2000,
      );
      expect(cat.amountForUser('u1', 0), 0.0);
    });

    test('hybrid: returns defaultAmount when user has no override', () {
      final cat = BillCategory(
        name: 'Water',
        type: 'hybrid',
        totalAmount: 1500,
        defaultAmount: 150,
        userOverrides: {'u2': 300},
      );
      expect(cat.amountForUser('u1', 10), 150.0);
    });

    test('hybrid: returns override when user has one', () {
      final cat = BillCategory(
        name: 'Water',
        type: 'hybrid',
        totalAmount: 1500,
        defaultAmount: 150,
        userOverrides: {'u2': 300},
      );
      expect(cat.amountForUser('u2', 10), 300.0);
    });

    test('individual: returns 0 when user has no override', () {
      final cat = BillCategory(
        name: 'Parking',
        type: 'individual',
        totalAmount: 500,
        userOverrides: {'u3': 250},
      );
      expect(cat.amountForUser('u99', 10), 0.0);
    });

    test('individual: returns override amount for user with one', () {
      final cat = BillCategory(
        name: 'Parking',
        type: 'individual',
        totalAmount: 500,
        userOverrides: {'u3': 250},
      );
      expect(cat.amountForUser('u3', 10), 250.0);
    });

    test('unknown type: falls back to equal split', () {
      final cat = BillCategory(
        name: 'Other',
        type: 'unknown_type',
        totalAmount: 1000,
      );
      expect(cat.amountForUser('u1', 5), 200.0);
    });
  });

  // ── BillModel.eligibleCount ────────────────────────────────────────────────

  group('BillModel.eligibleCount', () {
    BillModel makeBill({int totalFlats = 10, List<String> excluded = const []}) {
      return BillModel(
        id: 'b1',
        apartmentId: 'apt1',
        createdByAdminId: 'u1',
        title: 'Test Bill',
        totalAmount: 1000,
        totalFlats: totalFlats,
        category: '',
        month: 'June 2026',
        dueDate: DateTime(2026, 6, 30),
        createdAt: DateTime(2026, 6, 1),
        excludedUserIds: excluded,
      );
    }

    test('no exclusions → eligibleCount equals totalFlats', () {
      expect(makeBill().eligibleCount, 10);
    });

    test('2 excluded → eligibleCount is totalFlats - 2', () {
      expect(makeBill(excluded: ['u1', 'u2']).eligibleCount, 8);
    });

    test('all excluded → falls back to totalFlats (never returns 0)', () {
      // Guards against division-by-zero in split calculations.
      final bill = makeBill(
        totalFlats: 2,
        excluded: ['u1', 'u2'],
      );
      expect(bill.eligibleCount, 2);
    });
  });

  // ── BillModel.perFlatShare ─────────────────────────────────────────────────

  group('BillModel.perFlatShare', () {
    test('no categories: totalAmount / eligibleCount', () {
      final bill = BillModel(
        id: 'b1',
        apartmentId: 'apt1',
        createdByAdminId: 'u1',
        title: 'Test',
        totalAmount: 2000,
        totalFlats: 10,
        category: '',
        month: 'Jun 2026',
        dueDate: DateTime(2026, 6, 30),
        createdAt: DateTime(2026, 6, 1),
      );
      expect(bill.perFlatShare, 200.0);
    });

    test('with categories: sums per-flat contributions', () {
      // common ₹1000 / 10 = ₹100 + hybrid default ₹150 = ₹250 per flat
      final bill = BillModel(
        id: 'b1',
        apartmentId: 'apt1',
        createdByAdminId: 'u1',
        title: 'Test',
        totalAmount: 2500,
        totalFlats: 10,
        category: '',
        month: 'Jun 2026',
        dueDate: DateTime(2026, 6, 30),
        createdAt: DateTime(2026, 6, 1),
        categories: const [
          BillCategory(name: 'Lift', type: 'common', totalAmount: 1000),
          BillCategory(name: 'Water', type: 'hybrid', totalAmount: 1500, defaultAmount: 150),
        ],
      );
      expect(bill.perFlatShare, 250.0);
    });

    test('individual categories do not contribute to perFlatShare', () {
      final bill = BillModel(
        id: 'b1',
        apartmentId: 'apt1',
        createdByAdminId: 'u1',
        title: 'Test',
        totalAmount: 600,
        totalFlats: 10,
        category: '',
        month: 'Jun 2026',
        dueDate: DateTime(2026, 6, 30),
        createdAt: DateTime(2026, 6, 1),
        categories: const [
          BillCategory(
            name: 'Parking',
            type: 'individual',
            totalAmount: 600,
            userOverrides: {'u1': 200, 'u2': 400},
          ),
        ],
      );
      expect(bill.perFlatShare, 0.0);
    });
  });

  // ── BillModel.amountForUser ────────────────────────────────────────────────

  group('BillModel.amountForUser', () {
    test('excluded user owes ₹0 regardless of categories', () {
      final bill = BillModel(
        id: 'b1',
        apartmentId: 'apt1',
        createdByAdminId: 'admin',
        title: 'Test',
        totalAmount: 2000,
        totalFlats: 10,
        category: '',
        month: 'Jun 2026',
        dueDate: DateTime(2026, 6, 30),
        createdAt: DateTime(2026, 6, 1),
        excludedUserIds: const ['u5'],
      );
      expect(bill.amountForUser('u5'), 0.0);
    });

    test('non-excluded user: sum across all categories', () {
      // common ₹1000 / 10 = ₹100; hybrid override for u1 = ₹200 → total ₹300
      final bill = BillModel(
        id: 'b1',
        apartmentId: 'apt1',
        createdByAdminId: 'admin',
        title: 'Test',
        totalAmount: 2500,
        totalFlats: 10,
        category: '',
        month: 'Jun 2026',
        dueDate: DateTime(2026, 6, 30),
        createdAt: DateTime(2026, 6, 1),
        categories: const [
          BillCategory(name: 'Lift', type: 'common', totalAmount: 1000),
          BillCategory(
            name: 'Water',
            type: 'hybrid',
            totalAmount: 1500,
            defaultAmount: 150,
            userOverrides: {'u1': 200},
          ),
        ],
      );
      expect(bill.amountForUser('u1'), 300.0); // 100 + 200
      expect(bill.amountForUser('u2'), 250.0); // 100 + 150
    });
  });

  // ── BillModel.overallStatus ────────────────────────────────────────────────

  group('BillModel.overallStatus', () {
    final futureDue = DateTime.now().add(const Duration(days: 10));
    final pastDue   = DateTime.now().subtract(const Duration(days: 5));

    BillModel makeBill(DateTime due) => BillModel(
          id: 'b',
          apartmentId: 'a',
          createdByAdminId: 'u',
          title: 'T',
          totalAmount: 1000,
          totalFlats: 3,
          category: '',
          month: 'Jun 2026',
          dueDate: due,
          createdAt: DateTime(2026, 6, 1),
        );

    BillPayment payment(String id, String status) => BillPayment(
          id: id,
          billId: 'b',
          userId: id,
          unitNumber: '101',
          status: status,
        );

    test('no payments → Pending', () {
      expect(makeBill(futureDue).overallStatus([]), BillStatus.pending);
    });

    test('all paid → Paid', () {
      final payments = [
        payment('u1', BillStatus.paid),
        payment('u2', BillStatus.paid),
      ];
      expect(makeBill(futureDue).overallStatus(payments), BillStatus.paid);
    });

    test('none paid + past due → Overdue', () {
      final payments = [
        payment('u1', BillStatus.pending),
        payment('u2', BillStatus.pending),
      ];
      expect(makeBill(pastDue).overallStatus(payments), BillStatus.overdue);
    });

    test('none paid + future due → Pending', () {
      final payments = [
        payment('u1', BillStatus.pending),
        payment('u2', BillStatus.pending),
      ];
      expect(makeBill(futureDue).overallStatus(payments), BillStatus.pending);
    });

    test('some paid → Partial', () {
      final payments = [
        payment('u1', BillStatus.paid),
        payment('u2', BillStatus.pending),
      ];
      expect(makeBill(futureDue).overallStatus(payments), BillStatus.partiallyPaid);
    });
  });

  // ── BillModel.paidFlats ────────────────────────────────────────────────────

  group('BillModel.paidFlats', () {
    final bill = BillModel(
      id: 'b',
      apartmentId: 'a',
      createdByAdminId: 'u',
      title: 'T',
      totalAmount: 1000,
      totalFlats: 3,
      category: '',
      month: 'Jun 2026',
      dueDate: DateTime(2026, 6, 30),
      createdAt: DateTime(2026, 6, 1),
    );

    BillPayment p(String id, String status) => BillPayment(
          id: id, billId: 'b', userId: id, unitNumber: '101', status: status);

    test('counts only paid payments', () {
      final payments = [
        p('u1', BillStatus.paid),
        p('u2', BillStatus.pending),
        p('u3', BillStatus.paid),
      ];
      expect(bill.paidFlats(payments), 2);
    });

    test('returns 0 when no payments are paid', () {
      final payments = [p('u1', BillStatus.pending)];
      expect(bill.paidFlats(payments), 0);
    });
  });
}
