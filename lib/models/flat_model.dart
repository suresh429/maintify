import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single flat/unit inside an apartment.
class FlatModel {
  final String id;           // "${aptId}_${flatNumber}"
  final String flatNumber;   // "A-101" | "101"
  final String? tower;       // "A", "B" — null for non-gated
  final String status;       // "available" | "occupied"
  final String? residentId;
  final String? residentType; // "President" | "Resident" | null
  final String apartmentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FlatModel({
    required this.id,
    required this.flatNumber,
    this.tower,
    required this.status,
    this.residentId,
    this.residentType,
    required this.apartmentId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAvailable => status == 'available';
  bool get isOccupied  => status == 'occupied';

  factory FlatModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FlatModel(
      id:           doc.id,
      flatNumber:   d['flatNumber']   as String? ?? '',
      tower:        d['tower']        as String?,
      status:       d['status']       as String? ?? 'available',
      residentId:   d['residentId']   as String?,
      residentType: d['residentType'] as String?,
      apartmentId:  d['apartmentId']  as String? ?? '',
      createdAt:    (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:    (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'flatNumber':   flatNumber,
    'tower':        tower,
    'status':       status,
    'residentId':   residentId,
    'residentType': residentType,
    'apartmentId':  apartmentId,
    'createdAt':    Timestamp.fromDate(createdAt),
    'updatedAt':    Timestamp.fromDate(updatedAt),
  };
}

/// Generates all flats for a newly created apartment.
///
/// Gated Community: distributes [totalFlats] across [towerNames].
///   e.g. Tower A → A-101, A-102 …  Tower B → B-101, B-102 …
/// Others (Apartment / Villa): sequential numbers starting at 101.
///   e.g. 101, 102, 103 …
///
/// The flat matching [presidentFlatNumber] is marked occupied (President).
/// If [presidentUid] is provided it is written into [residentId].
List<FlatModel> generateFlatsForApartment({
  required String apartmentId,
  required int totalFlats,
  required bool isGated,
  required int towerCount,
  required List<String> towerNames,
  required String presidentFlatNumber,
  String? presidentUid,
}) {
  final now   = DateTime.now();
  final flats = <FlatModel>[];
  final presidentKey = presidentFlatNumber.trim().toUpperCase();

  String _id(String flatNum) =>
      '${apartmentId}_${flatNum.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}';

  bool _isPresident(String flatNum) =>
      flatNum.trim().toUpperCase() == presidentKey;

  FlatModel _make(String flatNum, String? tower) {
    final pres = _isPresident(flatNum);
    return FlatModel(
      id:           _id(flatNum),
      flatNumber:   flatNum,
      tower:        tower,
      status:       pres ? 'occupied' : 'available',
      residentId:   pres ? presidentUid : null,
      residentType: pres ? 'President' : null,
      apartmentId:  apartmentId,
      createdAt:    now,
      updatedAt:    now,
    );
  }

  if (isGated && towerCount > 0 && towerNames.isNotEmpty) {
    final base      = totalFlats ~/ towerCount;
    int   remainder = totalFlats - base * towerCount;
    int   generated = 0;

    for (int t = 0; t < towerCount && generated < totalFlats; t++) {
      final tower = towerNames[t];
      final count = base + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;

      for (int f = 0; f < count && generated < totalFlats; f++) {
        flats.add(_make('$tower-${101 + f}', tower));
        generated++;
      }
    }
  } else {
    for (int i = 0; i < totalFlats; i++) {
      flats.add(_make('${101 + i}', null));
    }
  }

  return flats;
}

/// Generates a collision-safe 8-character apartment code.
/// Format: 4 uppercase letters (from [aptName]) + 4 random digits.
/// The [codeExists] callback is used to retry until unique.
Future<String> generateUniqueApartmentCode(
  String aptName,
  Future<bool> Function(String code) codeExists,
) async {
  final rng = Random();
  final clean = aptName.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
  final letters = clean.length >= 4
      ? clean.substring(0, 4)
      : clean.padRight(4, 'X');

  String code;
  do {
    final digits = (1000 + rng.nextInt(9000)).toString();
    code = '$letters$digits';
  } while (await codeExists(code));

  return code;
}
