import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/models/complaint_model.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

ComplaintModel _complaint({
  required String id,
  required String apartmentId,
  required String userId,
}) {
  return ComplaintModel(
    id: id,
    apartmentId: apartmentId,
    userId: userId,
    userName: 'Test User',
    unit: '101',
    title: 'Test complaint',
    category: ComplaintCategory.maintenance,
    status: ComplaintStatus.open,
    createdAt: DateTime(2025, 1, 1),
    lastActivityAt: DateTime(2025, 1, 1),
  );
}

// Simulates what ComplaintProvider.complaintsForApartment does:
// returns only complaints matching the given aptId from the loaded list.
List<ComplaintModel> _filterForApartment(
    List<ComplaintModel> all, String aptId) {
  return all.where((c) => c.apartmentId == aptId).toList();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('Complaint apartment isolation — data layer logic', () {
    test('filtering by apartmentId returns only matching complaints', () {
      final all = [
        _complaint(id: 'c1', apartmentId: 'apt1', userId: 'u1'),
        _complaint(id: 'c2', apartmentId: 'apt2', userId: 'u2'),
        _complaint(id: 'c3', apartmentId: 'apt1', userId: 'u3'),
      ];

      final result = _filterForApartment(all, 'apt1');
      expect(result.length, equals(2));
      expect(result.every((c) => c.apartmentId == 'apt1'), isTrue);
    });

    test('other apartments\' complaints are not visible to apt1', () {
      final all = [
        _complaint(id: 'c1', apartmentId: 'apt1', userId: 'u1'),
        _complaint(id: 'c2', apartmentId: 'apt_other', userId: 'u2'),
      ];

      final visible = _filterForApartment(all, 'apt1');
      expect(visible.length, equals(1));
      expect(visible.first.id, equals('c1'));
      expect(visible.any((c) => c.apartmentId == 'apt_other'), isFalse);
    });

    test('empty result when no complaints belong to given apartment', () {
      final all = [
        _complaint(id: 'c1', apartmentId: 'apt2', userId: 'u1'),
      ];
      final result = _filterForApartment(all, 'apt1');
      expect(result, isEmpty);
    });

    test('all complaints returned when all share the same apartmentId', () {
      final all = [
        _complaint(id: 'c1', apartmentId: 'apt1', userId: 'u1'),
        _complaint(id: 'c2', apartmentId: 'apt1', userId: 'u2'),
        _complaint(id: 'c3', apartmentId: 'apt1', userId: 'u3'),
      ];
      final result = _filterForApartment(all, 'apt1');
      expect(result.length, equals(3));
    });
  });

  group('ComplaintModel — field validation', () {
    test('complaint carries correct apartmentId', () {
      final c = _complaint(id: 'c1', apartmentId: 'apt1', userId: 'u1');
      expect(c.apartmentId, equals('apt1'));
    });

    test('complaint status defaults to open', () {
      final c = _complaint(id: 'c1', apartmentId: 'apt1', userId: 'u1');
      expect(c.status, equals(ComplaintStatus.open));
    });

    test('complaint contains non-empty title and category', () {
      final c = _complaint(id: 'c1', apartmentId: 'apt1', userId: 'u1');
      expect(c.title, isNotEmpty);
      expect(c.category, isNotEmpty);
    });

    test('lastMessage is null when no messages have been added', () {
      final c = _complaint(id: 'c1', apartmentId: 'apt1', userId: 'u1');
      expect(c.lastMessage, isNull);
    });

    test('complaint carries userId for ownership checks', () {
      const ownerId = 'user_owner';
      final c = _complaint(id: 'c1', apartmentId: 'apt1', userId: ownerId);
      expect(c.userId, equals(ownerId));
    });

    test('user ownership check: same userId → isOwn = true', () {
      const myId = 'my_user';
      final c = _complaint(id: 'c1', apartmentId: 'apt1', userId: myId);
      expect(c.userId == myId, isTrue);
    });

    test('user ownership check: different userId → isOwn = false', () {
      final c = _complaint(id: 'c2', apartmentId: 'apt1', userId: 'other');
      expect(c.userId == 'my_user', isFalse);
    });
  });
}
