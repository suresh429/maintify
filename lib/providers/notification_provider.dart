import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../core/theme/role_theme.dart';
import '../core/services/firestore_service.dart';

/// Represents one visible row in the resident notification list.
///
/// For complaint notifications sharing a [groupReferenceId], a single
/// [NotifDisplayItem] covers the entire group (latest activity shown,
/// unread count as badge). For all other notification types, each
/// [NotifDisplayItem] maps 1-to-1 with one [NotificationModel].
class NotifDisplayItem {
  /// The notification used for display — the most-recent in a group, or the
  /// only one for single items.
  final NotificationModel representative;

  /// Non-null when this item is a grouped complaint.
  /// Equals the shared [NotificationModel.referenceId].
  final String? groupReferenceId;

  /// Number of unread notifications belonging to this item.
  /// 0 or 1 for singles; 0..N for groups.
  final int unreadCount;

  /// IDs of every notification document in this item.
  /// Used to mark them all read on tap.
  final List<String> memberIds;

  const NotifDisplayItem._({
    required this.representative,
    required this.groupReferenceId,
    required this.unreadCount,
    required this.memberIds,
  });

  factory NotifDisplayItem.single(NotificationModel n) => NotifDisplayItem._(
        representative: n,
        groupReferenceId: null,
        unreadCount: n.isRead ? 0 : 1,
        memberIds: [n.id],
      );

  factory NotifDisplayItem.group({
    required NotificationModel latest,
    required String referenceId,
    required int unreadCount,
    required List<String> memberIds,
  }) =>
      NotifDisplayItem._(
        representative: latest,
        groupReferenceId: referenceId,
        unreadCount: unreadCount,
        memberIds: memberIds,
      );

  bool get isGrouped => groupReferenceId != null;
  bool get hasUnread => unreadCount > 0;
}

class NotificationProvider extends ChangeNotifier {
  final FirestoreService _fs = FirestoreService();

  final List<NotificationModel> _notifications = [];
  StreamSubscription<List<NotificationModel>>? _sub;

  // ── Stream management ─────────────────────────────────────────────────────

