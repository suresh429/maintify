import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BILLING MODEL — Hybrid multi-category design
//
// One BillModel document = one month's full bill for an apartment.
// It embeds a `categories` array (BillCategory) that supports:
//   • common   → split equally across all flats
//   • hybrid   → defaultAmount per flat; per-user overrides in userOverrides
//   • individual → fully custom per-user (userOverrides only, no default)
//
// Storage: bills/ collection ONLY.  No user_bills/ or other collections.
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// BILL CATEGORY
// ─────────────────────────────────────────────────────────────────────────────

/// One billing line-item embedded in BillModel.categories.
class BillCategory {
  final String name;         // e.g. "Lift", "Water", "Garbage"
  final String type;         // "common" | "hybrid" | "individual"
  final double totalAmount;  // apt-level total for this category (stored at creation)
  final double defaultAmount;// per-user default; meaningful for hybrid
  final Map<String, double> userOverrides; // userId → override amount

  const BillCategory({
    required this.name,
    required this.type,
    required this.totalAmount,
    this.defaultAmount = 0,
    this.userOverrides = const {},
  });

  factory BillCategory.fromMap(Map<String, dynamic> m) {
    final rawOverrides = m['userOverrides'] as Map<String, dynamic>? ?? {};
    return BillCategory(
      name: m['name'] as String? ?? '',
      type: m['type'] as String? ?? 'common',
      totalAmount: (m['totalAmount'] as num?)?.toDouble() ?? 0,
      defaultAmount: (m['defaultAmount'] as num?)?.toDouble() ?? 0,
      userOverrides: rawOverrides.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type,
        'totalAmount': totalAmount,
        if (type != 'common') 'defaultAmount': defaultAmount,
        if (userOverrides.isNotEmpty) 'userOverrides': userOverrides,
      };

  /// Compute the amount this user owes for this category.
  double amountForUser(String userId, int eligibleCount) {
    switch (type) {
      case 'common': return eligibleCount > 0 ? totalAmount / eligibleCount : 0;
      case 'hybrid': return userOverrides.containsKey(userId)
          ? userOverrides[userId]! : defaultAmount;
      case 'individual': return userOverrides[userId] ?? 0;
      default: return eligibleCount > 0 ? totalAmount / eligibleCount : 0;
    }
  }
}

class BillStatus {
  static const String paid = 'Paid';
  static const String pending = 'Pending';
  static const String overdue = 'Overdue';
  static const String partiallyPaid = 'Partial';
}

/// One bill for the entire apartment.
/// May contain multiple embedded categories (common, hybrid, individual).
/// A single Firestore document in bills/ represents one month's full bill.
class BillModel {
  final String id;
  final String apartmentId;
  final String createdByAdminId;
  final String title;    // first category name or "" for multi-category bills
  final double totalAmount; // sum of category.totalAmount (or stored legacy value)
  final int totalFlats;
  final String category; // "" for multi-category bills; legacy field
  final String month;
  final DateTime dueDate;
  final DateTime createdAt;
  final String billType;       // "common" | "hybrid" | "individual" (legacy single-cat)
  final List<BillCategory> categories; // embedded categories (new-style bills)
  final List<String> excludedUserIds;

  const BillModel({
    required this.id,
    required this.apartmentId,
    required this.createdByAdminId,
    required this.title,
    required this.totalAmount,
    required this.totalFlats,
    required this.category,
    required this.month,
    required this.dueDate,
    required this.createdAt,
    this.billType = 'common',
    this.categories = const [],
    this.excludedUserIds = const [],
  });

  factory BillModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    // Parse embedded categories (new-style bills)
    final rawCats = d['categories'] as List<dynamic>?;
    final categories = rawCats != null
        ? rawCats
            .map((c) => BillCategory.fromMap(c as Map<String, dynamic>))
            .toList()
        : <BillCategory>[];

    // totalAmount: derive from categories when present; fall back to stored field
    final totalAmount = categories.isNotEmpty
        ? categories.fold(0.0, (s, c) => s + c.totalAmount)
        : (d['totalAmount'] as num?)?.toDouble() ?? 0;

    final rawExcluded = d['excludedUserIds'] as List<dynamic>? ?? [];

