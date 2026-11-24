import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SECURITY STAFF MODEL
//
// Public fields stored in apartments/{aptId}/securityStaff/{staffId}.
// All monetary values in PAISE (integer) to match community fund convention.
// ─────────────────────────────────────────────────────────────────────────────

class SecurityDesignation {
  static const watchman      = 'Watchman';
  static const securityGuard = 'Security Guard';
  static const headSecurity  = 'Head Security';
  static const nightSecurity = 'Night Security';
  static const daySecurity   = 'Day Security';
  static const other         = 'Other';

  static const List<String> all = [
    watchman,
    securityGuard,
    headSecurity,
    nightSecurity,
    daySecurity,
    other,
  ];
}

class SecurityShift {
  static const day     = 'Day';
  static const night   = 'Night';
  static const fullDay = 'Full Day';

  static const List<String> all = [day, night, fullDay];
}

class SecurityEmploymentStatus {
  static const active   = 'active';
  static const inactive = 'inactive';
}

// ─────────────────────────────────────────────────────────────────────────────
// SECURITY STAFF (PUBLIC)
// ─────────────────────────────────────────────────────────────────────────────

class SecurityStaffModel {
  final String id;
  final String apartmentId;
  final String name;
  final String mobileNumber;         // E.164 format e.g. +919876543210
  final String? alternateMobileNumber;
  final String designation;          // SecurityDesignation.*
  final DateTime joiningDate;
  final String? shift;               // SecurityShift.* | null
  final String? email;
  final String? address;
  final String? notes;
  final String? profileImageUrl;
  final String employmentStatus;     // 'active' | 'inactive'
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;

  const SecurityStaffModel({
    required this.id,
    required this.apartmentId,
    required this.name,
    required this.mobileNumber,
    this.alternateMobileNumber,
    required this.designation,
    required this.joiningDate,
    this.shift,
    this.email,
    this.address,
    this.notes,
    this.profileImageUrl,
    required this.employmentStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
  });

  bool get isActive => employmentStatus == SecurityEmploymentStatus.active;

  factory SecurityStaffModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SecurityStaffModel(
      id:                     doc.id,
      apartmentId:            d['apartmentId']            as String? ?? '',
      name:                   d['name']                   as String? ?? '',
      mobileNumber:           d['mobileNumber']           as String? ?? '',
      alternateMobileNumber:  d['alternateMobileNumber']  as String?,
      designation:            d['designation']            as String? ?? SecurityDesignation.watchman,
      joiningDate:            (d['joiningDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      shift:                  d['shift']                  as String?,
      email:                  d['email']                  as String?,
      address:                d['address']                as String?,
      notes:                  d['notes']                  as String?,
      profileImageUrl:        d['profileImageUrl']        as String?,
      employmentStatus:       d['employmentStatus']       as String? ?? SecurityEmploymentStatus.active,
      createdAt:              (d['createdAt']  as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:              (d['updatedAt']  as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy:              d['createdBy']              as String? ?? '',
      updatedBy:              d['updatedBy']              as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'apartmentId':      apartmentId,
      'name':             name,
      'mobileNumber':     mobileNumber,
      'designation':      designation,
      'joiningDate':      Timestamp.fromDate(joiningDate),
      'employmentStatus': employmentStatus,
      'createdAt':        Timestamp.fromDate(createdAt),
      'updatedAt':        Timestamp.fromDate(updatedAt),
      'createdBy':        createdBy,
      'updatedBy':        updatedBy,
    };
    if (alternateMobileNumber != null && alternateMobileNumber!.isNotEmpty) {
      map['alternateMobileNumber'] = alternateMobileNumber;
    }
    if (shift != null && shift!.isNotEmpty) map['shift'] = shift;
    if (email != null && email!.isNotEmpty) map['email'] = email;
    if (address != null && address!.isNotEmpty) map['address'] = address;
    if (notes != null && notes!.isNotEmpty) map['notes'] = notes;
    if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      map['profileImageUrl'] = profileImageUrl;
    }
    return map;
  }

  SecurityStaffModel copyWith({
    String? name,
    String? mobileNumber,
    String? alternateMobileNumber,
    String? designation,
    DateTime? joiningDate,
    String? shift,
    String? email,
    String? address,
    String? notes,
    String? profileImageUrl,
    String? employmentStatus,
    DateTime? updatedAt,
    String? updatedBy,
  }) =>
      SecurityStaffModel(
        id:                    id,
        apartmentId:           apartmentId,
        name:                  name             ?? this.name,
        mobileNumber:          mobileNumber     ?? this.mobileNumber,
        alternateMobileNumber: alternateMobileNumber ?? this.alternateMobileNumber,
        designation:           designation      ?? this.designation,
        joiningDate:           joiningDate      ?? this.joiningDate,
        shift:                 shift            ?? this.shift,
        email:                 email            ?? this.email,
        address:               address          ?? this.address,
        notes:                 notes            ?? this.notes,
        profileImageUrl:       profileImageUrl  ?? this.profileImageUrl,
        employmentStatus:      employmentStatus ?? this.employmentStatus,
        createdAt:             createdAt,
        updatedAt:             updatedAt        ?? this.updatedAt,
        createdBy:             createdBy,
        updatedBy:             updatedBy        ?? this.updatedBy,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SECURITY STAFF SALARY (PRIVATE)
// Stored in apartments/{aptId}/securityStaff/{staffId}/private/compensation
// ─────────────────────────────────────────────────────────────────────────────

class SecurityStaffSalary {
  final String staffId;
  final int monthlySalaryPaise; // paise integer (e.g. 15000 INR = 1500000 paise)
  final DateTime updatedAt;
  final String updatedBy;

  const SecurityStaffSalary({
    required this.staffId,
    required this.monthlySalaryPaise,
    required this.updatedAt,
    required this.updatedBy,
  });

  double get monthlySalary => monthlySalaryPaise / 100;

  factory SecurityStaffSalary.fromFirestore(String staffId, DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SecurityStaffSalary(
      staffId:             staffId,
      monthlySalaryPaise:  (d['monthlySalaryPaise'] as num?)?.toInt() ?? 0,
      updatedAt:           (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy:           d['updatedBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'monthlySalaryPaise': monthlySalaryPaise,
        'updatedAt':          Timestamp.fromDate(updatedAt),
        'updatedBy':          updatedBy,
      };
}
