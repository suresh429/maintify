import '../core/theme/role_theme.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? apartmentId;
  final String unit;
  final String avatarInitials;
  final DateTime joinedAt;
  final bool isActive;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.apartmentId,
    required this.unit,
    required this.avatarInitials,
    required this.joinedAt,
    this.isActive = true,
  });

  String get roleLabel {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'President';
      case UserRole.user:
        return 'Resident';
    }
  }
}

class MockUsers {
  static final List<UserModel> all = [
    // ── Super Admin ──────────────────────────────────────────
    UserModel(
      id: 'u1',
      name: 'Arjun Sharma',
      email: 'superadmin@test.com',
      phone: '+91 98765 43210',
      role: UserRole.superAdmin,
      unit: 'HQ',
      avatarInitials: 'AS',
      joinedAt: DateTime(2023, 1, 1),
    ),

    // ── Sai Residency — President ─────────────────────────────
    UserModel(
      id: 'u2',
      name: 'Priya Mehta',
      email: 'admin@test.com',
      phone: '+91 87654 32109',
      role: UserRole.admin,
      apartmentId: 'apt1',
      unit: 'Office',
      avatarInitials: 'PM',
      joinedAt: DateTime(2023, 3, 15),
    ),

    // ── Sai Residency — 10 Flat Residents ────────────────────
    UserModel(
      id: 'u3',
      name: 'Rahul Verma',
      email: 'user@test.com',
      phone: '+91 76543 21098',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: 'A-101',
      avatarInitials: 'RV',
      joinedAt: DateTime(2023, 6, 1),
    ),
    UserModel(
      id: 'u4',
      name: 'Sneha Patel',
      email: 'sneha@test.com',
      phone: '+91 65432 10987',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: 'A-102',
      avatarInitials: 'SP',
      joinedAt: DateTime(2023, 6, 10),
    ),
    UserModel(
      id: 'u5',
      name: 'Karan Singh',
      email: 'karan@test.com',
      phone: '+91 54321 09876',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: 'B-201',
      avatarInitials: 'KS',
      joinedAt: DateTime(2023, 7, 5),
    ),
    UserModel(
      id: 'u6',
      name: 'Meera Joshi',
      email: 'meera@test.com',
      phone: '+91 43210 98765',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: 'B-202',
      avatarInitials: 'MJ',
      joinedAt: DateTime(2023, 7, 20),
    ),
    UserModel(
      id: 'u9',
      name: 'Vikram Shah',
      email: 'vikram@test.com',
      phone: '+91 32101 23456',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: 'C-301',
      avatarInitials: 'VS',
      joinedAt: DateTime(2023, 8, 1),
    ),
    UserModel(
      id: 'u10',
      name: 'Divya Nair',
      email: 'divya@test.com',
      phone: '+91 21012 34567',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: 'C-302',
      avatarInitials: 'DN',
      joinedAt: DateTime(2023, 8, 12),
    ),
    UserModel(
      id: 'u11',
      name: 'Suresh Kumar',
      email: 'suresh@test.com',
      phone: '+91 10123 45678',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: 'D-401',
      avatarInitials: 'SK',
      joinedAt: DateTime(2023, 9, 3),
    ),
    UserModel(
      id: 'u12',
      name: 'Pooja Sharma',
      email: 'pooja@test.com',
      phone: '+91 90123 45670',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: 'D-402',
      avatarInitials: 'PS',
      joinedAt: DateTime(2023, 9, 18),
    ),
    UserModel(
      id: 'u13',
      name: 'Amit Jain',
      email: 'amit@test.com',
      phone: '+91 80234 56789',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: 'E-501',
      avatarInitials: 'AJ',
      joinedAt: DateTime(2023, 10, 5),
    ),
    UserModel(
      id: 'u14',
      name: 'Riya Desai',
      email: 'riya@test.com',
      phone: '+91 70345 67890',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: 'E-502',
      avatarInitials: 'RD',
      joinedAt: DateTime(2023, 10, 22),
    ),

    // ── Green Valley Towers — President ───────────────────────
    UserModel(
      id: 'u8',
      name: 'Ananya Gupta',
      email: 'ananya@test.com',
      phone: '+91 21098 76543',
      role: UserRole.admin,
      apartmentId: 'apt2',
      unit: 'Office',
      avatarInitials: 'AG',
      joinedAt: DateTime(2023, 4, 1),
    ),

    // ── Green Valley Towers — 8 Flat Residents ────────────────
    UserModel(
      id: 'u7',
      name: 'Deepak Kumar',
      email: 'deepak@test.com',
      phone: '+91 32109 87654',
      role: UserRole.user,
      apartmentId: 'apt2',
      unit: 'A-101',
      avatarInitials: 'DK',
      joinedAt: DateTime(2023, 8, 1),
    ),
    UserModel(
      id: 'u15',
      name: 'Preethi Nair',
      email: 'preethi@test.com',
      phone: '+91 60234 56789',
      role: UserRole.user,
      apartmentId: 'apt2',
      unit: 'A-102',
      avatarInitials: 'PN',
      joinedAt: DateTime(2023, 5, 10),
    ),
    UserModel(
      id: 'u16',
      name: 'Sanjay Rao',
      email: 'sanjay@test.com',
      phone: '+91 50345 67891',
      role: UserRole.user,
      apartmentId: 'apt2',
      unit: 'B-201',
      avatarInitials: 'SR',
      joinedAt: DateTime(2023, 5, 20),
    ),
    UserModel(
      id: 'u17',
      name: 'Kavitha Menon',
      email: 'kavitha@test.com',
      phone: '+91 40456 78902',
      role: UserRole.user,
      apartmentId: 'apt2',
      unit: 'B-202',
      avatarInitials: 'KM',
      joinedAt: DateTime(2023, 6, 5),
    ),
    UserModel(
      id: 'u18',
      name: 'Rajesh Iyer',
      email: 'rajesh@test.com',
      phone: '+91 30567 89013',
      role: UserRole.user,
      apartmentId: 'apt2',
      unit: 'C-301',
      avatarInitials: 'RI',
      joinedAt: DateTime(2023, 6, 15),
    ),
    UserModel(
      id: 'u19',
      name: 'Sunita Mishra',
      email: 'sunita@test.com',
      phone: '+91 20678 90124',
      role: UserRole.user,
      apartmentId: 'apt2',
      unit: 'C-302',
      avatarInitials: 'SM',
      joinedAt: DateTime(2023, 7, 1),
    ),
    UserModel(
      id: 'u20',
      name: 'Harish Bhat',
      email: 'harish@test.com',
      phone: '+91 10789 01235',
      role: UserRole.user,
      apartmentId: 'apt2',
      unit: 'D-401',
      avatarInitials: 'HB',
      joinedAt: DateTime(2023, 7, 10),
    ),
    UserModel(
      id: 'u21',
      name: 'Geetha Rao',
      email: 'geetha@test.com',
      phone: '+91 90890 12346',
      role: UserRole.user,
      apartmentId: 'apt2',
      unit: 'D-402',
      avatarInitials: 'GR',
      joinedAt: DateTime(2023, 8, 5),
    ),
  ];

  static UserModel? findByEmail(String email) {
    try {
      return all.firstWhere((u) => u.email == email);
    } catch (_) {
      return null;
    }
  }

  static UserModel? findById(String id) {
    try {
      return all.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<UserModel> get residents =>
      all.where((u) => u.role == UserRole.user).toList();

  static List<UserModel> get admins =>
      all.where((u) => u.role == UserRole.admin).toList();

  static List<UserModel> residentsForApartment(String aptId) => all
      .where((u) => u.role == UserRole.user && u.apartmentId == aptId)
      .toList();

  static UserModel? presidentFor(String aptId) {
    try {
      return all.firstWhere(
        (u) => u.role == UserRole.admin && u.apartmentId == aptId,
      );
    } catch (_) {
      return null;
    }
  }
}