    return BillModel(
      id: doc.id,
      apartmentId: d['apartmentId'] as String? ?? '',
      createdByAdminId: d['createdByAdminId'] as String? ?? '',
      title: d['title'] as String? ?? '',
      totalAmount: totalAmount,
      totalFlats: (d['totalFlats'] as int?) ?? 1,
      category: d['category'] as String? ?? '',
      month: d['month'] as String? ?? '',
      dueDate: (d['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      billType: d['billType'] as String? ?? 'common',
      categories: categories,
      excludedUserIds: rawExcluded.cast<String>(),
    );
  }

  Map<String, dynamic> toMap() => {
        'apartmentId': apartmentId,
        'createdByAdminId': createdByAdminId,
        'title': title,
        'totalAmount': totalAmount,
        'totalFlats': totalFlats,
        'category': category,
        'month': month,
        'dueDate': Timestamp.fromDate(dueDate),
        'createdAt': Timestamp.fromDate(createdAt),
        'billType': billType,
        if (categories.isNotEmpty)
          'categories': categories.map((c) => c.toMap()).toList(),
        if (excludedUserIds.isNotEmpty) 'excludedUserIds': excludedUserIds,
      };

  /// Number of flats that actually owe this bill (total minus excluded).
  int get eligibleCount {
    final n = totalFlats - excludedUserIds.length;
    return n > 0 ? n : totalFlats;
  }

  /// Per-flat share for display (sum of each category's per-flat contribution).
  double get perFlatShare {
    final eligible = eligibleCount;
    if (categories.isNotEmpty) {
      return categories.fold(0.0, (s, c) {
        switch (c.type) {
          case 'common': return s + (eligible > 0 ? c.totalAmount / eligible : 0);
          case 'hybrid': return s + c.defaultAmount; // defaultAmount is already per-flat
          case 'individual': return s;
          default: return s + (eligible > 0 ? c.totalAmount / eligible : 0);
        }
      });
    }
    return eligible > 0 ? totalAmount / eligible : 0;
  }

  /// This user's total amount due for this bill (sum across all categories).
  double amountForUser(String userId) {
    if (excludedUserIds.contains(userId)) return 0;
    if (categories.isNotEmpty) {
      return categories.fold(
          0.0, (s, c) => s + c.amountForUser(userId, eligibleCount));
    }
    return perFlatShare;
  }

  String overallStatus(List<BillPayment> payments) {
    if (payments.isEmpty) return BillStatus.pending;
    final paid = payments.where((p) => p.isPaid).length;
    if (paid == payments.length) return BillStatus.paid;
    if (paid == 0) {
      return DateTime.now().isAfter(dueDate)
          ? BillStatus.overdue
          : BillStatus.pending;
    }
    return BillStatus.partiallyPaid;
  }

  int paidFlats(List<BillPayment> payments) =>
      payments.where((p) => p.isPaid).length;

  double collectedAmount(List<BillPayment> payments) =>
      paidFlats(payments) * perFlatShare;
}

/// One payment record per (bill, flat/user) pair.
/// [amount] stores the per-user amount for individual bills; null for common
/// bills (derive from bill.perFlatShare in that case).
class BillPayment {
  final String id;
  final String billId;
  final String userId;
  final String unitNumber;
  String status;
  DateTime? paidDate;
  String? transactionId;
  bool adminVerified;
  final double? amount; // explicit per-user amount (individual bills only)

  BillPayment({
    required this.id,
    required this.billId,
    required this.userId,
    required this.unitNumber,
    required this.status,
    this.paidDate,
    this.transactionId,
    this.adminVerified = false,
    this.amount,
  });

  bool get isPaid => status == BillStatus.paid;
  bool get isPending => status == BillStatus.pending;
  bool get isOverdue => status == BillStatus.overdue;

