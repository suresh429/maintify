// ─────────────────────────────────────────────────────────────────────────────
// BILL MODEL
// A bill is created at the apartment level by the Admin (President).
// The total amount is split equally across all flats → perFlatShare.
// Each flat's payment is tracked separately via BillPayment.
// ─────────────────────────────────────────────────────────────────────────────

class BillStatus {
  static const String paid = 'Paid';
  static const String pending = 'Pending';
  static const String overdue = 'Overdue';
  static const String partiallyPaid = 'Partial';
}

/// One bill for the entire apartment (not per-user).
class BillModel {
  final String id;
  final String apartmentId;
  final String createdByAdminId;
  final String title;
  final double totalAmount;
  final int totalFlats;       // snapshot of apartment.totalFlats at creation time
  final String category;
  final String month;         // e.g. "May 2026"
  final DateTime dueDate;
  final DateTime createdAt;

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
  });

  /// Core bill-split computation.
  double get perFlatShare => totalAmount / totalFlats;

  /// Aggregate status derived from payment records.
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
class BillPayment {
  final String id;
  final String billId;
  final String userId;
  final String unitNumber;
  String status;
  DateTime? paidDate;
  String? transactionId;
  bool adminVerified;

  BillPayment({
    required this.id,
    required this.billId,
    required this.userId,
    required this.unitNumber,
    required this.status,
    this.paidDate,
    this.transactionId,
    this.adminVerified = false,
  });

  bool get isPaid => status == BillStatus.paid;
  bool get isPending => status == BillStatus.pending;
  bool get isOverdue => status == BillStatus.overdue;

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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK DATA — Sai Residency (apt1, 10 flats) + Green Valley (apt2, 8 flats)
// ─────────────────────────────────────────────────────────────────────────────

class MockBillData {
  // ── Apt1: Sai Residency bills ─────────────────────────────────────────────
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
      category: 'Utilities',
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

    // ── Apt2: Green Valley Towers bills ──────────────────────────────────────
    BillModel(
      id: 'g1',
      apartmentId: 'apt2',
      createdByAdminId: 'u8',
      title: 'Monthly Maintenance',
      totalAmount: 1600,
      totalFlats: 8,
      category: 'Maintenance',
      month: 'May 2026',
      dueDate: DateTime(2026, 6, 10),
      createdAt: DateTime(2026, 5, 1),
    ),
    BillModel(
      id: 'g2',
      apartmentId: 'apt2',
      createdByAdminId: 'u8',
      title: 'Lift Repair Fund',
      totalAmount: 2400,
      totalFlats: 8,
      category: 'Maintenance',
      month: 'April 2026',
      dueDate: DateTime(2026, 5, 10),
      createdAt: DateTime(2026, 4, 1),
    ),
  ];

