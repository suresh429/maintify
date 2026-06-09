import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingModel {
  final String id;
  final String title;
  final String description;
  final DateTime scheduledAt;
  final String createdByAdminId;
  final String apartmentId;

  const MeetingModel({
    required this.id,
    required this.title,
    required this.description,
    required this.scheduledAt,
    required this.createdByAdminId,
    required this.apartmentId,
  });

  factory MeetingModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MeetingModel(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      scheduledAt:
          (d['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdByAdminId: d['createdByAdminId'] as String? ?? '',
      apartmentId: d['apartmentId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'createdByAdminId': createdByAdminId,
        'apartmentId': apartmentId,
      };
}

class MockMeetings {
  static final List<MeetingModel> all = [
    MeetingModel(
      id: 'mt1',
      title: 'Monthly Maintenance Review',
      description:
          'Discuss upcoming maintenance work and budget for next month.',
      scheduledAt: DateTime.now().add(const Duration(days: 3)),
      createdByAdminId: 'u2',
      apartmentId: 'apt1',
    ),
    MeetingModel(
      id: 'mt2',
      title: 'Annual General Meeting',
      description:
          'Review annual financials, elect office bearers, and plan for the year ahead.',
      scheduledAt: DateTime.now().add(const Duration(days: 14)),
      createdByAdminId: 'u2',
      apartmentId: 'apt1',
    ),
  ];
}
