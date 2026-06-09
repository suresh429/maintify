import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meeting_model.dart';
import '../models/notification_model.dart';
import '../core/theme/role_theme.dart';
import '../core/services/firestore_service.dart';
import 'notification_provider.dart';

class MeetingProvider extends ChangeNotifier {
  final FirestoreService _fs = FirestoreService();

  List<MeetingModel> _meetings = [];
  StreamSubscription<List<MeetingModel>>? _sub;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  // ── Stream management ─────────────────────────────────────────────────────

  void startListening(String aptId) {
    _sub?.cancel();
    _sub = _fs.streamMeetingsForApartment(aptId).listen((list) {
      _meetings = list;
      notifyListeners();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  List<MeetingModel> meetingsForApartment(String aptId) {
    final list = _meetings
        .where((m) => m.apartmentId == aptId)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  List<MeetingModel> upcomingMeetings(String aptId) {
    final now = DateTime.now();
    return meetingsForApartment(aptId)
        .where((m) => m.scheduledAt.isAfter(now))
        .toList();
  }

  // ── Create meeting + push notification ───────────────────────────────────

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

    final docRef = await _fs.createMeeting({
      'apartmentId': aptId,
      'title': title,
      'description': description,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'createdByAdminId': adminId,
    });

    // Push a notification to all users in the apartment
    final dateStr =
        '${scheduledAt.day} ${_monthName(scheduledAt.month)} ${scheduledAt.year}'
        ' at ${_timeStr(scheduledAt)}';

    await notificationProvider.addAndPersistNotification(
      title: 'Meeting Scheduled: $title',
      body:
          'A meeting has been scheduled on $dateStr. $description',
      type: NotificationType.meeting,
      targetRole: UserRole.user,
    );

    // Optimistic local update
    final meeting = MeetingModel(
      id: docRef.id,
      title: title,
      description: description,
      scheduledAt: scheduledAt,
      createdByAdminId: adminId,
      apartmentId: aptId,
    );
    _meetings.add(meeting);
    MockMeetings.all.add(meeting);

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
