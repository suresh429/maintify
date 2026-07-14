import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/models/notification_model.dart';
import 'package:maintify/core/theme/role_theme.dart';

void main() {
  // ── NotificationType constants ─────────────────────────────────────────────

  group('NotificationType', () {
    test('constants have expected string values', () {
      expect(NotificationType.bill, 'bill');
      expect(NotificationType.payment, 'payment');
      expect(NotificationType.complaint, 'complaint');
      expect(NotificationType.system, 'system');
      expect(NotificationType.meeting, 'meeting');
    });
  });

  // ── NotificationModel construction ────────────────────────────────────────

  group('NotificationModel', () {
    final base = NotificationModel(
      id: 'n1',
      title: 'New Bill',
      body: 'May bill is due.',
      type: NotificationType.bill,
      createdAt: DateTime(2026, 5, 1),
      isRead: false,
      targetRole: UserRole.user,
    );

    test('fields are accessible after construction', () {
      expect(base.id, 'n1');
      expect(base.title, 'New Bill');
      expect(base.type, NotificationType.bill);
      expect(base.isRead, isFalse);
      expect(base.targetRole, UserRole.user);
    });

    test('copyWith(isRead: true) marks as read', () {
      final read = base.copyWith(isRead: true);
      expect(read.isRead, isTrue);
      expect(read.id, base.id);
      expect(read.title, base.title);
    });

    test('copyWith with no args preserves all fields', () {
      final copy = base.copyWith();
      expect(copy.id, base.id);
      expect(copy.isRead, base.isRead);
    });

    test('toMap includes all required keys', () {
      final map = base.toMap();
      expect(map.containsKey('title'), isTrue);
      expect(map.containsKey('body'), isTrue);
      expect(map.containsKey('type'), isTrue);
      expect(map.containsKey('isRead'), isTrue);
      expect(map.containsKey('targetRole'), isTrue);
      expect(map.containsKey('createdAt'), isTrue);
    });

    test('toMap encodes targetRole as its name string', () {
      final map = base.toMap();
      expect(map['targetRole'], 'user');
    });

    test('toMap for admin role encodes "admin"', () {
      final adminNotif = NotificationModel(
        id: 'n2',
        title: 'Payment',
        body: 'Received',
        type: NotificationType.payment,
        createdAt: DateTime(2026, 5, 1),
        isRead: false,
        targetRole: UserRole.admin,
      );
      expect(adminNotif.toMap()['targetRole'], 'admin');
    });
  });

  // ── MockNotifications ──────────────────────────────────────────────────────

  group('MockNotifications', () {
    test('all list is non-empty', () {
      expect(MockNotifications.all, isNotEmpty);
    });

    test('contains notifications for all three roles', () {
      final roles = MockNotifications.all.map((n) => n.targetRole).toSet();
      expect(roles, contains(UserRole.superAdmin));
      expect(roles, contains(UserRole.admin));
      expect(roles, contains(UserRole.user));
    });

    test('some notifications start as unread', () {
      expect(
        MockNotifications.all.any((n) => !n.isRead),
        isTrue,
      );
    });

    test('some notifications start as read', () {
      expect(
        MockNotifications.all.any((n) => n.isRead),
        isTrue,
      );
    });

    test('all notifications have non-empty title and body', () {
      for (final n in MockNotifications.all) {
        expect(n.title, isNotEmpty, reason: 'id=${n.id}');
        expect(n.body, isNotEmpty, reason: 'id=${n.id}');
      }
    });
  });
}
