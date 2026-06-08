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
