import '../core/theme/role_theme.dart';

class NotificationType {
  static const String bill = 'bill';
  static const String payment = 'payment';
  static const String complaint = 'complaint';
  static const String system = 'system';
  static const String meeting = 'meeting';
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final bool isRead;
  final UserRole targetRole;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.isRead,
    required this.targetRole,
  });

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      title: title,
      body: body,
      type: type,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      targetRole: targetRole,
    );
  }
}

class MockNotifications {
  static final List<NotificationModel> all = [
    // ── Super Admin notifications ────────────────────────────
    NotificationModel(
      id: 'n1',
      title: 'Apartment Registered',
      body: 'Samhith Residency has been successfully registered.',
      type: NotificationType.system,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
      targetRole: UserRole.superAdmin,
    ),
    NotificationModel(
      id: 'n2',
      title: 'President Assigned',
      body: 'G. Srikanth has been assigned as President of Samhith Residency.',
      type: NotificationType.system,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: false,
      targetRole: UserRole.superAdmin,
    ),
    NotificationModel(
      id: 'n3',
      title: 'Revenue Milestone',
      body: 'May 2026: ₹3,200 collected across all properties.',
      type: NotificationType.bill,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: false,
      targetRole: UserRole.superAdmin,
    ),
    NotificationModel(
      id: 'n4',
      title: 'New Resident Added',
      body: '1 new resident added to Samhith Residency.',
      type: NotificationType.system,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: false,
      targetRole: UserRole.superAdmin,
    ),

    // ── Admin notifications ──────────────────────────────────
    NotificationModel(
      id: 'n5',
      title: 'Bill Created',
      body: 'Lift Maintenance bill of ₹2,000 has been created for all flats.',
      type: NotificationType.bill,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
      targetRole: UserRole.admin,
    ),
    NotificationModel(
      id: 'n6',
      title: 'Payment Received',
      body: 'Rohit (Flat 101) paid ₹200 for Lift Maintenance.',
      type: NotificationType.payment,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
      targetRole: UserRole.admin,
    ),
    NotificationModel(
      id: 'n7',
      title: 'New Complaint',
      body: 'Ravi from Flat 102 submitted a new complaint. Tap to review.',
      type: NotificationType.complaint,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      isRead: false,
      targetRole: UserRole.admin,
    ),
    NotificationModel(
      id: 'n8',
      title: 'Overdue Alert',
      body: 'Security Charges (Apr 2026) is overdue for 3 flats.',
      type: NotificationType.bill,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
      targetRole: UserRole.admin,
    ),
    NotificationModel(
      id: 'n9',
      title: 'Payment Received',
      body: 'Sai (Flat 301) paid ₹200 for Lift Maintenance.',
      type: NotificationType.payment,
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      isRead: false,
      targetRole: UserRole.admin,
    ),

    // ── User notifications ───────────────────────────────────
    NotificationModel(
      id: 'n10',
      title: 'New Bill Raised',
      body: 'Water Charges of ₹150 is due on Jun 30, 2026.',
      type: NotificationType.bill,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
      targetRole: UserRole.user,
    ),
    NotificationModel(
      id: 'n11',
      title: 'Payment Confirmed',
      body: 'Your payment of ₹100 for Cleaning Fund has been confirmed.',
      type: NotificationType.payment,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
      targetRole: UserRole.user,
    ),
    NotificationModel(
      id: 'n12',
      title: 'Bill Overdue',
      body: 'Security Charges ₹300 from Apr 2026 is overdue. Please pay now.',
      type: NotificationType.bill,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
      targetRole: UserRole.user,
    ),
    NotificationModel(
      id: 'n13',
      title: 'Complaint Updated',
      body: 'Your complaint has been updated to "In Progress" by the President.',
      type: NotificationType.complaint,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: false,
      targetRole: UserRole.user,
    ),
  ];
}
