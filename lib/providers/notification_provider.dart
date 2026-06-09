import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../core/theme/role_theme.dart';
import '../core/services/firestore_service.dart';

class NotificationProvider extends ChangeNotifier {
  final FirestoreService _fs = FirestoreService();

  final List<NotificationModel> _notifications = [];
  StreamSubscription<List<NotificationModel>>? _sub;

  // ── Stream management ─────────────────────────────────────────────────────

  void startListening(UserRole role) {
    _sub?.cancel();
    _sub = _fs.streamNotificationsForRole(role).listen((list) {
      _notifications
        ..clear()
        ..addAll(list);
      notifyListeners();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Queries (same API as before) ──────────────────────────────────────────

  List<NotificationModel> forRole(UserRole role) =>
      _notifications.where((n) => n.targetRole == role).toList();

  int unreadCount(UserRole role) =>
      _notifications.where((n) => n.targetRole == role && !n.isRead).length;

  // ── Mutations ─────────────────────────────────────────────────────────────

  void markRead(String id) {
    final i = _notifications.indexWhere((n) => n.id == id);
    if (i != -1 && !_notifications[i].isRead) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
      _fs.markNotificationRead(id).ignore();
      notifyListeners();
    }
  }

  void markAllRead(UserRole role) {
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].targetRole == role &&
          !_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) {
      _fs.markAllNotificationsRead(role).ignore();
      notifyListeners();
    }
  }

  /// Adds a notification locally AND persists it to Firestore.
  /// Used by MeetingProvider / BillProvider when creating items.
  Future<void> addAndPersistNotification({
    required String title,
    required String body,
    required String type,
    required UserRole targetRole,
  }) async {
    final data = {
      'title': title,
      'body': body,
      'type': type,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'isRead': false,
      'targetRole': targetRole.name,
    };
    await _fs.addNotification(data);
    // Firestore stream will auto-update _notifications via startListening
    // but also add optimistically so the badge updates immediately:
    final localNotif = NotificationModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      isRead: false,
      targetRole: targetRole,
    );
    _notifications.insert(0, localNotif);
    notifyListeners();
  }

  /// Adds notification only to in-memory list (no Firestore write).
  /// Used for quick optimistic updates within the current session.
  void addNotification(NotificationModel notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }
}
