import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint_model.dart';
import '../models/notification_model.dart';
import '../core/services/firestore_service.dart';
import '../core/theme/role_theme.dart';
import 'notification_provider.dart';

class ComplaintProvider extends ChangeNotifier {
  final FirestoreService _fs = FirestoreService();

  // Apartment-level complaints cache
  List<ComplaintModel> _aptComplaints = [];
  StreamSubscription<List<ComplaintModel>>? _aptSub;

  // User-level complaints cache
  List<ComplaintModel> _userComplaints = [];
  StreamSubscription<List<ComplaintModel>>? _userSub;

  // Messages cache: complaintId → messages
  final Map<String, List<ComplaintMessage>> _messagesCache = {};
  final Map<String, StreamSubscription<List<ComplaintMessage>>>
      _messageSubs = {};

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ── Stream management ─────────────────────────────────────────────────────

  void startListeningForApartment(String aptId) {
    _aptSub?.cancel();
    _aptSub =
        _fs.streamComplaintsForApartment(aptId).listen((list) {
      debugPrint('[REALTIME] Complaints updated (apt $aptId): ${list.length} doc(s)');
      _aptComplaints = list;
      notifyListeners();
    }, onError: (e) {
      debugPrint('[REALTIME] Complaints stream ERROR (apt $aptId): $e');
    });
  }

  void startListeningForUser(String userId) {
    // Cancel any stale per-complaint message subscriptions from a previous
    // login session. The guard in subscribeToMessages() checks key existence,
    // so stale (dead) entries would prevent new subscriptions from being
    // created after logout/re-login.
    for (final sub in _messageSubs.values) {
      sub.cancel();
    }
    _messageSubs.clear();

    _userSub?.cancel();
    _userSub = _fs.streamComplaintsForUser(userId).listen((list) {
      debugPrint('[REALTIME] User complaints updated ($userId): ${list.length} doc(s)');
      _userComplaints = list;
      notifyListeners();
    }, onError: (e) {
      debugPrint('[REALTIME] User complaints stream ERROR ($userId): $e');
    });
  }

  /// Subscribe to real-time messages for a specific complaint.
  /// Call from the chat screen's initState.
  void subscribeToMessages(String complaintId) {
    if (_messageSubs.containsKey(complaintId)) return;
    _messageSubs[complaintId] =
        _fs.streamMessages(complaintId).listen((msgs) {
      debugPrint('[REALTIME] Messages updated ($complaintId): ${msgs.length} msg(s)');
      _messagesCache[complaintId] = msgs;
      notifyListeners();
    }, onError: (e) {
      debugPrint('[REALTIME] Messages stream ERROR ($complaintId): $e');
      // Remove the dead subscription so the next subscribeToMessages call
      // (e.g. re-entering the chat after auth recovery) can re-subscribe.
      _messageSubs.remove(complaintId)?.cancel();
    });
  }

  void unsubscribeFromMessages(String complaintId) {
    _messageSubs.remove(complaintId)?.cancel();
  }

