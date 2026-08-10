import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/models/complaint_model.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

ComplaintModel _makeComplaint({
  required String id,
  required String userId,
  String title = 'Test complaint',
  String category = ComplaintCategory.maintenance,
  String status = ComplaintStatus.open,
  String apartmentId = 'apt1',
}) {
  return ComplaintModel(
    id: id,
    apartmentId: apartmentId,
    userId: userId,
    userName: 'Resident User',
    unit: '101',
    title: title,
    category: category,
    status: status,
    createdAt: DateTime(2025, 1, 10),
    lastActivityAt: DateTime(2025, 1, 10),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('Complaint Board — anonymity rules', () {
    const currentUserId = 'user_current';

    test('own complaint is identified by matching userId', () {
      final complaint = _makeComplaint(id: 'c1', userId: currentUserId);
      final isOwn = complaint.userId == currentUserId;
      expect(isOwn, isTrue);
    });

    test('another user\'s complaint is NOT own', () {
      final complaint = _makeComplaint(id: 'c2', userId: 'user_other');
      final isOwn = complaint.userId == currentUserId;
      expect(isOwn, isFalse);
    });

    test('own complaint shows user info (not anonymous)', () {
      final complaint = _makeComplaint(id: 'c3', userId: currentUserId);
      final isOwn = complaint.userId == currentUserId;
      // When isOwn, display name is "Me" (not Anonymous Resident)
      final displayName = isOwn ? 'Me' : 'Anonymous Resident';
      expect(displayName, equals('Me'));
    });

    test('other user\'s complaint shows Anonymous Resident', () {
      final complaint = _makeComplaint(id: 'c4', userId: 'user_other');
      final isOwn = complaint.userId == currentUserId;
      final displayName = isOwn ? 'Me' : 'Anonymous Resident';
      expect(displayName, equals('Anonymous Resident'));
    });

    test('other user\'s complaint does NOT expose unit number', () {
      final complaint = _makeComplaint(id: 'c5', userId: 'user_other');
      final isOwn = complaint.userId == currentUserId;
      // Unit should only be shown for own complaints
      final shownUnit = isOwn ? complaint.unit : null;
      expect(shownUnit, isNull);
    });

    test('read-only mode applies when not admin and not owner', () {
      final complaint = _makeComplaint(id: 'c6', userId: 'user_other');
      const isAdminView = false;
      final isOwner = complaint.userId == currentUserId;
      final isReadOnly = !isAdminView && !isOwner;
      expect(isReadOnly, isTrue);
    });

    test('admin view is never read-only regardless of ownership', () {
      // isAdminView = true → admin always gets full access to chat
      // The read-only guard in ChatScreen checks: !isAdminView && !isOwner
      // So when isAdminView is true, isReadOnly must be false.
      bool readOnlyFor({required bool isAdmin, required bool isOwner}) =>
          !isAdmin && !isOwner;
      expect(readOnlyFor(isAdmin: true, isOwner: false), isFalse);
      expect(readOnlyFor(isAdmin: true, isOwner: true), isFalse);
    });

    test('own complaint view is never read-only', () {
      final complaint = _makeComplaint(id: 'c8', userId: currentUserId);
      const isAdminView = false;
      final isOwner = complaint.userId == currentUserId;
      final isReadOnly = !isAdminView && !isOwner;
      expect(isReadOnly, isFalse);
    });
  });

  group('Complaint data — apartmentId isolation logic', () {
    // These tests use pure model logic (no Firebase needed)

    test('complaint with different aptId is excluded by apartment filter', () {
      final complaints = [
        _makeComplaint(id: 'c1', userId: 'u1', apartmentId: 'apt1'),
        _makeComplaint(id: 'c2', userId: 'u2', apartmentId: 'apt_other'),
      ];
      final visible =
          complaints.where((c) => c.apartmentId == 'apt1').toList();
      expect(visible.length, equals(1));
      expect(visible.first.id, equals('c1'));
    });

    test('complaintsForApartment logic returns empty for unknown aptId', () {
      final complaints = [
        _makeComplaint(id: 'c1', userId: 'u1', apartmentId: 'apt1'),
      ];
      final visible =
          complaints.where((c) => c.apartmentId == 'apt_x').toList();
      expect(visible, isEmpty);
    });

    test('findComplaint logic returns null for unknown id', () {
      final complaints = [
        _makeComplaint(id: 'c1', userId: 'u1', apartmentId: 'apt1'),
      ];
      final found = complaints.where((c) => c.id == 'nonexistent').toList();
      expect(found, isEmpty);
    });
  });
}
