import 'package:cloud_firestore/cloud_firestore.dart';

class ApartmentModel {
  final String id;
  final String name;
  final String address;
  final String city;
  final int totalFlats;
  final String? presidentId;
  final String? presidentName;
  final List<String> amenities;
  final DateTime createdAt;

  const ApartmentModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.totalFlats,
    this.presidentId,
    this.presidentName,
    this.amenities = const [],
    required this.createdAt,
  });

  bool get hasPresident =>
      presidentId != null && presidentId!.isNotEmpty;

  factory ApartmentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ApartmentModel(
      id: doc.id,
      name: d['name'] as String? ?? '',
      address: d['address'] as String? ?? '',
      city: d['city'] as String? ?? '',
      totalFlats: (d['totalFlats'] as int?) ?? 0,
      presidentId: d['presidentId'] as String?,
      presidentName: d['presidentName'] as String?,
      amenities: List<String>.from(d['amenities'] as List? ?? []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'address': address,
        'city': city,
        'totalFlats': totalFlats,
        'presidentId': presidentId,
        'presidentName': presidentName,
        'amenities': amenities,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  ApartmentModel copyWith({
    String? presidentId,
    String? presidentName,
    bool clearPresident = false,
  }) {
    return ApartmentModel(
      id: id,
      name: name,
      address: address,
      city: city,
      totalFlats: totalFlats,
      presidentId: clearPresident ? null : (presidentId ?? this.presidentId),
      presidentName: clearPresident ? null : (presidentName ?? this.presidentName),
      amenities: amenities,
      createdAt: createdAt,
    );
  }
}

class MockApartments {
  // Mutable list so providers can add/update apartments at runtime.
  static final List<ApartmentModel> _list = [
    ApartmentModel(
      id: 'apt1',
      name: 'Samhith Residency',
      address: '14, Jubilee Hills',
      city: 'Hyderabad',
      totalFlats: 10,
      presidentId: 'u2',
      amenities: ['Parking', 'Lift', 'Security', 'Garden', 'Gym'],
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

  static void assignPresident(String aptId, String presidentId, String presidentName) {
    final i = _list.indexWhere((a) => a.id == aptId);
    if (i != -1) {
      _list[i] = _list[i].copyWith(presidentId: presidentId, presidentName: presidentName);
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