  /// Starts a real-time stream scoped to this specific user's notifications.
  /// Each notification doc has `userId == currentUser.id`.
  void startListening(String userId) {
    // Remove any legacy docs (targetRole only, no userId) so they don't pollute
    // future queries. Runs on every login; no-op when there is nothing to clean.
    _fs.cleanupLegacyNotifications()
        .catchError((e) => debugPrint('[CLEANUP] Legacy notification error: $e'));
    _sub?.cancel();
    _sub = _fs.streamNotificationsForUser(userId).listen((list) {
      debugPrint('[REALTIME] Listener triggered — userId: $userId');
      debugPrint('[REALTIME] Docs count: ${list.length}');
      _notifications
        ..clear()
        ..addAll(list);
      notifyListeners();
    }, onError: (e) {
      debugPrint('[REALTIME] Notifications stream ERROR (userId: $userId): $e');
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Resident grouped view ─────────────────────────────────────────────────

  /// Returns a display-ready list for the Resident notification screen.
  ///
  /// Complaint notifications (referenceType == 'complaint', non-null referenceId)
  /// are collapsed into one [NotifDisplayItem] per complaint, keyed by referenceId.
  /// All other notifications appear as individual [NotifDisplayItem.single] entries.
  /// Sorted by each item's latest [createdAt] descending (newest first).
  List<NotifDisplayItem> groupedForResident() {
    final Map<String, List<NotificationModel>> complaintGroups = {};
    final List<NotificationModel> singles = [];

    for (final n in _notifications) {
      final groupable = n.referenceType == 'complaint' &&
          n.referenceId != null &&
          n.referenceId!.isNotEmpty;
      if (groupable) {
        complaintGroups.putIfAbsent(n.referenceId!, () => []).add(n);
      } else {
        singles.add(n);
      }
    }

    final result = <NotifDisplayItem>[];

    for (final entry in complaintGroups.entries) {
      final members = List.of(entry.value)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final unread = members.where((m) => !m.isRead).length;
      result.add(NotifDisplayItem.group(
        latest: members.first,
        referenceId: entry.key,
        unreadCount: unread,
        memberIds: members.map((m) => m.id).toList(),
      ));
    }

    for (final n in singles) {
      result.add(NotifDisplayItem.single(n));
    }

    result.sort(
      (a, b) =>
          b.representative.createdAt.compareTo(a.representative.createdAt),
    );

    return List.unmodifiable(result);
  }

  /// Marks all unread complaint notifications for [referenceId] as read.
  /// Called when the resident taps a grouped complaint notification item.
  void markComplaintGroupRead(String referenceId) {
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      final n = _notifications[i];
      if (!n.isRead &&
          n.referenceId == referenceId &&
          n.referenceType == 'complaint') {
        _notifications[i] = n.copyWith(isRead: true);
        _fs
            .markNotificationRead(n.id)
            .catchError(
                (e) => debugPrint('[NOTIFICATION] markGroupRead error: $e'));
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  /// Returns all loaded notifications (already scoped to current user by stream).
  /// The `role` param is kept for backward-compatible callers — it's a no-op
  /// because the stream already returns only this user's notifications.
  List<NotificationModel> forRole(UserRole role) => List.unmodifiable(_notifications);

  int unreadCount(UserRole role) =>
      _notifications.where((n) => !n.isRead).length;

  // ── Mutations ─────────────────────────────────────────────────────────────

  void markRead(String id) {
    final i = _notifications.indexWhere((n) => n.id == id);
    if (i != -1 && !_notifications[i].isRead) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
      _fs.markNotificationRead(id)
          .catchError((e) => debugPrint('[NOTIFICATION] markRead error: $e'));
      notifyListeners();
    }
  }

  void markAllRead(String userId) {
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) {
      _fs.markAllNotificationsReadForUser(userId)
          .catchError((e) => debugPrint('[NOTIFICATION] markAllRead error: $e'));
      notifyListeners();
    }
  }

  /// Saves one Firestore notification document per target user.
  ///
  /// Provide either:
  /// - [targetUserIds] — explicit list of user IDs to notify, OR
  /// - [aptId] — apartment to broadcast to; users with [targetRole] are
  ///   fetched from Firestore automatically.
  ///
  /// When both are omitted nothing is written (logged as a warning).
  Future<void> addAndPersistNotification({
    required String title,
    required String body,
    required String type,
    required UserRole targetRole,
    String? aptId,
    List<String>? targetUserIds,
    String? referenceId,
    String? referenceType,
  }) async {
    // Resolve target user IDs ─────────────────────────────────────────────
    List<String> userIds = List.of(targetUserIds ?? []);

    if (userIds.isEmpty && aptId != null) {
      debugPrint('[NOTIFICATION] Fetching ${targetRole.name} users for apt $aptId...');
      final users = await _fs.getUsersForApartment(aptId, role: targetRole);
      userIds = users.map((u) => u.id).toList();
      debugPrint('[NOTIFICATION] Found ${userIds.length} target user(s)');
    }

    if (userIds.isEmpty) {
      debugPrint('[NOTIFICATION] ⚠ No target users — notification skipped (targetRole: ${targetRole.name}, aptId: $aptId)');
      return;
    }

    // Write one doc per user ──────────────────────────────────────────────
    debugPrint('[NOTIFICATION] Writing ${userIds.length} notification doc(s) — '
        'targetRole: ${targetRole.name}, type: $type, title: "$title"');
    debugPrint('[NOTIF-SERVER] Creating notification — type: $type  referenceId: $referenceId  referenceType: $referenceType');

    for (final userId in userIds) {
      // Note: targetRole is intentionally NOT stored — new docs are identified
      // purely by userId. This also lets cleanupLegacyNotifications() distinguish
      // old docs (have targetRole, no userId) from new ones (have userId, no targetRole).
      final data = <String, dynamic>{
        'userId': userId,
        'apartmentId': aptId,
        'title': title,
        'body': body,
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'referenceId': referenceId,
        'referenceType': referenceType,
      };
      await _fs.addNotification(data);
      debugPrint('[NOTIFICATION] Saved for userId: $userId  referenceId: $referenceId');
    }

    debugPrint('[NOTIFICATION] All docs saved — Firestore streams will auto-update UI');
    // No optimistic insert: each user's stream fires automatically when their
    // own doc is created. The current caller is a different role, so their
    // _notifications list is unaffected.
  }

  /// Adds a notification only to in-memory list (no Firestore write).
  void addNotification(NotificationModel notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }
}