  factory BillPayment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BillPayment(
      id: doc.id,
      billId: d['billId'] as String? ?? '',
      userId: d['userId'] as String? ?? '',
      unitNumber: d['unitNumber'] as String? ?? '',
      status: d['status'] as String? ?? BillStatus.pending,
      paidDate: (d['paidDate'] as Timestamp?)?.toDate(),
      transactionId: d['transactionId'] as String?,
      adminVerified: d['adminVerified'] as bool? ?? false,
      amount: (d['amount'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap({String? apartmentId}) => {
        'billId': billId,
        'userId': userId,
        'unitNumber': unitNumber,
        'status': status,
        'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
        'transactionId': transactionId,
        'adminVerified': adminVerified,
        if (amount != null) 'amount': amount,
        if (apartmentId != null) 'apartmentId': apartmentId,
      };

  BillPayment copyWith({
    String? status,
    DateTime? paidDate,
    String? transactionId,
    bool? adminVerified,
  }) {
    return BillPayment(
      id: id,
      billId: billId,
      userId: userId,
      unitNumber: unitNumber,
      status: status ?? this.status,
      paidDate: paidDate ?? this.paidDate,
      transactionId: transactionId ?? this.transactionId,
      adminVerified: adminVerified ?? this.adminVerified,
      amount: amount,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK DATA — Samhith Residency (apt1, 10 flats)
//
// Flats and user IDs:
//   101 → u3  Rohit        102 → u4  Ravi
//   201 → u5  Chaitanya    202 → u6  Suresh
//   301 → u9  Sai          302 → u10 Raghu
//   401 → u11 Ganesh       402 → u2  G. Srikanth (President/Admin)
//   501 → u13 Sathish      502 → u14 Deepika
//
// Bills:
//   b1: Lift Maintenance  ₹2000  May 2026   ₹200/flat  (mixed payments)
//   b2: Water Charges     ₹1500  May 2026   ₹150/flat  (mixed payments)
//   b3: Security Charges  ₹3000  April 2026 ₹300/flat  (mostly overdue)
//   b4: Cleaning Fund     ₹1000  March 2026 ₹100/flat  (all paid)
// ─────────────────────────────────────────────────────────────────────────────

class MockBillData {
  static final List<BillModel> _bills = [
    BillModel(
      id: 'b1',
      apartmentId: 'apt1',
      createdByAdminId: 'u2',
      title: 'Lift Maintenance',
      totalAmount: 2000,
      totalFlats: 10,
      category: 'Maintenance',
      month: 'May 2026',
      dueDate: DateTime(2026, 6, 10),
      createdAt: DateTime(2026, 5, 1),
    ),
    BillModel(
      id: 'b2',
      apartmentId: 'apt1',
      createdByAdminId: 'u2',
      title: 'Water Charges',
      totalAmount: 1500,
      totalFlats: 10,
      category: 'Water',
      month: 'May 2026',
      dueDate: DateTime(2026, 6, 10),
      createdAt: DateTime(2026, 5, 2),
    ),
    BillModel(
      id: 'b3',
      apartmentId: 'apt1',
      createdByAdminId: 'u2',
      title: 'Security Charges',
      totalAmount: 3000,
      totalFlats: 10,
      category: 'Security',
      month: 'April 2026',
      dueDate: DateTime(2026, 5, 10),
      createdAt: DateTime(2026, 4, 1),
    ),
    BillModel(
      id: 'b4',
      apartmentId: 'apt1',
      createdByAdminId: 'u2',
      title: 'Cleaning Fund',
      totalAmount: 1000,
      totalFlats: 10,
      category: 'Maintenance',
      month: 'March 2026',
      dueDate: DateTime(2026, 4, 10),
      createdAt: DateTime(2026, 3, 1),
    ),
  ];

  // ── Payment records ───────────────────────────────────────────────────────
  // b1: Lift Maintenance ₹200/flat — Chaitanya, Suresh, Raghu, Srikanth, Deepika paid
  // b2: Water Charges ₹150/flat   — Ravi, Chaitanya, Raghu, Srikanth paid
  // b3: Security Charges ₹300/flat — mostly overdue; Ravi, Suresh, Srikanth paid
  // b4: Cleaning Fund ₹100/flat   — all 10 paid
  static final List<BillPayment> _payments = [

    // ── b1: Lift Maintenance (May 2026) ──────────────────────────────────────
    BillPayment(id: 'p1_u3',  billId: 'b1', userId: 'u3',  unitNumber: '101', status: BillStatus.pending),
    BillPayment(id: 'p1_u4',  billId: 'b1', userId: 'u4',  unitNumber: '102', status: BillStatus.pending),
    BillPayment(id: 'p1_u5',  billId: 'b1', userId: 'u5',  unitNumber: '201', status: BillStatus.paid, paidDate: DateTime(2026, 5, 5),  transactionId: 'TXN1201CH',  adminVerified: true),
    BillPayment(id: 'p1_u6',  billId: 'b1', userId: 'u6',  unitNumber: '202', status: BillStatus.paid, paidDate: DateTime(2026, 5, 6),  transactionId: 'TXN1202SU',  adminVerified: true),
    BillPayment(id: 'p1_u9',  billId: 'b1', userId: 'u9',  unitNumber: '301', status: BillStatus.pending),
    BillPayment(id: 'p1_u10', billId: 'b1', userId: 'u10', unitNumber: '302', status: BillStatus.paid, paidDate: DateTime(2026, 5, 4),  transactionId: 'TXN1302RG',  adminVerified: true),
    BillPayment(id: 'p1_u11', billId: 'b1', userId: 'u11', unitNumber: '401', status: BillStatus.pending),
    BillPayment(id: 'p1_u2',  billId: 'b1', userId: 'u2',  unitNumber: '402', status: BillStatus.paid, paidDate: DateTime(2026, 5, 3),  transactionId: 'TXN1402SK',  adminVerified: true),
    BillPayment(id: 'p1_u13', billId: 'b1', userId: 'u13', unitNumber: '501', status: BillStatus.overdue),
    BillPayment(id: 'p1_u14', billId: 'b1', userId: 'u14', unitNumber: '502', status: BillStatus.paid, paidDate: DateTime(2026, 5, 7),  transactionId: 'TXN1502DK',  adminVerified: true),

    // ── b2: Water Charges (May 2026) ─────────────────────────────────────────
    BillPayment(id: 'p2_u3',  billId: 'b2', userId: 'u3',  unitNumber: '101', status: BillStatus.pending),
    BillPayment(id: 'p2_u4',  billId: 'b2', userId: 'u4',  unitNumber: '102', status: BillStatus.paid, paidDate: DateTime(2026, 5, 8),  transactionId: 'TXN2102RA',  adminVerified: true),
    BillPayment(id: 'p2_u5',  billId: 'b2', userId: 'u5',  unitNumber: '201', status: BillStatus.paid, paidDate: DateTime(2026, 5, 9),  transactionId: 'TXN2201CH',  adminVerified: true),
    BillPayment(id: 'p2_u6',  billId: 'b2', userId: 'u6',  unitNumber: '202', status: BillStatus.pending),
    BillPayment(id: 'p2_u9',  billId: 'b2', userId: 'u9',  unitNumber: '301', status: BillStatus.pending),
    BillPayment(id: 'p2_u10', billId: 'b2', userId: 'u10', unitNumber: '302', status: BillStatus.paid, paidDate: DateTime(2026, 5, 5),  transactionId: 'TXN2302RG',  adminVerified: true),
    BillPayment(id: 'p2_u11', billId: 'b2', userId: 'u11', unitNumber: '401', status: BillStatus.pending),
    BillPayment(id: 'p2_u2',  billId: 'b2', userId: 'u2',  unitNumber: '402', status: BillStatus.paid, paidDate: DateTime(2026, 5, 4),  transactionId: 'TXN2402SK',  adminVerified: true),
    BillPayment(id: 'p2_u13', billId: 'b2', userId: 'u13', unitNumber: '501', status: BillStatus.pending),
    BillPayment(id: 'p2_u14', billId: 'b2', userId: 'u14', unitNumber: '502', status: BillStatus.pending),

    // ── b3: Security Charges (April 2026 — overdue) ───────────────────────────
    BillPayment(id: 'p3_u3',  billId: 'b3', userId: 'u3',  unitNumber: '101', status: BillStatus.overdue),
    BillPayment(id: 'p3_u4',  billId: 'b3', userId: 'u4',  unitNumber: '102', status: BillStatus.paid, paidDate: DateTime(2026, 5, 2),  transactionId: 'TXN3102RA',  adminVerified: true),
    BillPayment(id: 'p3_u5',  billId: 'b3', userId: 'u5',  unitNumber: '201', status: BillStatus.overdue),
    BillPayment(id: 'p3_u6',  billId: 'b3', userId: 'u6',  unitNumber: '202', status: BillStatus.paid, paidDate: DateTime(2026, 5, 1),  transactionId: 'TXN3202SU',  adminVerified: true),
    BillPayment(id: 'p3_u9',  billId: 'b3', userId: 'u9',  unitNumber: '301', status: BillStatus.overdue),
    BillPayment(id: 'p3_u10', billId: 'b3', userId: 'u10', unitNumber: '302', status: BillStatus.overdue),
    BillPayment(id: 'p3_u11', billId: 'b3', userId: 'u11', unitNumber: '401', status: BillStatus.overdue),
    BillPayment(id: 'p3_u2',  billId: 'b3', userId: 'u2',  unitNumber: '402', status: BillStatus.paid, paidDate: DateTime(2026, 5, 3),  transactionId: 'TXN3402SK',  adminVerified: true),
    BillPayment(id: 'p3_u13', billId: 'b3', userId: 'u13', unitNumber: '501', status: BillStatus.overdue),
    BillPayment(id: 'p3_u14', billId: 'b3', userId: 'u14', unitNumber: '502', status: BillStatus.overdue),

    // ── b4: Cleaning Fund (March 2026 — all paid) ─────────────────────────────
    BillPayment(id: 'p4_u3',  billId: 'b4', userId: 'u3',  unitNumber: '101', status: BillStatus.paid, paidDate: DateTime(2026, 4, 2),  transactionId: 'TXN4101RO',  adminVerified: true),
    BillPayment(id: 'p4_u4',  billId: 'b4', userId: 'u4',  unitNumber: '102', status: BillStatus.paid, paidDate: DateTime(2026, 4, 3),  transactionId: 'TXN4102RA',  adminVerified: true),
    BillPayment(id: 'p4_u5',  billId: 'b4', userId: 'u5',  unitNumber: '201', status: BillStatus.paid, paidDate: DateTime(2026, 4, 1),  transactionId: 'TXN4201CH',  adminVerified: true),
    BillPayment(id: 'p4_u6',  billId: 'b4', userId: 'u6',  unitNumber: '202', status: BillStatus.paid, paidDate: DateTime(2026, 4, 2),  transactionId: 'TXN4202SU',  adminVerified: true),
    BillPayment(id: 'p4_u9',  billId: 'b4', userId: 'u9',  unitNumber: '301', status: BillStatus.paid, paidDate: DateTime(2026, 4, 4),  transactionId: 'TXN4301SA',  adminVerified: true),
    BillPayment(id: 'p4_u10', billId: 'b4', userId: 'u10', unitNumber: '302', status: BillStatus.paid, paidDate: DateTime(2026, 4, 5),  transactionId: 'TXN4302RG',  adminVerified: true),
    BillPayment(id: 'p4_u11', billId: 'b4', userId: 'u11', unitNumber: '401', status: BillStatus.paid, paidDate: DateTime(2026, 4, 3),  transactionId: 'TXN4401GN',  adminVerified: true),
    BillPayment(id: 'p4_u2',  billId: 'b4', userId: 'u2',  unitNumber: '402', status: BillStatus.paid, paidDate: DateTime(2026, 4, 1),  transactionId: 'TXN4402SK',  adminVerified: true),
    BillPayment(id: 'p4_u13', billId: 'b4', userId: 'u13', unitNumber: '501', status: BillStatus.paid, paidDate: DateTime(2026, 4, 6),  transactionId: 'TXN4501ST',  adminVerified: true),
    BillPayment(id: 'p4_u14', billId: 'b4', userId: 'u14', unitNumber: '502', status: BillStatus.paid, paidDate: DateTime(2026, 4, 2),  transactionId: 'TXN4502DK',  adminVerified: true),
  ];

  static List<BillModel> get bills => _bills;
  static List<BillPayment> get payments => _payments;

  static List<BillModel> billsForApartment(String aptId) =>
      _bills.where((b) => b.apartmentId == aptId).toList();

  static List<BillPayment> paymentsForBill(String billId) =>
      _payments.where((p) => p.billId == billId).toList();

  static List<BillPayment> paymentsForUser(String userId) =>
      _payments.where((p) => p.userId == userId).toList();

  static BillPayment? userPaymentForBill(String billId, String userId) {
    try {
      return _payments.firstWhere(
          (p) => p.billId == billId && p.userId == userId);
    } catch (_) {
      return null;
    }
  }

  /// Syncs static lists with Firestore-loaded data so DashboardProvider
  /// derives correct aggregates without requiring its own Firestore subscription.
  static void replaceAll(
      List<BillModel> bills, List<BillPayment> payments) {
    _bills
      ..clear()
      ..addAll(bills);
    _payments
      ..clear()
      ..addAll(payments);
  }
}
