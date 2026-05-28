class ApartmentModel {
  final String id;
  final String name;
  final String address;
  final String city;
  final int totalFlats;
  final String? presidentId;
  final List<String> amenities;
  final DateTime createdAt;

  const ApartmentModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.totalFlats,
    this.presidentId,
    this.amenities = const [],
    required this.createdAt,
  });

  bool get hasPresident =>
      presidentId != null && presidentId!.isNotEmpty;

  ApartmentModel copyWith({String? presidentId, bool clearPresident = false}) {
    return ApartmentModel(
      id: id,
      name: name,
      address: address,
      city: city,
      totalFlats: totalFlats,
      presidentId: clearPresident ? null : (presidentId ?? this.presidentId),
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
      name: 'Sai Residency',
      address: '12, MG Road',
      city: 'Bengaluru',
      totalFlats: 10,
      presidentId: 'u2',
      amenities: ['Parking', 'Gym', 'Pool', 'Security', 'Lift'],
      createdAt: DateTime(2020, 6, 1),
    ),
    ApartmentModel(
      id: 'apt2',
      name: 'Green Valley Towers',
      address: '45, Whitefield',
      city: 'Bengaluru',
      totalFlats: 8,
      presidentId: 'u8',
      amenities: ['Parking', 'Garden', 'Clubhouse', 'Security'],
      createdAt: DateTime(2021, 3, 15),
    ),
    ApartmentModel(
      id: 'apt3',
      name: 'Blue Sky Apartments',
      address: '78, Koramangala',
      city: 'Bengaluru',
      totalFlats: 6,
      amenities: ['Parking', 'Gym', 'Security'],
      createdAt: DateTime(2022, 1, 10),
    ),
    ApartmentModel(
      id: 'apt4',
      name: 'Royal Enclave',
      address: '23, HSR Layout',
      city: 'Bengaluru',
      totalFlats: 12,
      amenities: ['Parking', 'Pool', 'Tennis Court', 'Gym', 'Security', 'Lift'],
      createdAt: DateTime(2019, 9, 5),
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

  static void assignPresident(String aptId, String presidentId) {
    final i = _list.indexWhere((a) => a.id == aptId);
    if (i != -1) {
      _list[i] = _list[i].copyWith(presidentId: presidentId);
    }
  }

  static List<ApartmentModel> get withPresident =>
      _list.where((a) => a.hasPresident).toList();

  static List<ApartmentModel> get withoutPresident =>
      _list.where((a) => !a.hasPresident).toList();
}
