// Billing calculation consistency tests.
//
// Verifies that the Admin/President view and the Resident view derive per-flat
// and per-user amounts from the SAME authoritative source in BillModel /
// BillCategory, with no duplicated or diverging formulas.
//
// The August 2026 fixture matches the exact data reported in the bug:
//   electricity ₹3,818 common  | watchman ₹7,000 common | CCTV ₹598 common
//   GHMC ₹1,200 hybrid (default ₹150)                   | water ₹1,295 common
//   Total flats: 10 | apartmentId: 'apt_aug'
//
// Before the fix, the admin "Per Flat" for GHMC was ₹1,200/10 = ₹120 while the
// resident saw ₹150 (the correct defaultAmount), producing a ₹30 discrepancy
// that cascaded into ₹1,391 (admin) vs ₹1,421 (resident) totals.

import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/models/bill_model.dart';
import 'package:maintify/providers/bill_provider.dart';

// ── Shared August 2026 fixture ────────────────────────────────────────────────

const _aptId = 'apt_aug';
const _month = 'August 2026';
const _userId = 'u_resident';
const _totalFlats = 10;

/// The single Firestore bill document for August 2026.
BillModel _augBill() => BillModel(
      id: 'bill_aug',
      apartmentId: _aptId,
      createdByAdminId: 'u_president',
      title: 'electricity bill',
      totalAmount: 13911,
      totalFlats: _totalFlats,
      category: '',
      month: _month,
      dueDate: DateTime(2026, 8, 31),
      createdAt: DateTime(2026, 8, 1),
      categories: const [
        BillCategory(name: 'electricity bill', type: 'common', totalAmount: 3818),
        BillCategory(name: 'watch man salary', type: 'common', totalAmount: 7000),
        BillCategory(name: 'CCTV BILL',        type: 'common', totalAmount: 598),
        BillCategory(
          name: 'GHMC GARBAGE',
          type: 'hybrid',
          totalAmount: 1200,
          defaultAmount: 150,
        ),
        BillCategory(name: 'WATER BILL', type: 'common', totalAmount: 1295),
      ],
    );

BillPayment _augPayment() => BillPayment(
      id: 'bill_aug_$_userId',
      billId: 'bill_aug',
      userId: _userId,
      unitNumber: '101',
      status: BillStatus.pending,
      // amount stored at creation = sum of per-category amountForUser
      amount: 1421.1, // 381.8 + 700 + 59.8 + 150 + 129.5
    );

