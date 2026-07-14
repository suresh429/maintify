import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/models/apartment_model.dart';
import 'package:maintify/models/bill_model.dart';
import 'package:maintify/models/user_model.dart';
import 'package:maintify/providers/dashboard_provider.dart';
import 'package:maintify/core/theme/role_theme.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

/// Builds a minimal paid bill (all 10 payments paid).
List<BillPayment> _paidPayments(String billId, {int count = 10}) {
  return List.generate(
    count,
    (i) => BillPayment(
      id: 'p_${billId}_$i',
      billId: billId,
      userId: 'u$i',
      unitNumber: '${i + 1}01',
      status: BillStatus.paid,
    ),
  );
}

/// Builds a minimal overdue bill (all payments overdue).
List<BillPayment> _overduePayments(String billId, {int count = 10}) {
  return List.generate(
    count,
    (i) => BillPayment(
      id: 'p_${billId}_$i',
      billId: billId,
      userId: 'u$i',
      unitNumber: '${i + 1}01',
      status: BillStatus.overdue,
    ),
  );
}

BillModel _bill(String id, {double totalAmount = 1000, int totalFlats = 10}) =>
    BillModel(
      id: id,
      apartmentId: 'apt1',
      createdByAdminId: 'u2',
      title: 'Test Bill',
      totalAmount: totalAmount,
      totalFlats: totalFlats,
      category: '',
      month: 'Jun 2026',
      dueDate: DateTime(2026, 6, 30),
      createdAt: DateTime(2026, 6, 1),
    );

UserModel _user(String id, UserRole role, {String? aptId}) => UserModel(
      id: id,
      name: id,
      email: '$id@test.com',
      phone: '',
      role: role,
      apartmentId: aptId,
      unit: '101',
      avatarInitials: id.toUpperCase(),
      joinedAt: DateTime(2024),
    );

