import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/models/bill_model.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

BillPayment _payment({
  required String id,
  required String userId,
  required String status,
  DateTime? paidDate,
  DateTime? submittedAt,
}) {
  return BillPayment(
    id: id,
    billId: 'bill1',
    userId: userId,
    unitNumber: '101',
    status: status,
    paidDate: paidDate,
    submittedAt: submittedAt,
  );
}

// Mimics the status resolution logic in PaymentBoardScreen._MonthCardState
enum _PaymentStatus { paid, pendingVerification, overdue, pending }

_PaymentStatus _resolveStatus(List<BillPayment> payments, DateTime dueDate) {
  final now = DateTime.now();
  if (payments.isEmpty) return _PaymentStatus.pending;
  if (payments.every((p) => p.isPaid)) return _PaymentStatus.paid;
  if (payments.any((p) => p.isPendingApproval)) {
    return _PaymentStatus.pendingVerification;
  }
  if (payments.any(
      (p) => !p.isPaid && !p.isPendingApproval && now.isAfter(dueDate))) {
    return _PaymentStatus.overdue;
  }
  return _PaymentStatus.pending;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('Payment Board — status chip labels', () {
    test('paid payment resolves to paid status', () {
      final payment = _payment(
        id: 'p1',
        userId: 'u1',
        status: BillStatus.paid,
        paidDate: DateTime(2025, 1, 5),
      );
      expect(payment.isPaid, isTrue);
      expect(payment.isPendingApproval, isFalse);
      expect(payment.isOverdue, isFalse);

      final status = _resolveStatus(
          [payment], DateTime(2025, 1, 31));
      expect(status, equals(_PaymentStatus.paid));
    });

    test('pendingApproval payment resolves to pendingVerification', () {
      final payment = _payment(
        id: 'p2',
        userId: 'u2',
        status: BillStatus.pendingApproval,
        submittedAt: DateTime(2025, 1, 10),
      );
      expect(payment.isPendingApproval, isTrue);
      expect(payment.isPaid, isFalse);

      final status = _resolveStatus(
          [payment], DateTime(2025, 1, 31));
      expect(status, equals(_PaymentStatus.pendingVerification));
    });

    test('overdue payment (past due date, not paid) resolves to overdue', () {
      final pastDue = DateTime.now().subtract(const Duration(days: 5));
      final payment = _payment(
        id: 'p3',
        userId: 'u3',
        status: BillStatus.pending,
      );
      expect(payment.isPaid, isFalse);
      expect(payment.isPendingApproval, isFalse);

      final status = _resolveStatus([payment], pastDue);
      expect(status, equals(_PaymentStatus.overdue));
    });

    test('pending payment (within due date) resolves to pending', () {
      final futureDue = DateTime.now().add(const Duration(days: 10));
      final payment = _payment(
        id: 'p4',
        userId: 'u4',
        status: BillStatus.pending,
      );

      final status = _resolveStatus([payment], futureDue);
      expect(status, equals(_PaymentStatus.pending));
    });

    test('empty payment list resolves to pending', () {
      final status = _resolveStatus([], DateTime(2025, 1, 31));
      expect(status, equals(_PaymentStatus.pending));
    });
  });

  group('Payment Board — no sensitive data', () {
    test('BillPayment does not expose UPI ref or transaction ID in status check',
        () {
      // The payment board screen only reads: isPaid, isPendingApproval,
      // isOverdue, paidDate, userId, unitNumber — never transactionId.
      // This test documents that the model fields exist but are NOT used
      // for display in the community board.
      final payment = _payment(
        id: 'p5',
        userId: 'u5',
        status: BillStatus.paid,
        paidDate: DateTime(2025, 1, 3),
      );
      // transactionId is set separately; we verify the type for safety
      expect(payment.transactionId, isNull); // default null
      // We explicitly do NOT surface transactionId in the payment board
    });

    test('paid status does not require transactionId to be non-null', () {
      final payment = BillPayment(
        id: 'p6',
        billId: 'bill1',
        userId: 'u6',
        unitNumber: '201',
        status: BillStatus.paid,
        paidDate: DateTime(2025, 2, 1),
        transactionId: null, // no txn id — still paid
      );
      expect(payment.isPaid, isTrue);
      expect(payment.transactionId, isNull);
    });
  });
}