  // ── Payment records ───────────────────────────────────────────────────────
  // b1: Lift Maintenance ₹200/flat (May 2026, 10 flats)
  // b2: Water Charges ₹150/flat (May 2026, 10 flats)
  // b3: Security Charges ₹300/flat (April 2026, overdue for several)
  // b4: Cleaning Fund ₹100/flat (March 2026, all paid)
  static final List<BillPayment> _payments = [
    // ── b1: Lift Maintenance ─────────────────
    BillPayment(id: 'p1_u3',  billId: 'b1', userId: 'u3',  unitNumber: 'A-101', status: BillStatus.pending),
    BillPayment(id: 'p1_u4',  billId: 'b1', userId: 'u4',  unitNumber: 'A-102', status: BillStatus.pending),
    BillPayment(id: 'p1_u5',  billId: 'b1', userId: 'u5',  unitNumber: 'B-201', status: BillStatus.paid, paidDate: DateTime(2026, 5, 5), transactionId: 'TXN1B201', adminVerified: true),
    BillPayment(id: 'p1_u6',  billId: 'b1', userId: 'u6',  unitNumber: 'B-202', status: BillStatus.paid, paidDate: DateTime(2026, 5, 6), transactionId: 'TXN1B202', adminVerified: true),
    BillPayment(id: 'p1_u9',  billId: 'b1', userId: 'u9',  unitNumber: 'C-301', status: BillStatus.pending),
    BillPayment(id: 'p1_u10', billId: 'b1', userId: 'u10', unitNumber: 'C-302', status: BillStatus.paid, paidDate: DateTime(2026, 5, 4), transactionId: 'TXN1C302', adminVerified: true),
    BillPayment(id: 'p1_u11', billId: 'b1', userId: 'u11', unitNumber: 'D-401', status: BillStatus.pending),
    BillPayment(id: 'p1_u12', billId: 'b1', userId: 'u12', unitNumber: 'D-402', status: BillStatus.pending),
    BillPayment(id: 'p1_u13', billId: 'b1', userId: 'u13', unitNumber: 'E-501', status: BillStatus.overdue),
    BillPayment(id: 'p1_u14', billId: 'b1', userId: 'u14', unitNumber: 'E-502', status: BillStatus.paid, paidDate: DateTime(2026, 5, 3), transactionId: 'TXN1E502', adminVerified: true),

    // ── b2: Water Charges ────────────────────
    BillPayment(id: 'p2_u3',  billId: 'b2', userId: 'u3',  unitNumber: 'A-101', status: BillStatus.pending),
    BillPayment(id: 'p2_u4',  billId: 'b2', userId: 'u4',  unitNumber: 'A-102', status: BillStatus.paid, paidDate: DateTime(2026, 5, 7), transactionId: 'TXN2A102', adminVerified: true),
    BillPayment(id: 'p2_u5',  billId: 'b2', userId: 'u5',  unitNumber: 'B-201', status: BillStatus.paid, paidDate: DateTime(2026, 5, 8), transactionId: 'TXN2B201', adminVerified: true),
    BillPayment(id: 'p2_u6',  billId: 'b2', userId: 'u6',  unitNumber: 'B-202', status: BillStatus.pending),
    BillPayment(id: 'p2_u9',  billId: 'b2', userId: 'u9',  unitNumber: 'C-301', status: BillStatus.pending),
    BillPayment(id: 'p2_u10', billId: 'b2', userId: 'u10', unitNumber: 'C-302', status: BillStatus.paid, paidDate: DateTime(2026, 5, 5), transactionId: 'TXN2C302', adminVerified: true),
    BillPayment(id: 'p2_u11', billId: 'b2', userId: 'u11', unitNumber: 'D-401', status: BillStatus.pending),
    BillPayment(id: 'p2_u12', billId: 'b2', userId: 'u12', unitNumber: 'D-402', status: BillStatus.paid, paidDate: DateTime(2026, 5, 9), transactionId: 'TXN2D402', adminVerified: true),
    BillPayment(id: 'p2_u13', billId: 'b2', userId: 'u13', unitNumber: 'E-501', status: BillStatus.pending),
    BillPayment(id: 'p2_u14', billId: 'b2', userId: 'u14', unitNumber: 'E-502', status: BillStatus.pending),

    // ── b3: Security Charges (overdue) ────────
    BillPayment(id: 'p3_u3',  billId: 'b3', userId: 'u3',  unitNumber: 'A-101', status: BillStatus.overdue),
    BillPayment(id: 'p3_u4',  billId: 'b3', userId: 'u4',  unitNumber: 'A-102', status: BillStatus.paid, paidDate: DateTime(2026, 5, 2), transactionId: 'TXN3A102', adminVerified: true),
    BillPayment(id: 'p3_u5',  billId: 'b3', userId: 'u5',  unitNumber: 'B-201', status: BillStatus.overdue),
    BillPayment(id: 'p3_u6',  billId: 'b3', userId: 'u6',  unitNumber: 'B-202', status: BillStatus.paid, paidDate: DateTime(2026, 5, 1), transactionId: 'TXN3B202', adminVerified: true),
    BillPayment(id: 'p3_u9',  billId: 'b3', userId: 'u9',  unitNumber: 'C-301', status: BillStatus.overdue),
    BillPayment(id: 'p3_u10', billId: 'b3', userId: 'u10', unitNumber: 'C-302', status: BillStatus.overdue),
    BillPayment(id: 'p3_u11', billId: 'b3', userId: 'u11', unitNumber: 'D-401', status: BillStatus.overdue),
    BillPayment(id: 'p3_u12', billId: 'b3', userId: 'u12', unitNumber: 'D-402', status: BillStatus.paid, paidDate: DateTime(2026, 5, 3), transactionId: 'TXN3D402', adminVerified: true),
    BillPayment(id: 'p3_u13', billId: 'b3', userId: 'u13', unitNumber: 'E-501', status: BillStatus.overdue),
    BillPayment(id: 'p3_u14', billId: 'b3', userId: 'u14', unitNumber: 'E-502', status: BillStatus.overdue),

    // ── b4: Cleaning Fund (all paid) ──────────
    BillPayment(id: 'p4_u3',  billId: 'b4', userId: 'u3',  unitNumber: 'A-101', status: BillStatus.paid, paidDate: DateTime(2026, 4, 2), transactionId: 'TXN4A101', adminVerified: true),
    BillPayment(id: 'p4_u4',  billId: 'b4', userId: 'u4',  unitNumber: 'A-102', status: BillStatus.paid, paidDate: DateTime(2026, 4, 3), transactionId: 'TXN4A102', adminVerified: true),
    BillPayment(id: 'p4_u5',  billId: 'b4', userId: 'u5',  unitNumber: 'B-201', status: BillStatus.paid, paidDate: DateTime(2026, 4, 1), transactionId: 'TXN4B201', adminVerified: true),
    BillPayment(id: 'p4_u6',  billId: 'b4', userId: 'u6',  unitNumber: 'B-202', status: BillStatus.paid, paidDate: DateTime(2026, 4, 2), transactionId: 'TXN4B202', adminVerified: true),
    BillPayment(id: 'p4_u9',  billId: 'b4', userId: 'u9',  unitNumber: 'C-301', status: BillStatus.paid, paidDate: DateTime(2026, 4, 4), transactionId: 'TXN4C301', adminVerified: true),
    BillPayment(id: 'p4_u10', billId: 'b4', userId: 'u10', unitNumber: 'C-302', status: BillStatus.paid, paidDate: DateTime(2026, 4, 5), transactionId: 'TXN4C302', adminVerified: true),
    BillPayment(id: 'p4_u11', billId: 'b4', userId: 'u11', unitNumber: 'D-401', status: BillStatus.paid, paidDate: DateTime(2026, 4, 3), transactionId: 'TXN4D401', adminVerified: true),
    BillPayment(id: 'p4_u12', billId: 'b4', userId: 'u12', unitNumber: 'D-402', status: BillStatus.paid, paidDate: DateTime(2026, 4, 6), transactionId: 'TXN4D402', adminVerified: true),
    BillPayment(id: 'p4_u13', billId: 'b4', userId: 'u13', unitNumber: 'E-501', status: BillStatus.paid, paidDate: DateTime(2026, 4, 1), transactionId: 'TXN4E501', adminVerified: true),
    BillPayment(id: 'p4_u14', billId: 'b4', userId: 'u14', unitNumber: 'E-502', status: BillStatus.paid, paidDate: DateTime(2026, 4, 2), transactionId: 'TXN4E502', adminVerified: true),

    // ── g1: Green Valley Maintenance ──────────
    BillPayment(id: 'pg1_u7',  billId: 'g1', userId: 'u7',  unitNumber: 'A-101', status: BillStatus.paid, paidDate: DateTime(2026, 5, 5), transactionId: 'TXNG1A101', adminVerified: true),
    BillPayment(id: 'pg1_u15', billId: 'g1', userId: 'u15', unitNumber: 'A-102', status: BillStatus.pending),
    BillPayment(id: 'pg1_u16', billId: 'g1', userId: 'u16', unitNumber: 'B-201', status: BillStatus.paid, paidDate: DateTime(2026, 5, 6), transactionId: 'TXNG1B201', adminVerified: true),
    BillPayment(id: 'pg1_u17', billId: 'g1', userId: 'u17', unitNumber: 'B-202', status: BillStatus.pending),
    BillPayment(id: 'pg1_u18', billId: 'g1', userId: 'u18', unitNumber: 'C-301', status: BillStatus.paid, paidDate: DateTime(2026, 5, 4), transactionId: 'TXNG1C301', adminVerified: true),
    BillPayment(id: 'pg1_u19', billId: 'g1', userId: 'u19', unitNumber: 'C-302', status: BillStatus.pending),
    BillPayment(id: 'pg1_u20', billId: 'g1', userId: 'u20', unitNumber: 'D-401', status: BillStatus.pending),
    BillPayment(id: 'pg1_u21', billId: 'g1', userId: 'u21', unitNumber: 'D-402', status: BillStatus.paid, paidDate: DateTime(2026, 5, 7), transactionId: 'TXNG1D402', adminVerified: true),

    // ── g2: Green Valley Lift Repair ──────────
    BillPayment(id: 'pg2_u7',  billId: 'g2', userId: 'u7',  unitNumber: 'A-101', status: BillStatus.overdue),
    BillPayment(id: 'pg2_u15', billId: 'g2', userId: 'u15', unitNumber: 'A-102', status: BillStatus.paid, paidDate: DateTime(2026, 4, 28), transactionId: 'TXNG2A102', adminVerified: true),
    BillPayment(id: 'pg2_u16', billId: 'g2', userId: 'u16', unitNumber: 'B-201', status: BillStatus.overdue),
    BillPayment(id: 'pg2_u17', billId: 'g2', userId: 'u17', unitNumber: 'B-202', status: BillStatus.paid, paidDate: DateTime(2026, 5, 1), transactionId: 'TXNG2B202', adminVerified: true),
    BillPayment(id: 'pg2_u18', billId: 'g2', userId: 'u18', unitNumber: 'C-301', status: BillStatus.paid, paidDate: DateTime(2026, 5, 2), transactionId: 'TXNG2C301', adminVerified: true),
    BillPayment(id: 'pg2_u19', billId: 'g2', userId: 'u19', unitNumber: 'C-302', status: BillStatus.overdue),
    BillPayment(id: 'pg2_u20', billId: 'g2', userId: 'u20', unitNumber: 'D-401', status: BillStatus.overdue),
    BillPayment(id: 'pg2_u21', billId: 'g2', userId: 'u21', unitNumber: 'D-402', status: BillStatus.paid, paidDate: DateTime(2026, 5, 3), transactionId: 'TXNG2D402', adminVerified: true),
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
}
