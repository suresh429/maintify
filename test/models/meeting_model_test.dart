import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/models/meeting_model.dart';

void main() {
  // ── MeetingModel ───────────────────────────────────────────────────────────

  group('MeetingModel', () {
    final meeting = MeetingModel(
      id: 'mtg1',
      title: 'Monthly Residents Meeting',
      description: 'Discuss maintenance and upcoming bills.',
      scheduledAt: DateTime(2026, 6, 15, 10, 0),
      createdByAdminId: 'u2',
      apartmentId: 'apt1',
    );

    test('fields are accessible after construction', () {
      expect(meeting.id, 'mtg1');
      expect(meeting.title, 'Monthly Residents Meeting');
      expect(meeting.apartmentId, 'apt1');
      expect(meeting.createdByAdminId, 'u2');
    });

    test('toMap includes all expected keys', () {
      final map = meeting.toMap();
      expect(map.containsKey('title'), isTrue);
      expect(map.containsKey('description'), isTrue);
      expect(map.containsKey('scheduledAt'), isTrue);
      expect(map.containsKey('createdByAdminId'), isTrue);
      expect(map.containsKey('apartmentId'), isTrue);
    });

    test('toMap title matches meeting title', () {
      expect(meeting.toMap()['title'], 'Monthly Residents Meeting');
    });
  });

  // ── MockMeetings ───────────────────────────────────────────────────────────

  group('MockMeetings', () {
    test('all list is non-empty', () {
      expect(MockMeetings.all, isNotEmpty);
    });

    test('all meetings belong to apt1', () {
      expect(
        MockMeetings.all.every((m) => m.apartmentId == 'apt1'),
        isTrue,
      );
    });

    test('all meetings have non-empty title', () {
      expect(
        MockMeetings.all.every((m) => m.title.isNotEmpty),
        isTrue,
      );
    });
  });
}
