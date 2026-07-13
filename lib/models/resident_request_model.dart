import 'package:cloud_firestore/cloud_firestore.dart';

class ResidentRequestModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String apartmentId;
  final String uid;        // Firebase Auth UID (created at signup, before approval)
  final String unit;       // flat number
  final String status;     // "pending" | "approved" | "rejected"
  final DateTime requestedAt;

  const ResidentRequestModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.apartmentId,
    required this.uid,
    required this.unit,
    required this.status,
    required this.requestedAt,
  });

  factory ResidentRequestModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ResidentRequestModel(
      id: doc.id,
      name: d['name'] as String? ?? '',
      email: d['email'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      apartmentId: d['apartmentId'] as String? ?? '',
      uid: d['uid'] as String? ?? '',
      unit: d['unit'] as String? ?? '',
      status: d['status'] as String? ?? 'pending',
      requestedAt:
          (d['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'apartmentId': apartmentId,
        'uid': uid,
        'unit': unit,
        'status': status,
        'requestedAt': Timestamp.fromDate(requestedAt),
      };
}
