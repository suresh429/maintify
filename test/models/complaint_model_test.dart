import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/models/complaint_model.dart';

void main() {
  // ── ComplaintCategory ──────────────────────────────────────────────────────

  group('ComplaintCategory', () {
    test('all list contains all 6 categories', () {
      expect(ComplaintCategory.all.length, 6);
      expect(ComplaintCategory.all, contains(ComplaintCategory.maintenance));
      expect(ComplaintCategory.all, contains(ComplaintCategory.billing));
      expect(ComplaintCategory.all, contains(ComplaintCategory.noise));
      expect(ComplaintCategory.all, contains(ComplaintCategory.parking));
      expect(ComplaintCategory.all, contains(ComplaintCategory.amenities));
      expect(ComplaintCategory.all, contains(ComplaintCategory.other));
    });
  });

  // ── ComplaintStatus constants ──────────────────────────────────────────────

  group('ComplaintStatus', () {
    test('constants have expected values', () {
      expect(ComplaintStatus.open, 'Open');
      expect(ComplaintStatus.inProgress, 'In Progress');
      expect(ComplaintStatus.resolved, 'Resolved');
    });
  });

  // ── ComplaintModel computed fields ─────────────────────────────────────────

  group('ComplaintModel', () {
    final msg1 = ComplaintMessage(
      id: 'm1',
      complaintId: 'c1',
      senderId: 'u1',
      senderName: 'User',
      isFromAdmin: false,
      content: 'First message',
      timestamp: DateTime(2026, 1, 1, 9),
    );
    final msg2 = ComplaintMessage(
      id: 'm2',
      complaintId: 'c1',
      senderId: 'u2',
      senderName: 'Admin',
      isFromAdmin: true,
      content: 'Admin reply',
      timestamp: DateTime(2026, 1, 1, 10),
    );

    test('lastMessage is null when messages list is empty', () {
      final complaint = ComplaintModel(
        id: 'c1',
        apartmentId: 'apt1',
        userId: 'u1',
        userName: 'User',
        unit: '101',
        title: 'Test',
        category: ComplaintCategory.other,
        status: ComplaintStatus.open,
        createdAt: DateTime(2026, 1, 1),
        messages: [],
      );
      expect(complaint.lastMessage, isNull);
    });

    test('lastMessage returns the last element in messages', () {
      final complaint = ComplaintModel(
        id: 'c1',
        apartmentId: 'apt1',
        userId: 'u1',
        userName: 'User',
        unit: '101',
        title: 'Test',
        category: ComplaintCategory.other,
        status: ComplaintStatus.open,
        createdAt: DateTime(2026, 1, 1),
        messages: [msg1, msg2],
      );
      expect(complaint.lastMessage?.id, 'm2');
    });

    test('lastMessagePreview shows content of last message', () {
      final complaint = ComplaintModel(
        id: 'c1',
        apartmentId: 'apt1',
        userId: 'u1',
        userName: 'User',
        unit: '101',
        title: 'Test',
        category: ComplaintCategory.other,
        status: ComplaintStatus.open,
        createdAt: DateTime(2026, 1, 1),
        messages: [msg1, msg2],
      );
      expect(complaint.lastMessagePreview, 'Admin reply');
    });

    test('lastMessagePreview returns "No messages yet" when empty', () {
      final complaint = ComplaintModel(
        id: 'c1',
        apartmentId: 'apt1',
        userId: 'u1',
        userName: 'User',
        unit: '101',
        title: 'Test',
        category: ComplaintCategory.other,
        status: ComplaintStatus.open,
        createdAt: DateTime(2026, 1, 1),
        messages: [],
      );
      expect(complaint.lastMessagePreview, 'No messages yet');
    });

    test('lastActivityAt returns last message timestamp when messages exist', () {
      final complaint = ComplaintModel(
        id: 'c1',
        apartmentId: 'apt1',
        userId: 'u1',
        userName: 'User',
        unit: '101',
        title: 'Test',
        category: ComplaintCategory.other,
        status: ComplaintStatus.open,
        createdAt: DateTime(2026, 1, 1),
        messages: [msg1, msg2],
      );
      expect(complaint.lastActivityAt, msg2.timestamp);
    });

    test('lastActivityAt falls back to createdAt when no messages', () {
      final createdAt = DateTime(2026, 3, 15);
      final complaint = ComplaintModel(
        id: 'c1',
        apartmentId: 'apt1',
        userId: 'u1',
        userName: 'User',
        unit: '101',
        title: 'Test',
        category: ComplaintCategory.other,
        status: ComplaintStatus.open,
        createdAt: createdAt,
        messages: [],
      );
      expect(complaint.lastActivityAt, createdAt);
    });

    test('status is mutable', () {
      final complaint = ComplaintModel(
        id: 'c1',
        apartmentId: 'apt1',
        userId: 'u1',
        userName: 'User',
        unit: '101',
        title: 'Test',
        category: ComplaintCategory.other,
        status: ComplaintStatus.open,
        createdAt: DateTime(2026, 1, 1),
        messages: [],
      );
      complaint.status = ComplaintStatus.resolved;
      expect(complaint.status, ComplaintStatus.resolved);
    });
  });

  // ── MockComplaints ─────────────────────────────────────────────────────────

  group('MockComplaints', () {
    test('all returns a non-empty list', () {
      expect(MockComplaints.all, isNotEmpty);
    });

    test('forApartment filters by apartmentId', () {
      final result = MockComplaints.forApartment('apt1');
      expect(result.every((c) => c.apartmentId == 'apt1'), isTrue);
    });

    test('forApartment is sorted by lastActivityAt descending', () {
      final result = MockComplaints.forApartment('apt1');
      for (int i = 0; i < result.length - 1; i++) {
        expect(
          result[i].lastActivityAt.isAfter(result[i + 1].lastActivityAt) ||
              result[i].lastActivityAt == result[i + 1].lastActivityAt,
          isTrue,
        );
      }
    });

    test('forUser filters by userId', () {
      final result = MockComplaints.forUser('u3');
      expect(result.every((c) => c.userId == 'u3'), isTrue);
    });

    test('findById returns correct complaint', () {
      final c = MockComplaints.findById('c1');
      expect(c, isNotNull);
      expect(c!.id, 'c1');
    });

    test('findById returns null for unknown id', () {
      expect(MockComplaints.findById('nonexistent'), isNull);
    });

    test('addComplaint inserts at front', () {
      final initial = MockComplaints.all.length;
      final newComplaint = ComplaintModel(
        id: 'test_new',
        apartmentId: 'apt1',
        userId: 'u5',
        userName: 'Chaitanya',
        unit: '201',
        title: 'Test complaint',
        category: ComplaintCategory.noise,
        status: ComplaintStatus.open,
        createdAt: DateTime.now(),
        messages: [],
      );
      MockComplaints.addComplaint(newComplaint);
      expect(MockComplaints.all.length, initial + 1);
      expect(MockComplaints.all.first.id, 'test_new');
      // Clean up
      MockComplaints.all.remove(newComplaint);
    });

    test('updateStatus mutates the complaint\'s status', () {
      MockComplaints.updateStatus('c1', ComplaintStatus.resolved);
      expect(MockComplaints.findById('c1')!.status, ComplaintStatus.resolved);
      // Restore
      MockComplaints.updateStatus('c1', ComplaintStatus.inProgress);
    });
  });
}
