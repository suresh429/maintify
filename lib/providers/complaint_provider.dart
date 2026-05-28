import 'package:flutter/foundation.dart';
import '../models/complaint_model.dart';

class ComplaintProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<ComplaintModel> complaintsForUser(String userId) =>
      MockComplaints.forUser(userId);

  List<ComplaintModel> complaintsForApartment(String aptId) =>
      MockComplaints.forApartment(aptId);

  List<ComplaintMessage> messagesForComplaint(String complaintId) {
    final c = MockComplaints.findById(complaintId);
    return c?.messages ?? [];
  }

  Future<void> createComplaint({
    required String apartmentId,
    required String userId,
    required String userName,
    required String unit,
    required String title,
    required String category,
  }) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));

    final id = 'c${DateTime.now().millisecondsSinceEpoch}';
    final complaint = ComplaintModel(
      id: id,
      apartmentId: apartmentId,
      userId: userId,
      userName: userName,
      unit: unit,
      title: title,
      category: category,
      status: ComplaintStatus.open,
      createdAt: DateTime.now(),
      messages: [],
    );
    MockComplaints.addComplaint(complaint);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> sendMessage({
    required String complaintId,
    required String senderId,
    required String senderName,
    required bool isFromAdmin,
    required String content,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final msg = ComplaintMessage(
      id: 'msg${DateTime.now().millisecondsSinceEpoch}',
      complaintId: complaintId,
      senderId: senderId,
      senderName: senderName,
      isFromAdmin: isFromAdmin,
      content: content,
      timestamp: DateTime.now(),
    );
    MockComplaints.addMessage(complaintId, msg);
    notifyListeners();
  }

  Future<void> updateStatus(String complaintId, String status) async {
    await Future.delayed(const Duration(milliseconds: 200));
    MockComplaints.updateStatus(complaintId, status);
    notifyListeners();
  }
}