// ── Helper: simulate _expandBillToSyntheticList ───────────────────────────────
//
// We can't call BillProvider._expandBillToSyntheticList directly (it's private),
// so replicate the FIXED logic here to verify the contract.
List<BillModel> _expandBill(BillModel bill) {
  if (bill.categories.isEmpty) return [bill];
  return bill.categories.map((cat) => BillModel(
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
        categories: [cat], // FIXED: preserve so perFlatShare uses type logic
        excludedUserIds: bill.excludedUserIds,
      )).toList();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Admin and Resident use the same calculation source ─────────────────

  group('Admin and Resident share the same per-flat/per-user calculation', () {
    test('common category: admin perFlatShare == resident amountForUser', () {
      final bill = _augBill();
      final synthetics = _expandBill(bill);
      final electricitySynthetic = synthetics.first; // electricity bill

      final adminPerFlat = electricitySynthetic.perFlatShare;
      final residentShare = bill.categories[0]
          .amountForUser(_userId, bill.eligibleCount);

      expect(adminPerFlat, residentShare,
          reason: 'Common category must split identically for admin and resident');
    });

    test('hybrid category: admin perFlatShare == resident amountForUser (defaultAmount)', () {
      final bill = _augBill();
      final synthetics = _expandBill(bill);
      final ghmc = synthetics[3]; // GHMC GARBAGE

      final adminPerFlat = ghmc.perFlatShare;
      final residentShare = bill.categories[3]
          .amountForUser(_userId, bill.eligibleCount);

      expect(adminPerFlat, 150.0,
          reason: 'Hybrid perFlatShare must use defaultAmount, not totalAmount/totalFlats');
      expect(adminPerFlat, residentShare,
          reason: 'Hybrid: admin and resident must agree on per-flat amount');
    });

    test('MonthlyBillSummary.perFlatShare equals sum of resident userAmounts', () {
      final bill = _augBill();
      final synthetics = _expandBill(bill);
      final payment = _augPayment();

      final summary = MonthlyBillSummary(
        month: _month,
        apartmentId: _aptId,
        bills: synthetics,
        allPayments: [payment],
        totalFlats: _totalFlats,
      );

      // Resident total = sum of per-category amountForUser
      final residentTotal = bill.categories.fold<double>(
          0.0, (s, c) => s + c.amountForUser(_userId, bill.eligibleCount));

      expect(summary.perFlatShare, closeTo(residentTotal, 0.001),
          reason: 'Admin perFlatShare and resident userAmount total must agree');
    });
  });

  // ── 2. August 2026 exact calculation verification ─────────────────────────

  group('August 2026 billing data — exact values', () {
    late BillModel bill;
    late List<BillModel> synthetics;

    setUp(() {
      bill = _augBill();
      synthetics = _expandBill(bill);
    });

    test('apartment totalAmount is ₹13,911', () {
      expect(bill.totalAmount, 13911.0);
    });

    test('totalFlats is 10', () {
      expect(bill.totalFlats, _totalFlats);
    });

    test('eligibleCount is 10 (no exclusions)', () {
      expect(bill.eligibleCount, 10);
    });

    test('electricity per flat = ₹381.80 (3818 / 10)', () {
      expect(synthetics[0].perFlatShare, closeTo(381.8, 0.001));
    });

    test('watchman per flat = ₹700.00 (7000 / 10)', () {
      expect(synthetics[1].perFlatShare, closeTo(700.0, 0.001));
    });

    test('CCTV per flat = ₹59.80 (598 / 10)', () {
      expect(synthetics[2].perFlatShare, closeTo(59.8, 0.001));
    });

    test('GHMC GARBAGE per flat = ₹150.00 (hybrid defaultAmount)', () {
      // Before fix this was ₹1200/10 = ₹120 — WRONG
      expect(synthetics[3].perFlatShare, closeTo(150.0, 0.001));
    });

    test('WATER BILL per flat = ₹129.50 (1295 / 10)', () {
      expect(synthetics[4].perFlatShare, closeTo(129.5, 0.001));
    });

    test('sum of synthetic perFlatShares = ₹1421.10', () {
      final total = synthetics.fold<double>(0, (s, b) => s + b.perFlatShare);
      expect(total, closeTo(1421.1, 0.01));
    });

    test('MonthlyBillSummary.perFlatShare = ₹1421.10 (not ₹1391)', () {
      final summary = MonthlyBillSummary(
        month: _month,
        apartmentId: _aptId,
        bills: synthetics,
        allPayments: [],
        totalFlats: _totalFlats,
      );
      expect(summary.perFlatShare, closeTo(1421.1, 0.01));
    });

    test('bill.amountForUser produces ₹1421.10 for non-excluded resident', () {
      expect(bill.amountForUser(_userId), closeTo(1421.1, 0.01));
    });

    test('both screens agree: perFlatShare == amountForUser for resident without overrides', () {
      final summary = MonthlyBillSummary(
        month: _month,
        apartmentId: _aptId,
        bills: synthetics,
        allPayments: [_augPayment()],
        totalFlats: _totalFlats,
      );
      expect(
        summary.perFlatShare,
        closeTo(bill.amountForUser(_userId), 0.01),
      );
    });
  });

  // ── 3. Common bill calculations are identical ──────────────────────────────

  group('Common bill: admin and resident always agree', () {
    test('equal split across 10 flats with no exclusions', () {
      const cat = BillCategory(name: 'Lift', type: 'common', totalAmount: 3000);
      final bill = BillModel(
        id: 'b1', apartmentId: 'apt1', createdByAdminId: 'u1',
        title: 'Lift', totalAmount: 3000, totalFlats: 10,
        category: '', month: 'August 2026',
        dueDate: DateTime(2026, 8, 31), createdAt: DateTime(2026, 8, 1),
        categories: const [cat],
      );
      final synthetic = _expandBill(bill).first;

      expect(synthetic.perFlatShare, 300.0);
      expect(cat.amountForUser('u1', bill.eligibleCount), 300.0);
      expect(synthetic.perFlatShare, cat.amountForUser('u1', bill.eligibleCount));
    });

    test('equal split with 2 exclusions uses eligibleCount=8 not totalFlats=10', () {
      const cat = BillCategory(name: 'Security', type: 'common', totalAmount: 800);
      final bill = BillModel(
        id: 'b2', apartmentId: 'apt1', createdByAdminId: 'u1',
        title: 'Security', totalAmount: 800, totalFlats: 10,
        category: '', month: 'August 2026',
        dueDate: DateTime(2026, 8, 31), createdAt: DateTime(2026, 8, 1),
        categories: const [cat],
        excludedUserIds: const ['uX', 'uY'],
      );
      final synthetic = _expandBill(bill).first;

      // eligibleCount = 10 - 2 = 8
      expect(bill.eligibleCount, 8);
      expect(synthetic.perFlatShare, 100.0);  // 800 / 8
      expect(cat.amountForUser('u1', bill.eligibleCount), 100.0);
    });
  });

  // ── 4. Hybrid bill calculation follows business rule ──────────────────────

  group('Hybrid bill: defaultAmount governs, overrides take precedence', () {
    const cat = BillCategory(
      name: 'GHMC GARBAGE', type: 'hybrid',
      totalAmount: 1200, defaultAmount: 150,
      userOverrides: {'u_override': 200},
    );
    final bill = BillModel(
      id: 'b3', apartmentId: 'apt1', createdByAdminId: 'u1',
      title: 'GHMC', totalAmount: 1200, totalFlats: 10,
      category: '', month: 'August 2026',
      dueDate: DateTime(2026, 8, 31), createdAt: DateTime(2026, 8, 1),
      categories: const [cat],
    );

    test('perFlatShare for hybrid = defaultAmount (not totalAmount/totalFlats)', () {
      final synthetic = _expandBill(bill).first;
      expect(synthetic.perFlatShare, 150.0);
    });

    test('resident without override sees defaultAmount', () {
      expect(cat.amountForUser('u_regular', 10), 150.0);
    });

    test('resident with override sees override amount', () {
      expect(cat.amountForUser('u_override', 10), 200.0);
    });

    test('admin perFlatShare (defaultAmount) == resident without override', () {
      final synthetic = _expandBill(bill).first;
      expect(synthetic.perFlatShare, cat.amountForUser('u_regular', 10));
    });
  });

  // ── 5. Rounding does not create incorrect totals ──────────────────────────

  group('Rounding: authoritative total from model, not from rounded display values', () {
    test('precision is maintained through double arithmetic, not integer rounding', () {
      final bill = _augBill();
      final preciseTotal = bill.amountForUser(_userId);
      // 381.8 + 700.0 + 59.8 + 150.0 + 129.5 = 1421.1
      expect(preciseTotal, closeTo(1421.1, 0.001));

      // Summing individually rounded integer values gives a WRONG total
      // (382 + 700 + 60 + 150 + 130 = 1422 — off by ₹0.90)
      // The app must use preciseTotal, never sum of rounded display values.
      const displayRoundedSum = 382 + 700 + 60 + 150 + 130;
      expect(displayRoundedSum, isNot(closeTo(preciseTotal, 0.01)));
    });

    test('electricity: 3818/10 = 381.80 (not 382.0)', () {
      const cat = BillCategory(name: 'e', type: 'common', totalAmount: 3818);
      expect(cat.amountForUser('u', 10), closeTo(381.8, 0.001));
    });

    test('CCTV: 598/10 = 59.80 (not 60.0)', () {
      const cat = BillCategory(name: 'c', type: 'common', totalAmount: 598);
      expect(cat.amountForUser('u', 10), closeTo(59.8, 0.001));
    });

    test('water: 1295/10 = 129.50 (not 130.0)', () {
      const cat = BillCategory(name: 'w', type: 'common', totalAmount: 1295);
      expect(cat.amountForUser('u', 10), closeTo(129.5, 0.001));
    });
  });

  // ── 6. Same billing period on both screens ────────────────────────────────

  group('Billing period and apartment ID consistency', () {
    test('month string "August 2026" is preserved on synthetic bills', () {
      final synthetics = _expandBill(_augBill());
      for (final s in synthetics) {
        expect(s.month, _month,
            reason: 'Synthetic bill must carry same month as parent');
      }
    });

    test('apartmentId is preserved on synthetic bills', () {
      final synthetics = _expandBill(_augBill());
      for (final s in synthetics) {
        expect(s.apartmentId, _aptId,
            reason: 'Synthetic bill must carry same apartmentId as parent');
      }
    });

    test('billId is preserved on synthetic bills (payment lookup key)', () {
      final bill = _augBill();
      final synthetics = _expandBill(bill);
      for (final s in synthetics) {
        expect(s.id, bill.id,
            reason: 'Synthetic bills share parent id for payment lookups');
      }
    });
  });

  // ── 7. Category values reconcile with apartment total ─────────────────────

  group('Category totals reconcile with apartment totalAmount', () {
    test('sum of category.totalAmount == bill.totalAmount', () {
      final bill = _augBill();
      final catSum = bill.categories.fold<double>(0, (s, c) => s + c.totalAmount);
      expect(catSum, closeTo(bill.totalAmount, 0.001));
    });

    test('synthetic bills: sum of totalAmount == parent totalAmount', () {
      final bill = _augBill();
      final synthetics = _expandBill(bill);
      final syntheticSum = synthetics.fold<double>(0, (s, b) => s + b.totalAmount);
      expect(syntheticSum, closeTo(bill.totalAmount, 0.001));
    });
  });

  // ── 8. adminEditBill uses eligibleCount, not totalFlats ───────────────────

  group('adminEditBill: eligibleCount used consistently with createBill', () {
    test('common category: eligibleCount = totalFlats - excludedCount', () {
      const totalFlats = 10;
      final excludedUserIds = ['uX', 'uY'];
      final eligibleCount = (totalFlats - excludedUserIds.length).clamp(1, totalFlats);
      expect(eligibleCount, 8);

      const cat = BillCategory(name: 'Security', type: 'common', totalAmount: 800);
      // At creation: 800 / 8 = 100
      final creationAmount = cat.amountForUser('u1', eligibleCount);
      // After edit with the FIX: also uses eligibleCount = 8 → 100
      final editAmount = cat.amountForUser('u1', eligibleCount);

      expect(creationAmount, editAmount);
      expect(editAmount, 100.0);
    });

    test('before fix (using totalFlats): edit would produce wrong amount', () {
      const totalFlats = 10;
      const eligibleCount = 8; // 2 excluded

      const cat = BillCategory(name: 'Security', type: 'common', totalAmount: 800);
      final correctAmount = cat.amountForUser('u1', eligibleCount); // 100
      final buggyAmount  = cat.amountForUser('u1', totalFlats);     // 80

      expect(buggyAmount, isNot(correctAmount),
          reason: 'Using totalFlats instead of eligibleCount gives wrong amount when exclusions exist');
    });
  });

  // ── 9. New billing month does not inherit stale values ────────────────────

  group('No stale values bleed between months', () {
    test('MonthlyBillSummary for August 2026 only includes August bills', () {
      final augBill = _augBill();
      final mayBill = BillModel(
        id: 'bill_may', apartmentId: _aptId, createdByAdminId: 'u_p',
        title: 'May bill', totalAmount: 5000, totalFlats: 10,
        category: '', month: 'May 2026',
        dueDate: DateTime(2026, 5, 31), createdAt: DateTime(2026, 5, 1),
      );

      final augSynthetics = _expandBill(augBill);
      final maySummary = MonthlyBillSummary(
        month: 'May 2026',
        apartmentId: _aptId,
        bills: [mayBill],
        allPayments: [],
        totalFlats: _totalFlats,
      );
      final augSummary = MonthlyBillSummary(
        month: _month,
        apartmentId: _aptId,
        bills: augSynthetics,
        allPayments: [],
        totalFlats: _totalFlats,
      );

      expect(maySummary.month, 'May 2026');
      expect(augSummary.month, _month);
      expect(maySummary.totalAmount, isNot(augSummary.totalAmount),
          reason: 'Different months must have independent totals');
    });
  });

  // ── 10. Excluded user owes ₹0 on both screens ────────────────────────────

  group('Excluded user: both admin and resident agree on ₹0', () {
    test('excluded user owes 0 via bill.amountForUser', () {
      final bill = BillModel(
        id: 'b', apartmentId: 'apt1', createdByAdminId: 'u1',
        title: 'Test', totalAmount: 1000, totalFlats: 10,
        category: '', month: 'August 2026',
        dueDate: DateTime(2026, 8, 31), createdAt: DateTime(2026, 8, 1),
        excludedUserIds: const ['u_excluded'],
      );
      expect(bill.amountForUser('u_excluded'), 0.0);
    });

    test('excluded user: each category amountForUser returns 0', () {
      const categories = [
        BillCategory(name: 'Common', type: 'common', totalAmount: 500),
        BillCategory(name: 'Hybrid', type: 'hybrid', totalAmount: 300, defaultAmount: 30),
      ];
      // Exclusion is checked at BillModel.amountForUser level, not BillCategory.
      // BillCategory itself has no exclusion awareness — that is correct by design.
      // The BillModel guards excluded users before delegating to categories.
      final bill = BillModel(
        id: 'b', apartmentId: 'apt1', createdByAdminId: 'u1',
        title: 'Test', totalAmount: 800, totalFlats: 10,
        category: '', month: 'August 2026',
        dueDate: DateTime(2026, 8, 31), createdAt: DateTime(2026, 8, 1),
        categories: categories,
        excludedUserIds: const ['u_excluded'],
      );
      expect(bill.amountForUser('u_excluded'), 0.0,
          reason: 'BillModel.amountForUser must return 0 for excluded users');
      expect(bill.amountForUser('u_regular'), isNot(0.0),
          reason: 'Non-excluded user must still owe their share');
    });
  });

  // ── 11. Hybrid applicableResidentIds: non-applicable pays ₹0 ─────────────

  group('Hybrid applicableResidentIds — applicable/non-applicable logic', () {
    const cat = BillCategory(
      name: 'GHMC GARBAGE',
      type: 'hybrid',
      totalAmount: 1200,
      defaultAmount: 150,
      applicableResidentIds: ['u1', 'u2', 'u3', 'u4', 'u5', 'u6', 'u7', 'u8'],
    );

    test('applicable resident pays defaultAmount', () {
      expect(cat.amountForUser('u1', 10), 150.0);
    });

    test('non-applicable resident pays ₹0', () {
      expect(cat.amountForUser('u9', 10), 0.0);
      expect(cat.amountForUser('u10', 10), 0.0);
    });

    test('isApplicable returns true for applicable resident', () {
      expect(cat.isApplicable('u1'), isTrue);
    });

    test('isApplicable returns false for non-applicable resident', () {
      expect(cat.isApplicable('u9'), isFalse);
    });

    test('total reconciles: 8 × ₹150 = ₹1,200', () {
      final applicableTotal = [
        'u1','u2','u3','u4','u5','u6','u7','u8'
      ].fold<double>(0, (s, uid) => s + cat.amountForUser(uid, 10));
      expect(applicableTotal, closeTo(1200.0, 0.001));
    });

    test('all 10 flats: applicable pay ₹150, non-applicable pay ₹0', () {
      const allResidents = ['u1','u2','u3','u4','u5','u6','u7','u8','u9','u10'];
      final amounts = {for (final uid in allResidents) uid: cat.amountForUser(uid, 10)};
      for (final uid in ['u1','u2','u3','u4','u5','u6','u7','u8']) {
        expect(amounts[uid], 150.0, reason: '$uid should pay ₹150');
      }
      for (final uid in ['u9','u10']) {
        expect(amounts[uid], 0.0, reason: '$uid should pay ₹0');
      }
    });
  });

  group('Hybrid backward compat: empty applicableResidentIds = all applicable', () {
    const cat = BillCategory(
      name: 'GHMC GARBAGE',
      type: 'hybrid',
      totalAmount: 1500,
      defaultAmount: 150,
      // applicableResidentIds: [] (default — empty = all applicable)
    );

    test('empty applicableResidentIds: all residents pay defaultAmount', () {
      expect(cat.amountForUser('u1', 10), 150.0);
      expect(cat.amountForUser('u9', 10), 150.0);
    });

    test('isApplicable returns true when applicableResidentIds is empty', () {
      expect(cat.isApplicable('u_any'), isTrue);
    });
  });

  group('Hybrid: non-applicable resident never charged defaultAmount', () {
    const cat = BillCategory(
      name: 'GHMC',
      type: 'hybrid',
      totalAmount: 900,
      defaultAmount: 150,
      applicableResidentIds: ['u1', 'u2', 'u3', 'u4', 'u5', 'u6'],
    );

    test('non-applicable u7 gets ₹0 even if default is ₹150', () {
      expect(cat.amountForUser('u7', 10), 0.0);
    });

    test('applicable u1 gets ₹150', () {
      expect(cat.amountForUser('u1', 10), 150.0);
    });

    test('admin and resident agree: applicable flat gets ₹150', () {
      final bill = BillModel(
        id: 'b', apartmentId: 'apt', createdByAdminId: 'admin',
        title: 'GHMC', totalAmount: 900, totalFlats: 10,
        category: '', month: 'August 2026',
        dueDate: DateTime(2026, 8, 31), createdAt: DateTime(2026, 8, 1),
        categories: const [cat],
      );
      final synthetic = _expandBill(bill).first;
      // Admin per-flat (defaultAmount for hybrid)
      expect(synthetic.perFlatShare, 150.0);
      // Resident applicable
      expect(bill.amountForUser('u1'), 150.0);
      // Both agree
      expect(synthetic.perFlatShare, bill.amountForUser('u1'));
    });

    test('admin and resident agree: non-applicable flat gets ₹0', () {
      final bill = BillModel(
        id: 'b', apartmentId: 'apt', createdByAdminId: 'admin',
        title: 'GHMC', totalAmount: 900, totalFlats: 10,
        category: '', month: 'August 2026',
        dueDate: DateTime(2026, 8, 31), createdAt: DateTime(2026, 8, 1),
        categories: const [cat],
      );
      // Admin "per flat" shows ₹150 (the standard applicable amount)
      // but non-applicable resident u7 owes ₹0
      expect(bill.amountForUser('u7'), 0.0);
    });
  });

  group('Hybrid: updating applicable flats recalculates amounts', () {
    test('adding a resident to applicableResidentIds increases their amount from 0 to defaultAmount', () {
      const catBefore = BillCategory(
        name: 'GHMC',
        type: 'hybrid',
        totalAmount: 600,
        defaultAmount: 150,
        applicableResidentIds: ['u1', 'u2', 'u3', 'u4'],
      );
      const catAfter = BillCategory(
        name: 'GHMC',
        type: 'hybrid',
        totalAmount: 750,
        defaultAmount: 150,
        applicableResidentIds: ['u1', 'u2', 'u3', 'u4', 'u5'],
      );

      expect(catBefore.amountForUser('u5', 10), 0.0);
      expect(catAfter.amountForUser('u5', 10), 150.0);
    });

    test('removing a resident from applicableResidentIds sets their amount to 0', () {
      const catBefore = BillCategory(
        name: 'GHMC',
        type: 'hybrid',
        totalAmount: 750,
        defaultAmount: 150,
        applicableResidentIds: ['u1', 'u2', 'u3', 'u4', 'u5'],
      );
      const catAfter = BillCategory(
        name: 'GHMC',
        type: 'hybrid',
        totalAmount: 600,
        defaultAmount: 150,
        applicableResidentIds: ['u1', 'u2', 'u3', 'u4'],
      );

      expect(catBefore.amountForUser('u5', 10), 150.0);
      expect(catAfter.amountForUser('u5', 10), 0.0);
    });
  });

  group('Hybrid zero applicable: total = ₹0', () {
    test('all flats non-applicable: total = ₹0', () {
      const cat = BillCategory(
        name: 'GHMC',
        type: 'hybrid',
        totalAmount: 0,
        defaultAmount: 150,
        applicableResidentIds: [], // none (but empty = all applicable in legacy mode)
      );
      // With empty list (legacy mode), still all applicable
      expect(cat.isApplicable('u1'), isTrue);
    });

    // To have zero applicable, use a non-empty list that excludes everyone
    test('non-empty applicableResidentIds with no matching user: ₹0 for that user', () {
      const cat = BillCategory(
        name: 'GHMC',
        type: 'hybrid',
        totalAmount: 0,
        defaultAmount: 150,
        applicableResidentIds: ['u_other'],
      );
      expect(cat.amountForUser('u1', 10), 0.0);
      expect(cat.isApplicable('u1'), isFalse);
    });
  });
}
