import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/role_theme.dart';

class NotificationType {
  static const String bill              = 'bill';
  static const String billUpdated       = 'bill_updated';
  static const String billDeleted       = 'bill_deleted';
  static const String payment           = 'payment';
  static const String paymentReceived   = 'payment_received';
  static const String paymentApproved   = 'payment_approved';
  static const String paymentRejected   = 'payment_rejected';
  static const String complaint         = 'complaint';
  static const String complaintReply    = 'complaint_reply';
  static const String complaintClosed   = 'complaint_closed';
  static const String meeting           = 'meeting';
  static const String meetingUpdated    = 'meeting_updated';
  static const String meetingCancelled  = 'meeting_cancelled';
  static const String presidentTransfer = 'president_transfer';
  static const String residentRegistered = 'resident_registered';
  static const String system            = 'system';
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final bool isRead;
  final UserRole targetRole;
  // Extended fields (populated by new Cloud Function triggers)
  final String? receiverId;
  final String? senderId;
  final String? apartmentId;
  final String? route;
  final String? referenceId;
  final String? referenceType;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.isRead,
    required this.targetRole,
    this.receiverId,
    this.senderId,
    this.apartmentId,
    this.route,
    this.referenceId,
    this.referenceType,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    UserRole role;
    switch (d['targetRole'] as String?) {
      case 'superAdmin':
        role = UserRole.superAdmin;
        break;
      case 'admin':
        role = UserRole.admin;
        break;
      default:
        role = UserRole.user;
    }
    return NotificationModel(
      id:            doc.id,
      title:         d['title']         as String?   ?? '',
      body:          d['body']          as String?   ?? '',
      type:          d['type']          as String?   ?? NotificationType.system,
      createdAt:     (d['createdAt']    as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead:        d['isRead']        as bool?     ?? false,
      targetRole:    role,
      receiverId:    d['receiverId']    as String?,
      senderId:      d['senderId']      as String?,
      apartmentId:   d['apartmentId']   as String?,
      route:         d['route']         as String?,
      referenceId:   d['referenceId']   as String?,
      referenceType: d['referenceType'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'title':         title,
        'body':          body,
        'type':          type,
        'createdAt':     Timestamp.fromDate(createdAt),
        'isRead':        isRead,
        'targetRole':    targetRole.name,
        'receiverId':    receiverId,
        'senderId':      senderId,
        'apartmentId':   apartmentId,
        'route':         route,
        'referenceId':   referenceId,
        'referenceType': referenceType,
      };

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id:            id,
      title:         title,
      body:          body,
      type:          type,
      createdAt:     createdAt,
      isRead:        isRead ?? this.isRead,
      targetRole:    targetRole,
      receiverId:    receiverId,
      senderId:      senderId,
      apartmentId:   apartmentId,
      route:         route,
      referenceId:   referenceId,
      referenceType: referenceType,
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
