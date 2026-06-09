import 'package:cloud_firestore/cloud_firestore.dart';

class ComplaintStatus {
  static const String open = 'Open';
  static const String inProgress = 'In Progress';
  static const String resolved = 'Resolved';
}

class ComplaintCategory {
  static const String maintenance = 'Maintenance';
  static const String billing = 'Billing';
  static const String noise = 'Noise';
  static const String parking = 'Parking';
  static const String amenities = 'Amenities';
  static const String other = 'Other';

  static const List<String> all = [
    maintenance,
    billing,
    noise,
    parking,
    amenities,
    other,
  ];
}

class ComplaintMessage {
  final String id;
  final String complaintId;
  final String senderId;
  final String senderName;
  final bool isFromAdmin;
  final String content;
  final DateTime timestamp;

  const ComplaintMessage({
    required this.id,
    required this.complaintId,
    required this.senderId,
    required this.senderName,
    required this.isFromAdmin,
    required this.content,
    required this.timestamp,
  });

  factory ComplaintMessage.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ComplaintMessage(
      id: doc.id,
      complaintId: d['complaintId'] as String? ?? '',
      senderId: d['senderId'] as String? ?? '',
      senderName: d['senderName'] as String? ?? '',
      isFromAdmin: d['isFromAdmin'] as bool? ?? false,
      content: d['content'] as String? ?? '',
      timestamp:
          (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'complaintId': complaintId,
        'senderId': senderId,
        'senderName': senderName,
        'isFromAdmin': isFromAdmin,
        'content': content,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}

class ComplaintModel {
  final String id;
  final String apartmentId;
  final String userId;
  final String userName;
  final String unit;
  final String title;
  final String category;
  String status;
  final DateTime createdAt;
  final List<ComplaintMessage> messages;

  ComplaintModel({
    required this.id,
    required this.apartmentId,
    required this.userId,
    required this.userName,
    required this.unit,
    required this.title,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.messages,
  });

  factory ComplaintModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ComplaintModel(
      id: doc.id,
      apartmentId: d['apartmentId'] as String? ?? '',
      userId: d['userId'] as String? ?? '',
      userName: d['userName'] as String? ?? '',
      unit: d['unit'] as String? ?? '',
      title: d['title'] as String? ?? '',
      category: d['category'] as String? ?? '',
      status: d['status'] as String? ?? ComplaintStatus.open,
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      messages: const [], // messages loaded separately from subcollection
    );
  }

  Map<String, dynamic> toMap() => {
        'apartmentId': apartmentId,
        'userId': userId,
        'userName': userName,
        'unit': unit,
        'title': title,
        'category': category,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastActivityAt': Timestamp.fromDate(lastActivityAt),
      };

  ComplaintMessage? get lastMessage =>
      messages.isEmpty ? null : messages.last;

  String get lastMessagePreview =>
      lastMessage?.content ?? 'No messages yet';

  DateTime get lastActivityAt =>
      lastMessage?.timestamp ?? createdAt;
}

// ── Mock Data ─────────────────────────────────────────────────────────────────

class MockComplaints {
  static final List<ComplaintModel> _all = [
    ComplaintModel(
      id: 'c1',
      apartmentId: 'apt1',
      userId: 'u3',
      userName: 'Rohit',
      unit: '101',
      title: 'Water leakage in bathroom ceiling',
      category: ComplaintCategory.maintenance,
      status: ComplaintStatus.inProgress,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      messages: [
        ComplaintMessage(
          id: 'm1',
          complaintId: 'c1',
          senderId: 'u3',
          senderName: 'Rohit',
          isFromAdmin: false,
          content:
              'There is a water leakage from the bathroom ceiling. Water is dripping since yesterday night. Please look into this urgently.',
          timestamp:
              DateTime.now().subtract(const Duration(days: 5, hours: 2)),
        ),
        ComplaintMessage(
          id: 'm2',
          complaintId: 'c1',
          senderId: 'u2',
          senderName: 'G. Srikanth',
          isFromAdmin: true,
          content:
              'Hello Rohit, thank you for reporting this. I have noted the issue and will send a plumber tomorrow morning.',
          timestamp:
              DateTime.now().subtract(const Duration(days: 4, hours: 20)),
        ),
        ComplaintMessage(
          id: 'm3',
          complaintId: 'c1',
          senderId: 'u3',
          senderName: 'Rohit',
          isFromAdmin: false,
          content:
              'The leak is getting worse. The floor is wet now. Please send someone today itself.',
          timestamp:
              DateTime.now().subtract(const Duration(days: 4, hours: 10)),
        ),
        ComplaintMessage(
          id: 'm4',
          complaintId: 'c1',
          senderId: 'u2',
          senderName: 'G. Srikanth',
          isFromAdmin: true,
          content:
              'Understood. I have contacted the plumber and he will visit by 3 PM today. Please be available.',
          timestamp: DateTime.now().subtract(const Duration(days: 4, hours: 8)),
        ),
        ComplaintMessage(
          id: 'm5',
          complaintId: 'c1',
          senderId: 'u3',
          senderName: 'Rohit',
          isFromAdmin: false,
          content: 'The plumber came and did a temporary fix. Still waiting for permanent repair.',
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ],
    ),
    ComplaintModel(
      id: 'c2',
      apartmentId: 'apt1',
      userId: 'u3',
      userName: 'Rohit',
      unit: '101',
      title: 'Gym equipment not working',
      category: ComplaintCategory.amenities,
      status: ComplaintStatus.open,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      messages: [
        ComplaintMessage(
          id: 'm6',
          complaintId: 'c2',
          senderId: 'u3',
          senderName: 'Rohit',
          isFromAdmin: false,
          content:
              'The treadmill in the gym is not working since last week. Also the AC in the gym is making a lot of noise.',
          timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
        ),
        ComplaintMessage(
          id: 'm7',
          complaintId: 'c2',
          senderId: 'u2',
          senderName: 'G. Srikanth',
          isFromAdmin: true,
          content:
              'Hi Rohit, I will check with the service team and get back to you shortly.',
          timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 22)),
        ),
        ComplaintMessage(
          id: 'm8',
          complaintId: 'c2',
          senderId: 'u3',
          senderName: 'Rohit',
          isFromAdmin: false,
          content: 'Please let me know the timeline, many residents use the gym daily.',
          timestamp: DateTime.now().subtract(const Duration(hours: 18)),
        ),
      ],
    ),
    ComplaintModel(
      id: 'c3',
      apartmentId: 'apt1',
      userId: 'u4',
      userName: 'Ravi',
      unit: '102',
      title: 'Parking slot occupied by unknown vehicle',
      category: ComplaintCategory.parking,
      status: ComplaintStatus.resolved,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      messages: [
        ComplaintMessage(
          id: 'm9',
          complaintId: 'c3',
          senderId: 'u4',
          senderName: 'Ravi',
          isFromAdmin: false,
          content:
              'My allocated parking slot has been occupied by an unknown car (TS-09-AB-1234) since this morning. I cannot park my vehicle.',
          timestamp:
              DateTime.now().subtract(const Duration(days: 10, hours: 5)),
        ),
        ComplaintMessage(
          id: 'm10',
          complaintId: 'c3',
          senderId: 'u2',
          senderName: 'G. Srikanth',
          isFromAdmin: true,
          content:
              'Hi Ravi, we will immediately check who owns that vehicle and get it cleared. Please use the visitor parking temporarily.',
          timestamp:
              DateTime.now().subtract(const Duration(days: 10, hours: 4)),
        ),
        ComplaintMessage(
          id: 'm11',
          complaintId: 'c3',
          senderId: 'u2',
          senderName: 'G. Srikanth',
          isFromAdmin: true,
          content:
              'The vehicle owner has been contacted. They will move it within 30 minutes. Sorry for the inconvenience.',
          timestamp:
              DateTime.now().subtract(const Duration(days: 10, hours: 3)),
        ),
        ComplaintMessage(
          id: 'm12',
          complaintId: 'c3',
          senderId: 'u4',
          senderName: 'Ravi',
          isFromAdmin: false,
          content: 'Thank you for the quick action! The slot is now cleared.',
          timestamp:
              DateTime.now().subtract(const Duration(days: 10, hours: 2)),
        ),
      ],
    ),
    ComplaintModel(
      id: 'c4',
      apartmentId: 'apt1',
      userId: 'u5',
      userName: 'Chaitanya',
      unit: '201',
      title: 'Noise complaint — late night disturbance',
      category: ComplaintCategory.noise,
      status: ComplaintStatus.open,
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      messages: [
        ComplaintMessage(
          id: 'm13',
          complaintId: 'c4',
          senderId: 'u5',
          senderName: 'Chaitanya',
          isFromAdmin: false,
          content:
              'There has been loud music playing after 11 PM for the past 3 nights. It is disturbing the sleep of many residents. Please take action.',
          timestamp: DateTime.now().subtract(const Duration(hours: 6)),
        ),
      ],
    ),
  ];

  static List<ComplaintModel> get all => _all;

  static List<ComplaintModel> forApartment(String aptId) =>
      _all.where((c) => c.apartmentId == aptId).toList()
        ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));

  static List<ComplaintModel> forUser(String userId) =>
      _all.where((c) => c.userId == userId).toList()
        ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));

  static ComplaintModel? findById(String id) =>
      _all.where((c) => c.id == id).firstOrNull;

  static void addComplaint(ComplaintModel complaint) {
    _all.insert(0, complaint);
  }

  static void addMessage(String complaintId, ComplaintMessage message) {
    final complaint = findById(complaintId);
    complaint?.messages.add(message);
  }

  static void updateStatus(String complaintId, String status) {
    final complaint = findById(complaintId);
    if (complaint != null) complaint.status = status;
  }
}
