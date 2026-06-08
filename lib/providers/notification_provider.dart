import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../core/theme/role_theme.dart';

class NotificationProvider extends ChangeNotifier {
  final List<NotificationModel> _notifications =
      List.from(MockNotifications.all);

  List<NotificationModel> forRole(UserRole role) =>
      _notifications.where((n) => n.targetRole == role).toList();

  int unreadCount(UserRole role) =>
      _notifications.where((n) => n.targetRole == role && !n.isRead).length;

  void markRead(String id) {
    final i = _notifications.indexWhere((n) => n.id == id);
    if (i != -1 && !_notifications[i].isRead) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void markAllRead(UserRole role) {
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].targetRole == role && !_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void addNotification(NotificationModel notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }
}