void main() {
  late DashboardProvider provider;

  setUp(() {
    provider = DashboardProvider();
  });

  // ── Super-admin level stats ────────────────────────────────────────────────

  group('DashboardProvider super-admin stats', () {
    setUp(() {
      // 1 apartment
      MockApartments.replaceAll([
        ApartmentModel(
          id: 'apt1',
          name: 'Test Apt',
          code: 'TST001',
          status: 'active',
          presidentId: 'u2',
          presidentName: 'Admin',
          totalFlats: 10,
          createdAt: DateTime(2021),
        ),
      ]);

      // 1 admin + 2 residents
      MockUsers.replaceAll([
        _user('u1', UserRole.superAdmin),
        _user('u2', UserRole.admin, aptId: 'apt1'),
        _user('u3', UserRole.user, aptId: 'apt1'),
        _user('u4', UserRole.user, aptId: 'apt1'),
      ]);

      // 1 paid bill + 1 overdue bill
      final b1 = _bill('b1', totalAmount: 2000);
      final b2 = _bill('b2', totalAmount: 3000);
      final payments = [
        ..._paidPayments('b1'),
        ..._overduePayments('b2'),
      ];
      MockBillData.replaceAll([b1, b2], payments);
    });

    test('totalApartments equals mocked apartment count', () {
      expect(provider.totalApartments, 1);
    });

    test('totalResidents counts only user-role users', () {
      expect(provider.totalResidents, 2);
    });

    test('totalAdmins counts only admin-role users', () {
      expect(provider.totalAdmins, 1);
    });

    test('totalBills equals mocked bill count', () {
      expect(provider.totalBills, 2);
    });

    test('paidBills counts bills where all payments are paid', () {
      expect(provider.paidBills, 1);
    });

    test('overdueBills counts bills with any overdue payment', () {
      expect(provider.overdueBills, 1);
    });

    test('totalRevenue sums collected amounts (paid × perFlatShare)', () {
      // b1: 2000/10 * 10 paid = 2000
      expect(provider.totalRevenue, 2000.0);
    });

    test('pendingRevenue sums uncollected amounts (unpaid × perFlatShare)', () {
      // b2: 3000/10 * 10 unpaid = 3000
      expect(provider.pendingRevenue, 3000.0);
    });
  });

  // ── Admin stats (per-apartment) ────────────────────────────────────────────

  group('DashboardProvider.adminStats', () {
    setUp(() {
      MockUsers.replaceAll([
        _user('u1', UserRole.superAdmin),
        _user('u2', UserRole.admin, aptId: 'apt1'),
        _user('u3', UserRole.user, aptId: 'apt1'),
        _user('u4', UserRole.user, aptId: 'apt1'),
        _user('u5', UserRole.user, aptId: 'apt1'),
      ]);

      // b1: 2 paid, 1 pending (partial)
      // b2: all overdue
      final b1 = _bill('b1', totalAmount: 3000, totalFlats: 3);
      final b2 = _bill('b2', totalAmount: 1500, totalFlats: 3);
      final payments = [
        BillPayment(id: 'p1', billId: 'b1', userId: 'u3', unitNumber: '101', status: BillStatus.paid),
        BillPayment(id: 'p2', billId: 'b1', userId: 'u4', unitNumber: '102', status: BillStatus.paid),
        BillPayment(id: 'p3', billId: 'b1', userId: 'u5', unitNumber: '103', status: BillStatus.pending),
        BillPayment(id: 'p4', billId: 'b2', userId: 'u3', unitNumber: '101', status: BillStatus.overdue),
        BillPayment(id: 'p5', billId: 'b2', userId: 'u4', unitNumber: '102', status: BillStatus.overdue),
        BillPayment(id: 'p6', billId: 'b2', userId: 'u5', unitNumber: '103', status: BillStatus.overdue),
      ];
      MockBillData.replaceAll([b1, b2], payments);
    });

    test('totalResidents counts only user-role members for the apartment', () {
      final stats = provider.adminStats('apt1');
      expect(stats['totalResidents'], 3);
    });

    test('totalBills equals bills for that apartment', () {
      final stats = provider.adminStats('apt1');
      expect(stats['totalBills'], 2);
    });

    test('overdueBills counts bills with any overdue payment', () {
      final stats = provider.adminStats('apt1');
      expect(stats['overdueBills'], 1);
    });

    test('collected sums paid × perFlatShare', () {
      final stats = provider.adminStats('apt1');
      // b1: 3000/3 = 1000/flat × 2 paid = 2000
      expect(stats['collected'], 2000.0);
    });

    test('paidPayments counts total paid payment records', () {
      final stats = provider.adminStats('apt1');
      // 2 from b1 + 0 from b2 = 2
      expect(stats['paidPayments'], 2);
    });

    test('collectionRate is paidPayments / totalPayments', () {
      final stats = provider.adminStats('apt1');
      // 2 paid out of 6 total = 0.333...
      expect(stats['collectionRate'], closeTo(2 / 6, 0.001));
    });

    test('collectionRate is 0 when no payments exist', () {
      MockBillData.replaceAll([], []);
      final stats = provider.adminStats('apt1');
      expect(stats['collectionRate'], 0.0);
    });

    test('collectionRate returns 1.0 via collectionRate() helper', () {
      MockUsers.replaceAll([_user('u3', UserRole.user, aptId: 'apt1')]);
      final bill = _bill('b1', totalAmount: 1000, totalFlats: 1);
      final payment = BillPayment(
        id: 'p1', billId: 'b1', userId: 'u3', unitNumber: '101',
        status: BillStatus.paid,
      );
      MockBillData.replaceAll([bill], [payment]);
      expect(provider.collectionRate('apt1'), 1.0);
    });
  });

  // ── Initialize / refresh ───────────────────────────────────────────────────

  group('DashboardProvider.initialize', () {
    test('initialize sets initialized to true', () async {
      expect(provider.initialized, isFalse);
      await provider.initialize();
      expect(provider.initialized, isTrue);
    });

    test('initialize is idempotent — second call is a no-op', () async {
      await provider.initialize();
      await provider.initialize(); // should not throw
      expect(provider.initialized, isTrue);
    });

    test('refresh resets and reinitializes', () async {
      await provider.initialize();
      provider.refresh();
      expect(provider.initialized, isTrue); // refresh calls initialize
    });
  });
}
