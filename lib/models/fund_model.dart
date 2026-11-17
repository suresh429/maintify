import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COMMUNITY FUND MODEL
//
// All monetary values stored in paise (integer) to avoid floating-point drift.
// ₹1 = 100 paise.
//
// Firestore structure:
//   fund_summary/{aptId}            — one summary doc per apartment
//   fund_transactions/{txnId}       — all transactions across all apartments
//     (each doc has an `apartmentId` field for queries)
// ─────────────────────────────────────────────────────────────────────────────

// Expense category names
class FundCategory {
  static const electrical = 'Electrical';
  static const plumbing = 'Plumbing';
  static const cleaning = 'Cleaning';
  static const gardening = 'Gardening';
  static const security = 'Security';
  static const painting = 'Painting';
  static const repairs = 'Repairs';
  static const equipment = 'Equipment';
  static const general = 'General';
  static const other = 'Other';

  static const List<String> all = [
    electrical,
    plumbing,
    cleaning,
    gardening,
    security,
    painting,
    repairs,
    equipment,
    general,
    other,
  ];
}

// Transaction types
class FundTxnType {
  static const collection = 'collection';
  static const expense = 'expense';
}

// ─────────────────────────────────────────────────────────────────────────────
// FUND SUMMARY
// ─────────────────────────────────────────────────────────────────────────────

class FundSummary {
  final String apartmentId;
  final int balancePaise;         // current balance
  final int totalCollectedPaise;  // cumulative income ever
  final int totalExpensedPaise;   // cumulative expenses ever
  final int transactionCount;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final String createdBy; // userId

  const FundSummary({
    required this.apartmentId,
    required this.balancePaise,
    required this.totalCollectedPaise,
    required this.totalExpensedPaise,
    required this.transactionCount,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.createdBy,
  });

  // Convenience getters (rupees)
  double get balance => balancePaise / 100;
  double get totalCollected => totalCollectedPaise / 100;
  double get totalExpensed => totalExpensedPaise / 100;

  FundSummary copyWith({
    int? balancePaise,
    int? totalCollectedPaise,
    int? totalExpensedPaise,
    int? transactionCount,
    DateTime? lastUpdatedAt,
  }) => FundSummary(
        apartmentId: apartmentId,
        balancePaise: balancePaise ?? this.balancePaise,
        totalCollectedPaise: totalCollectedPaise ?? this.totalCollectedPaise,
        totalExpensedPaise: totalExpensedPaise ?? this.totalExpensedPaise,
        transactionCount: transactionCount ?? this.transactionCount,
        createdAt: createdAt,
        lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
        createdBy: createdBy,
      );

  factory FundSummary.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FundSummary(
      apartmentId: d['apartmentId'] as String? ?? doc.id,
      balancePaise: (d['balancePaise'] as num?)?.toInt() ?? 0,
      totalCollectedPaise: (d['totalCollectedPaise'] as num?)?.toInt() ?? 0,
      totalExpensedPaise: (d['totalExpensedPaise'] as num?)?.toInt() ?? 0,
      transactionCount: (d['transactionCount'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdatedAt: (d['lastUpdatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: d['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'apartmentId': apartmentId,
        'balancePaise': balancePaise,
        'totalCollectedPaise': totalCollectedPaise,
        'totalExpensedPaise': totalExpensedPaise,
        'transactionCount': transactionCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt),
        'createdBy': createdBy,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// FUND TRANSACTION
// ─────────────────────────────────────────────────────────────────────────────

class FundTransaction {
  final String id;
  final String apartmentId;
  final String type;         // FundTxnType.collection | FundTxnType.expense
  final int amountPaise;
  final String description;
  final String category;     // FundCategory.* — meaningful for expenses
  final String createdBy;    // userId
  final String createdByName;
  final DateTime createdAt;
  final String? receiptNote; // optional note / receipt number

  const FundTransaction({
    required this.id,
    required this.apartmentId,
    required this.type,
    required this.amountPaise,
    required this.description,
    required this.category,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.receiptNote,
  });

  double get amount => amountPaise / 100;
  bool get isCollection => type == FundTxnType.collection;
  bool get isExpense => type == FundTxnType.expense;

  factory FundTransaction.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FundTransaction(
      id: doc.id,
      apartmentId: d['apartmentId'] as String? ?? '',
      type: d['type'] as String? ?? FundTxnType.collection,
      amountPaise: (d['amountPaise'] as num?)?.toInt() ?? 0,
      description: d['description'] as String? ?? '',
      category: d['category'] as String? ?? FundCategory.general,
      createdBy: d['createdBy'] as String? ?? '',
      createdByName: d['createdByName'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      receiptNote: d['receiptNote'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'apartmentId': apartmentId,
        'type': type,
        'amountPaise': amountPaise,
        'description': description,
        'category': category,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'createdAt': Timestamp.fromDate(createdAt),
        if (receiptNote != null && receiptNote!.isNotEmpty) 'receiptNote': receiptNote,
      };
}
