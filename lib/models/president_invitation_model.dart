import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a president invitation created by a Super Admin.
/// Stored in the `president_invitations` Firestore collection.
class PresidentInvitationModel {
  final String id;
  final String invitationToken;   // Unique 12-char alphanumeric token
  final String apartmentId;
  final String apartmentCode;
  final String presidentName;
  final String presidentEmail;
  final String mobileNumber;
  final String apartmentName;
  final String? apartmentType;
  final String? apartmentAddress;
  final String presidentFlatNumber;
  final int?   towerCount;
  final List<String>? towerNames;
  final String status;            // 'pending' | 'completed' | 'expired'
  final DateTime expiresAt;
  final DateTime createdAt;
  final String? createdBy;        // Super admin UID

  const PresidentInvitationModel({
    required this.id,
    required this.invitationToken,
    required this.apartmentId,
    required this.apartmentCode,
    required this.presidentName,
    required this.presidentEmail,
    required this.mobileNumber,
    required this.apartmentName,
    this.apartmentType,
    this.apartmentAddress,
    required this.presidentFlatNumber,
    this.towerCount,
    this.towerNames,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.createdBy,
  });

  bool get isPending   => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isExpired   => status == 'expired' || DateTime.now().isAfter(expiresAt);

  /// Human-readable tower summary, e.g. "2 Towers (A, B)". Null if not gated.
  String? get towerInfo {
    if (towerCount == null || towerCount! <= 0 ||
        towerNames == null || towerNames!.isEmpty) return null;
    return '$towerCount ${towerCount == 1 ? "Tower" : "Towers"} (${towerNames!.join(", ")})';
  }

  factory PresidentInvitationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PresidentInvitationModel(
      id:                   doc.id,
      invitationToken:      d['invitationToken']      as String? ?? '',
      apartmentId:          d['apartmentId']          as String? ?? '',
      apartmentCode:        d['apartmentCode']        as String? ?? '',
      presidentName:        d['presidentName']        as String? ?? '',
      presidentEmail:       d['presidentEmail']       as String? ?? '',
      mobileNumber:         d['mobileNumber']         as String? ?? '',
      apartmentName:        d['apartmentName']        as String? ?? '',
      apartmentType:        d['apartmentType']        as String?,
      apartmentAddress:     d['apartmentAddress']     as String?,
      presidentFlatNumber:  d['presidentFlatNumber']  as String? ?? '',
      towerCount:           d['towerCount']           as int?,
      towerNames:           (d['towerNames'] as List<dynamic>?)?.cast<String>(),
      status:               d['status']               as String? ?? 'pending',
      expiresAt:            (d['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt:            (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy:            d['createdBy']            as String?,
    );
  }
}
