import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/models/apartment_model.dart';

void main() {
  // ── ApartmentModel.hasPresident ────────────────────────────────────────────

  group('ApartmentModel.hasPresident', () {
    ApartmentModel makeApt({String? presidentId}) => ApartmentModel(
          id: 'apt1',
          name: 'Test Apt',
          code: 'TEST001',
          status: 'active',
          presidentId: presidentId,
          totalFlats: 10,
          createdAt: DateTime(2024),
        );

    test('true when presidentId is set and non-empty', () {
      expect(makeApt(presidentId: 'u1').hasPresident, isTrue);
    });

    test('false when presidentId is null', () {
      expect(makeApt(presidentId: null).hasPresident, isFalse);
    });

    test('false when presidentId is empty string', () {
      expect(makeApt(presidentId: '').hasPresident, isFalse);
    });
  });

  // ── ApartmentModel.copyWith ────────────────────────────────────────────────

  group('ApartmentModel.copyWith', () {
    final base = ApartmentModel(
      id: 'apt1',
      name: 'Samhith Residency',
      code: 'SAMH4721',
      status: 'active',
      presidentId: 'u2',
      presidentName: 'G. Srikanth',
      presidentEmail: 'admin@test.com',
      totalFlats: 10,
      occupiedFlats: 9,
      createdAt: DateTime(2021, 8, 15),
    );

    test('updates presidentId and presidentName', () {
      final updated = base.copyWith(
        presidentId: 'u5',
        presidentName: 'Chaitanya',
      );
      expect(updated.presidentId, 'u5');
      expect(updated.presidentName, 'Chaitanya');
      expect(updated.id, base.id);
      expect(updated.totalFlats, base.totalFlats);
    });

    test('clearPresident nullifies presidentId and presidentName', () {
      final cleared = base.copyWith(clearPresident: true);
      expect(cleared.presidentId, isNull);
      expect(cleared.presidentName, isNull);
      expect(cleared.hasPresident, isFalse);
    });

    test('updates occupiedFlats', () {
      final updated = base.copyWith(occupiedFlats: 10);
      expect(updated.occupiedFlats, 10);
    });

    test('updates status', () {
      final updated = base.copyWith(status: 'disabled');
      expect(updated.status, 'disabled');
    });

    test('no args preserves all fields', () {
      final copy = base.copyWith();
      expect(copy.id, base.id);
      expect(copy.presidentId, base.presidentId);
      expect(copy.totalFlats, base.totalFlats);
    });
  });

  // ── MockApartments ─────────────────────────────────────────────────────────

  group('MockApartments', () {
    test('all list is non-empty', () {
      expect(MockApartments.all, isNotEmpty);
    });

    test('findById returns correct apartment', () {
      final apt = MockApartments.findById('apt1');
      expect(apt, isNotNull);
      expect(apt!.name, 'Samhith Residency');
    });

    test('findById returns null for unknown id', () {
      expect(MockApartments.findById('nonexistent'), isNull);
    });

    test('withPresident returns only apartments that have a president', () {
      final result = MockApartments.withPresident;
      expect(result.every((a) => a.hasPresident), isTrue);
    });

    test('withoutPresident returns only apartments without a president', () {
      final result = MockApartments.withoutPresident;
      expect(result.every((a) => !a.hasPresident), isTrue);
    });

    test('assignPresident updates in-place', () {
      MockApartments.assignPresident('apt1', 'u99', 'New President');
      final apt = MockApartments.findById('apt1')!;
      expect(apt.presidentId, 'u99');
      expect(apt.presidentName, 'New President');
      // Restore
      MockApartments.assignPresident('apt1', 'u2', 'G. Srikanth');
    });

    test('replaceAll syncs the static list', () {
      final original = List<ApartmentModel>.from(MockApartments.all);
      final newApt = ApartmentModel(
        id: 'new_apt',
        name: 'New Block',
        code: 'NEW001',
        status: 'active',
        totalFlats: 5,
        createdAt: DateTime(2026),
      );
      MockApartments.replaceAll([newApt]);
      expect(MockApartments.all.length, 1);
      expect(MockApartments.all.first.id, 'new_apt');
      // Restore
      MockApartments.replaceAll(original);
    });

    test('all returns an unmodifiable view', () {
      final apt = MockApartments.all.first;
      expect(
        () => MockApartments.all.add(apt),
        throwsUnsupportedError,
      );
    });
  });
}
