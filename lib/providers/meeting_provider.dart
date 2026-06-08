import 'package:flutter/material.dart';
import '../models/meeting_model.dart';
import '../models/notification_model.dart';
import '../core/theme/role_theme.dart';
import 'notification_provider.dart';

class MeetingProvider extends ChangeNotifier {
  final List<MeetingModel> _meetings = List.from(MockMeetings.all);

  List<MeetingModel> meetingsForApartment(String aptId) {
    final list =
        _meetings.where((m) => m.apartmentId == aptId).toList();
    list.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  List<MeetingModel> upcomingMeetings(String aptId) {
    final now = DateTime.now();
    return meetingsForApartment(aptId)
        .where((m) => m.scheduledAt.isAfter(now))
        .toList();
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> createMeeting({
    required String title,
    required String description,
    required DateTime scheduledAt,
    required String adminId,
    required String aptId,
    required NotificationProvider notificationProvider,
  }) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    final id = 'mt${DateTime.now().millisecondsSinceEpoch}';
    final meeting = MeetingModel(
      id: id,
      title: title,
      description: description,
      scheduledAt: scheduledAt,
      createdByAdminId: adminId,
      apartmentId: aptId,
    );

    _meetings.add(meeting);
    MockMeetings.all.add(meeting);

    final dateStr =
        '${scheduledAt.day} ${_monthName(scheduledAt.month)} ${scheduledAt.year}'
        ' at ${_timeStr(scheduledAt)}';

    notificationProvider.addNotification(NotificationModel(
      id: 'mn$id',
      title: 'Meeting Scheduled: $title',
      body: 'A meeting has been scheduled on $dateStr. $description',
      type: NotificationType.meeting,
      createdAt: DateTime.now(),
      isRead: false,
      targetRole: UserRole.user,
    ));

    _isLoading = false;
    notifyListeners();
  }

  static String _monthName(int month) => const [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][month];

  static String _timeStr(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$min $period';
  }
}
