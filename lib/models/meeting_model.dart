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
