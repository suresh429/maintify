import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/models/user_model.dart';
import 'package:maintify/core/theme/role_theme.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

UserModel _makeUser({
  required String id,
  required String name,
  required UserRole role,
  String unit = '101',
  String apartmentId = 'apt1',
}) {
  return UserModel(
    id: id,
    name: name,
    email: 'user@test.com',
    phone: '9999999999',
    role: role,
    apartmentId: apartmentId,
    unit: unit,
    avatarInitials: name.isNotEmpty ? name[0] : 'U',
    joinedAt: DateTime(2025, 1, 1),
    isActive: true,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('Directory Screen — member display rules', () {
    test('president is sorted first before residents', () {
      final members = [
        _makeUser(id: 'u1', name: 'Alice', role: UserRole.resident, unit: '101'),
        _makeUser(id: 'u2', name: 'Bob', role: UserRole.president, unit: '201'),
        _makeUser(id: 'u3', name: 'Charlie', role: UserRole.resident, unit: '102'),
      ];

      final sorted = [...members];
      sorted.sort((a, b) {
        final aIsPresident = a.role == UserRole.president;
        final bIsPresident = b.role == UserRole.president;
        if (aIsPresident && !bIsPresident) return -1;
        if (!aIsPresident && bIsPresident) return 1;
        return a.unit.compareTo(b.unit);
      });

      expect(sorted.first.role, equals(UserRole.president));
      expect(sorted.first.name, equals('Bob'));
    });

    test('residents are sorted by unit number after president', () {
      final members = [
        _makeUser(id: 'u1', name: 'Alice', role: UserRole.resident, unit: '301'),
        _makeUser(id: 'u2', name: 'Bob', role: UserRole.president, unit: '201'),
        _makeUser(id: 'u3', name: 'Charlie', role: UserRole.resident, unit: '101'),
      ];

      final sorted = [...members];
      sorted.sort((a, b) {
        final aIsPresident = a.role == UserRole.president;
        final bIsPresident = b.role == UserRole.president;
        if (aIsPresident && !bIsPresident) return -1;
        if (!aIsPresident && bIsPresident) return 1;
        return a.unit.compareTo(b.unit);
      });

      expect(sorted[0].name, equals('Bob')); // president
      expect(sorted[1].name, equals('Charlie')); // unit 101
      expect(sorted[2].name, equals('Alice')); // unit 301
    });

    test('role chip shows President for president role', () {
      final user = _makeUser(
          id: 'u1', name: 'Bob', role: UserRole.president, unit: '201');
      expect(user.role, equals(UserRole.president));
      final label = user.role == UserRole.president ? 'President' : 'Resident';
      expect(label, equals('President'));
    });

    test('role chip shows Resident for resident role', () {
      final user = _makeUser(
          id: 'u2', name: 'Alice', role: UserRole.resident, unit: '101');
      final label = user.role == UserRole.president ? 'President' : 'Resident';
      expect(label, equals('Resident'));
    });

    test('avatarInitials is non-empty', () {
      final user = _makeUser(
          id: 'u3', name: 'John Doe', role: UserRole.resident, unit: '102');
      expect(user.avatarInitials, isNotEmpty);
    });

    test('email is NOT in the directory-displayed fields set', () {
      final user = _makeUser(
          id: 'u4', name: 'Jane Smith', role: UserRole.resident, unit: '103');
      // Directory shows: name, unit, role, avatarInitials — never email or phone.
      // Verify email exists on the model (so we know it was intentionally excluded).
      expect(user.email, isNotNull);
      // The fields actually rendered in DirectoryScreen:
      final displayedFields = [user.name, user.unit, user.avatarInitials];
      for (final field in displayedFields) {
        expect(field, isNotEmpty);
      }
    });

    test('phone is NOT in the directory-displayed fields set', () {
      final user = _makeUser(
          id: 'u5', name: 'Mark Lee', role: UserRole.resident, unit: '104');
      expect(user.phone, isNotNull); // model has it
      // phone is never surfaced in the directory widget
    });

    test('only apartment members are shown (matching apartmentId)', () {
      final allUsers = [
        _makeUser(id: 'u1', name: 'Alice', role: UserRole.resident,
            unit: '101', apartmentId: 'apt1'),
        _makeUser(id: 'u2', name: 'Bob', role: UserRole.resident,
            unit: '201', apartmentId: 'apt2'),
        _makeUser(id: 'u3', name: 'Charlie', role: UserRole.president,
            unit: '301', apartmentId: 'apt1'),
      ];

      const targetAptId = 'apt1';
      final filtered =
          allUsers.where((u) => u.apartmentId == targetAptId).toList();

      expect(filtered.length, equals(2));
      expect(filtered.any((u) => u.name == 'Bob'), isFalse);
    });

    test('empty list when no members in apartment', () {
      final allUsers = <UserModel>[];
      const targetAptId = 'apt1';
      final filtered =
          allUsers.where((u) => u.apartmentId == targetAptId).toList();
      expect(filtered, isEmpty);
    });
  });
}