  @override
  void dispose() {
    _aptSub?.cancel();
    _userSub?.cancel();
    for (final sub in _messageSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  // ── Queries (same signatures as original) ─────────────────────────────────

  List<ComplaintModel> complaintsForUser(String userId) => _userComplaints;

  List<ComplaintModel> complaintsForApartment(String aptId) => _aptComplaints;

  List<ComplaintMessage> messagesForComplaint(String complaintId) {
    if (_messagesCache.containsKey(complaintId)) {
      return _messagesCache[complaintId]!;
    }
    subscribeToMessages(complaintId);
    return [];
  }

  /// Returns the live complaint from the provider cache (updated by Firestore stream).
  ComplaintModel? findComplaint(String complaintId) => _findComplaint(complaintId);

  // ── Internal helpers ──────────────────────────────────────────────────────

  ComplaintModel? _findComplaint(String complaintId) {
    final combined = [..._aptComplaints, ..._userComplaints];
    try {
      return combined.firstWhere((c) => c.id == complaintId);
    } catch (_) {
      return null;
    }
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> createComplaint({
    required String apartmentId,
    required String userId,
    required String userName,
    required String unit,
    required String title,
    required String content,
    required String category,
    required NotificationProvider notificationProvider,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final id = 'c${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();
      await _fs.createComplaint(id, {
        'apartmentId': apartmentId,
        'userId': userId,
        'userName': userName,
        'unit': unit,
        'title': title,
        'content': content,
        'category': category,
        'status': ComplaintStatus.open,
        'createdAt': Timestamp.fromDate(now),
        'lastActivityAt': Timestamp.fromDate(now),
      });

      // Optimistic: insert into _userComplaints immediately so the list
      // updates before the Firestore stream fires its next snapshot.
      final complaint = ComplaintModel(
        id: id,
        apartmentId: apartmentId,
        userId: userId,
        userName: userName,
        unit: unit,
        title: title,
        content: content,
        category: category,
        status: ComplaintStatus.open,
        createdAt: now,
        lastActivityAt: now,
      );
      _userComplaints = [complaint, ..._userComplaints];
      MockComplaints.addComplaint(complaint);

      // Notify admin(s) of this apartment.
      // Wrapped in its own try/catch — notification failure (e.g. PERMISSION_DENIED)
      // must never block a successful complaint creation.
      try {
        debugPrint(
            '[FLOW] Complaint created — triggering notification to admin (apt: $apartmentId)');
        // Notify president
        await notificationProvider.addAndPersistNotification(
          title: 'New Complaint',
          body: 'A new complaint has been reported in your apartment.',
          type: NotificationType.complaint,
          targetRole: UserRole.president,
          aptId: apartmentId,
        );
        // Notify all residents in the apartment
        await notificationProvider.addAndPersistNotification(
          title: 'New Apartment Complaint',
          body: 'A new complaint has been reported in your apartment.',
          type: NotificationType.complaint,
          targetRole: UserRole.resident,
          aptId: apartmentId,
        );
      } catch (notifErr) {
        debugPrint('[WARN] createComplaint notification failed (non-fatal): $notifErr');
      }
    } catch (e) {
      debugPrint('[ERROR] createComplaint: $e');
      rethrow; // surface to UI so the caller can show an error snackbar
    } finally {
      // Always reset loading — even when an exception is thrown.
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage({
    required String complaintId,
    required String senderId,
    required String senderName,
    required bool isFromAdmin,
    required String content,
    required NotificationProvider notificationProvider,
  }) async {
    try {
      final now = DateTime.now();
      await _fs.addMessage(complaintId, {
        'complaintId': complaintId,
        'senderId': senderId,
        'senderName': senderName,
        'isFromAdmin': isFromAdmin,
        'content': content,
        'timestamp': Timestamp.fromDate(now),
      });

      // Update lastActivityAt on the parent complaint document.
      await _fs.updateComplaint(complaintId, {
        'lastActivityAt': Timestamp.fromDate(now),
      });

      // Optimistic mock update so lists show the latest message
      final msg = ComplaintMessage(
        id: 'msg${now.millisecondsSinceEpoch}',
        complaintId: complaintId,
        senderId: senderId,
        senderName: senderName,
        isFromAdmin: isFromAdmin,
        content: content,
        timestamp: now,
      );
      MockComplaints.addMessage(complaintId, msg);

      // In-app notification to the other party.
      // Wrapped in its own try/catch — notification failure (e.g. PERMISSION_DENIED)
      // must never block a successfully sent message.
      try {
        final complaint = _findComplaint(complaintId);
        final aptId = complaint?.apartmentId;
        if (isFromAdmin) {
          final targetUserId = complaint?.userId;
          debugPrint('[FLOW] Admin replied — notifying user: $targetUserId');
          if (targetUserId != null) {
            await notificationProvider.addAndPersistNotification(
              title: 'Reply on Your Complaint',
              body: 'The admin has replied to your complaint'
                  '${complaint != null ? ': "${complaint.title}"' : '.'}',
              type: NotificationType.complaint,
              targetRole: UserRole.resident,
              aptId: aptId,
              targetUserIds: [targetUserId],
            );
          }
        } else {
          debugPrint(
              '[FLOW] User sent message — notifying admin(s) of apt: $aptId');
          final truncated =
              content.length > 80 ? '${content.substring(0, 80)}…' : content;
          await notificationProvider.addAndPersistNotification(
            title: 'New Message on Complaint',
            body: '$senderName: $truncated',
            type: NotificationType.complaint,
            targetRole: UserRole.president,
            aptId: aptId,
          );
        }
      } catch (notifErr) {
        debugPrint('[WARN] sendMessage notification failed (non-fatal): $notifErr');
      }
    } catch (e) {
      debugPrint('[ERROR] sendMessage: $e');
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> updateStatus(String complaintId, String status) async {
    await _fs.updateComplaint(complaintId, {'status': status});
    MockComplaints.updateStatus(complaintId, status);
    notifyListeners();
  }
}
