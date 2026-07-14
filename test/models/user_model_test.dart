import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/models/user_model.dart';
import 'package:maintify/core/theme/role_theme.dart';

void main() {
  // ── UserModel.roleLabel ────────────────────────────────────────────────────

  group('UserModel.roleLabel', () {
    UserModel makeUser(UserRole role) => UserModel(
          id: 'u1',
          name: 'Test',
          email: 'test@test.com',
          phone: '',
          role: role,
          unit: '101',
          avatarInitials: 'T',
          joinedAt: DateTime(2024, 1, 1),
        );

    test('superAdmin → "Super Admin"', () {
      expect(makeUser(UserRole.superAdmin).roleLabel, 'Super Admin');
    });

    test('admin → "President"', () {
      expect(makeUser(UserRole.admin).roleLabel, 'President');
    });

    test('user → "Resident"', () {
      expect(makeUser(UserRole.user).roleLabel, 'Resident');
    });
  });

  // ── UserModel.copyWith ─────────────────────────────────────────────────────

  group('UserModel.copyWith', () {
    final base = UserModel(
      id: 'u1',
      name: 'Rohit',
      email: 'rohit@test.com',
      phone: '+91 00000',
      role: UserRole.user,
      unit: '101',
      avatarInitials: 'RO',
      joinedAt: _epoch,
    );

    test('copies with new role, preserves other fields', () {
      final updated = base.copyWith(role: UserRole.admin);
      expect(updated.role, UserRole.admin);
      expect(updated.id, base.id);
      expect(updated.name, base.name);
      expect(updated.email, base.email);
    });

    test('no args → identical copy', () {
      final copy = base.copyWith();
      expect(copy.id, base.id);
      expect(copy.role, base.role);
    });
  });

  // ── UserModel.isActive default ─────────────────────────────────────────────

  test('isActive defaults to true', () {
    final user = UserModel(
      id: 'u1',
      name: 'X',
      email: 'x@x.com',
      phone: '',
      role: UserRole.user,
      unit: '101',
      avatarInitials: 'X',
      joinedAt: _epoch,
    );
    expect(user.isActive, isTrue);
  });

  // ── MockUsers ──────────────────────────────────────────────────────────────

  group('MockUsers', () {
    test('contains at least one super admin', () {
      expect(
        MockUsers.all.where((u) => u.role == UserRole.superAdmin),
        isNotEmpty,
      );
    });

    test('residents getter returns only user-role entries', () {
      expect(
        MockUsers.residents.every((u) => u.role == UserRole.user),
        isTrue,
      );
    });

    test('admins getter returns only admin-role entries', () {
      expect(
        MockUsers.admins.every((u) => u.role == UserRole.admin),
        isTrue,
      );
    });

    test('findByEmail returns correct user', () {
      final user = MockUsers.findByEmail('superadmin@test.com');
      expect(user, isNotNull);
      expect(user!.role, UserRole.superAdmin);
    });

    test('findByEmail returns null for unknown email', () {
      expect(MockUsers.findByEmail('nobody@unknown.com'), isNull);
    });

    test('findById returns correct user', () {
      final user = MockUsers.findById('u2');
      expect(user, isNotNull);
      expect(user!.role, UserRole.admin);
    });

    test('findById returns null for unknown id', () {
      expect(MockUsers.findById('zzz'), isNull);
    });

    test('residentsForApartment filters by apartmentId', () {
      final residents = MockUsers.residentsForApartment('apt1');
      expect(residents, isNotEmpty);
      expect(residents.every((u) => u.apartmentId == 'apt1'), isTrue);
      expect(residents.every((u) => u.role == UserRole.user), isTrue);
    });

    test('presidentFor returns admin for matching apartment', () {
      final president = MockUsers.presidentFor('apt1');
      expect(president, isNotNull);
      expect(president!.role, UserRole.admin);
      expect(president.apartmentId, 'apt1');
    });

    test('presidentFor returns null for unknown apartment', () {
      expect(MockUsers.presidentFor('apt_nonexistent'), isNull);
    });

    test('updateRole changes a user\'s role in-place', () {
      // Save original role to restore after test
      final u3 = MockUsers.findById('u3')!;
      final original = u3.role;
      MockUsers.updateRole('u3', UserRole.admin);
      expect(MockUsers.findById('u3')!.role, UserRole.admin);
      // Restore
      MockUsers.updateRole('u3', original);
    });

    test('replaceAll syncs the static list', () {
      final original = List<UserModel>.from(MockUsers.all);
      final replacement = [
        UserModel(
          id: 'new1',
          name: 'NewUser',
          email: 'new@test.com',
          phone: '',
          role: UserRole.user,
          unit: '999',
          avatarInitials: 'NU',
          joinedAt: DateTime(2024),
        ),
      ];
      MockUsers.replaceAll(replacement);
      expect(MockUsers.all.length, 1);
      expect(MockUsers.all.first.id, 'new1');
      // Restore
      MockUsers.replaceAll(original);
    });
  });
}

// Shared sentinel date used across const-like model constructions.
final _epoch = DateTime(2020);
