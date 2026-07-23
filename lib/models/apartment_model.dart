import 'package:cloud_firestore/cloud_firestore.dart';

class ApartmentModel {
  final String id;
  final String name;
  final String code;           // e.g. "SAMH4721"
  final String status;         // "waiting_for_president" | "active" | "disabled"
  final String? type;          // "Apartment" | "Villa" | "Gated Community"
  final String? address;
  final int? towerCount;
  final List<String>? towerNames;
  final String? presidentFlat; // President's flat number e.g. "A-101"
  final String? presidentName;
  final String? presidentEmail;
  final String? presidentPhone;
  final String? presidentId;
  final int totalFlats;
  final int occupiedFlats;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ApartmentModel({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
    this.type,
    this.address,
    this.towerCount,
    this.towerNames,
    this.presidentFlat,
    this.presidentName,
    this.presidentEmail,
    this.presidentPhone,
    this.presidentId,
    required this.totalFlats,
    this.occupiedFlats = 0,
    required this.createdAt,
    this.updatedAt,
  });

  bool get hasPresident =>
      presidentId != null && presidentId!.isNotEmpty;

  factory ApartmentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ApartmentModel(
      id: doc.id,
      name: d['name'] as String? ?? '',
      // Support legacy docs that still store "apartmentCode"
      code: (d['code'] ?? d['apartmentCode']) as String? ?? '',
      status: d['status'] as String? ?? 'active',
      type: d['type'] as String?,
      address: d['address'] as String?,
      towerCount: d['towerCount'] as int?,
      towerNames: (d['towerNames'] as List<dynamic>?)?.cast<String>(),
      presidentFlat: d['presidentFlat'] as String?,
      presidentName: d['presidentName'] as String?,
      presidentEmail: d['presidentEmail'] as String?,
      presidentPhone: d['presidentPhone'] as String?,
      presidentId: d['presidentId'] as String?,
      totalFlats: (d['totalFlats'] as int?) ?? 0,
      occupiedFlats: (d['occupiedFlats'] as int?) ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'code': code,
        'status': status,
        'type': type,
        'address': address,
        'towerCount': towerCount,
        'towerNames': towerNames,
        'presidentFlat': presidentFlat,
        'presidentName': presidentName,
        'presidentEmail': presidentEmail,
        'presidentPhone': presidentPhone,
        'presidentId': presidentId,
        'totalFlats': totalFlats,
        'occupiedFlats': occupiedFlats,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      };

  ApartmentModel copyWith({
    String? presidentId,
    String? presidentName,
    bool clearPresident = false,
    String? status,
    String? code,
    String? type,
    String? address,
    int? towerCount,
    List<String>? towerNames,
    String? presidentFlat,
    String? presidentEmail,
    String? presidentPhone,
    int? occupiedFlats,
    DateTime? updatedAt,
  }) {
    return ApartmentModel(
      id: id,
      name: name,
      code: code ?? this.code,
      status: status ?? this.status,
      type: type ?? this.type,
      address: address ?? this.address,
      towerCount: towerCount ?? this.towerCount,
      towerNames: towerNames ?? this.towerNames,
      presidentFlat: presidentFlat ?? this.presidentFlat,
      presidentId: clearPresident ? null : (presidentId ?? this.presidentId),
      presidentName:
          clearPresident ? null : (presidentName ?? this.presidentName),
      presidentEmail: presidentEmail ?? this.presidentEmail,
      presidentPhone: presidentPhone ?? this.presidentPhone,
      totalFlats: totalFlats,
      occupiedFlats: occupiedFlats ?? this.occupiedFlats,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MockApartments {
  static final List<ApartmentModel> _list = [
    ApartmentModel(
      id: 'apt1',
      name: 'Samhith Residency',
      code: 'SAMH4721',
      status: 'active',
      presidentId: 'u2',
      presidentName: 'G. Srikanth',
      presidentEmail: 'admin@test.com',
      totalFlats: 10,
      occupiedFlats: 9,
      createdAt: DateTime(2021, 8, 15),
    ),
  ];

  static List<ApartmentModel> get all => List.unmodifiable(_list);

  static ApartmentModel? findById(String id) {
    try {
      return _list.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  static void add(ApartmentModel apt) => _list.add(apt);

  static void assignPresident(
      String aptId, String presidentId, String presidentName) {
    final i = _list.indexWhere((a) => a.id == aptId);
    if (i != -1) {
      _list[i] =
          _list[i].copyWith(presidentId: presidentId, presidentName: presidentName);
    }
  }

  static List<ApartmentModel> get withPresident =>
      _list.where((a) => a.hasPresident).toList();

  static List<ApartmentModel> get withoutPresident =>
      _list.where((a) => !a.hasPresident).toList();

  static void replaceAll(List<ApartmentModel> apartments) {
    _list
      ..clear()
      ..addAll(apartments);
  }
}
