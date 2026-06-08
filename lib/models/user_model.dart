import '../core/theme/role_theme.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String password;
  final String phone;
  final UserRole role;
  final String? apartmentId;
  final String unit;
  final String avatarInitials;
  final DateTime joinedAt;
  final bool isActive;
  final bool isFirstLogin;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.password = '123456',
    required this.phone,
    required this.role,
    this.apartmentId,
    required this.unit,
    required this.avatarInitials,
    required this.joinedAt,
    this.isActive = true,
    this.isFirstLogin = false,
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

  UserModel copyWith({UserRole? role, String? password, bool? isFirstLogin}) {
    return UserModel(
      id: id,
      name: name,
      email: email,
      password: password ?? this.password,
      phone: phone,
      role: role ?? this.role,
      apartmentId: apartmentId,
      unit: unit,
      avatarInitials: avatarInitials,
      joinedAt: joinedAt,
      isActive: isActive,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
    );
  }
}

class MockUsers {
  static final List<UserModel> all = [
    // ── Super Admin ──────────────────────────────────────────
    UserModel(
      id: 'u1',
      name: 'Admin System',
      email: 'superadmin@test.com',
      phone: '+91 98765 00001',
      role: UserRole.superAdmin,
      unit: 'HQ',
      avatarInitials: 'SA',
      joinedAt: DateTime(2021, 1, 1),
    ),

    // ── Samhith Residency — President ────────────────────────
    UserModel(
      id: 'u2',
      name: 'G. Srikanth',
      email: 'admin@test.com',
      phone: '+91 98765 00002',
      role: UserRole.admin,
      apartmentId: 'apt1',
      unit: '402',
      avatarInitials: 'GS',
      joinedAt: DateTime(2021, 9, 1),
    ),

    // ── Samhith Residency — 9 Residents ─────────────────────
    UserModel(
      id: 'u3',
      name: 'Rohit',
      email: 'user@test.com',
      phone: '+91 98765 00003',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: '101',
      avatarInitials: 'RO',
      joinedAt: DateTime(2021, 9, 5),
    ),
    UserModel(
      id: 'u4',
      name: 'Ravi',
      email: 'ravi@test.com',
      phone: '+91 98765 00004',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: '102',
      avatarInitials: 'RA',
      joinedAt: DateTime(2021, 9, 10),
    ),
    UserModel(
      id: 'u5',
      name: 'Chaitanya',
      email: 'chaitanya@test.com',
      phone: '+91 98765 00005',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: '201',
      avatarInitials: 'CH',
      joinedAt: DateTime(2021, 10, 1),
    ),
    UserModel(
      id: 'u6',
      name: 'Suresh',
      email: 'suresh@test.com',
      phone: '+91 98765 00006',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: '202',
      avatarInitials: 'SU',
      joinedAt: DateTime(2021, 10, 5),
    ),
    UserModel(
      id: 'u9',
      name: 'Sai',
      email: 'sai@test.com',
      phone: '+91 98765 00009',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: '301',
      avatarInitials: 'SA',
      joinedAt: DateTime(2021, 10, 15),
    ),
    UserModel(
      id: 'u10',
      name: 'Raghu',
      email: 'raghu@test.com',
      phone: '+91 98765 00010',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: '302',
      avatarInitials: 'RG',
      joinedAt: DateTime(2021, 11, 1),
    ),
    UserModel(
      id: 'u11',
      name: 'Ganesh',
      email: 'ganesh@test.com',
      phone: '+91 98765 00011',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: '401',
      avatarInitials: 'GN',
      joinedAt: DateTime(2021, 11, 10),
    ),
    UserModel(
      id: 'u13',
      name: 'Sathish',
      email: 'sathish@test.com',
      phone: '+91 98765 00013',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: '501',
      avatarInitials: 'ST',
      joinedAt: DateTime(2021, 12, 1),
    ),
    UserModel(
      id: 'u14',
      name: 'Deepika',
      email: 'deepika@test.com',
      phone: '+91 98765 00014',
      role: UserRole.user,
      apartmentId: 'apt1',
      unit: '502',
      avatarInitials: 'DK',
      joinedAt: DateTime(2021, 12, 10),
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

  static void updateRole(String userId, UserRole role) {
    final i = all.indexWhere((u) => u.id == userId);
    if (i != -1) {
      all[i] = all[i].copyWith(role: role);
    }
  }

  static void updatePassword(String userId, String newPassword) {
    final i = all.indexWhere((u) => u.id == userId);
    if (i != -1) {
      all[i] = all[i].copyWith(password: newPassword, isFirstLogin: false);
    }
  }
}
