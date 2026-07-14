import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/core/utils/app_utils.dart';

void main() {
  // ── AppUtils.displayFirstName ──────────────────────────────────────────────

  group('AppUtils.displayFirstName', () {
    test('skips single-letter initials', () {
      expect(AppUtils.displayFirstName('G. Srikanth'), 'Srikanth');
    });

    test('skips dot-terminated initials', () {
      expect(AppUtils.displayFirstName('A.B. Kumar'), 'Kumar');
    });

    test('returns first word when no initials present', () {
      expect(AppUtils.displayFirstName('Rohit Kumar'), 'Rohit');
    });

    test('single word name returns as-is', () {
      expect(AppUtils.displayFirstName('Ravi'), 'Ravi');
    });

    test('falls back to last part when all parts are initials', () {
      // "A. B." → last part wins
      expect(AppUtils.displayFirstName('A. B.'), 'B.');
    });

    test('handles leading/trailing whitespace', () {
      expect(AppUtils.displayFirstName('  Admin System  '), 'Admin');
    });
  });

  // ── AppUtils.formatCurrency ────────────────────────────────────────────────

  group('AppUtils.formatCurrency', () {
    test('formats whole rupee amounts with ₹ symbol', () {
      final result = AppUtils.formatCurrency(1000);
      expect(result, contains('₹'));
      expect(result, contains('1,000'));
    });

    test('formats zero as ₹0', () {
      final result = AppUtils.formatCurrency(0);
      expect(result, contains('₹'));
      expect(result, contains('0'));
    });

    test('formats large amounts with Indian grouping (lakhs/crores)', () {
      final result = AppUtils.formatCurrency(100000);
      expect(result, contains('₹'));
      // en_IN locale: 1,00,000
      expect(result, contains('1,00,000'));
    });

    test('drops decimal digits', () {
      final result = AppUtils.formatCurrency(1234.99);
      expect(result, isNot(contains('.')));
    });
  });

  // ── AppUtils.formatDate ────────────────────────────────────────────────────

  group('AppUtils.formatDate', () {
    test('formats date as dd MMM yyyy', () {
      final date = DateTime(2026, 6, 10);
      expect(AppUtils.formatDate(date), '10 Jun 2026');
    });

    test('pads single-digit day', () {
      final date = DateTime(2026, 1, 5);
      expect(AppUtils.formatDate(date), '05 Jan 2026');
    });
  });

  // ── AppUtils.formatMonthYear ───────────────────────────────────────────────

  group('AppUtils.formatMonthYear', () {
    test('formats as full month name and year', () {
      final date = DateTime(2026, 6, 1);
      expect(AppUtils.formatMonthYear(date), 'June 2026');
    });

    test('formats January correctly', () {
      final date = DateTime(2026, 1, 15);
      expect(AppUtils.formatMonthYear(date), 'January 2026');
    });
  });

  // ── AppUtils.formatDateTime ────────────────────────────────────────────────

  group('AppUtils.formatDateTime', () {
    test('includes both date and time parts', () {
      final dt = DateTime(2026, 6, 10, 14, 30); // 2:30 PM
      final result = AppUtils.formatDateTime(dt);
      expect(result, contains('10 Jun 2026'));
      expect(result, contains('02:30'));
    });
  });

  // ── AppUtils.timeAgo ───────────────────────────────────────────────────────

  group('AppUtils.timeAgo', () {
    test('just now for very recent timestamps', () {
      final now = DateTime.now().subtract(const Duration(seconds: 10));
      expect(AppUtils.timeAgo(now), 'just now');
    });

    test('minutes ago', () {
      final past = DateTime.now().subtract(const Duration(minutes: 5));
      expect(AppUtils.timeAgo(past), '5m ago');
    });

    test('hours ago', () {
      final past = DateTime.now().subtract(const Duration(hours: 3));
      expect(AppUtils.timeAgo(past), '3h ago');
    });

    test('days ago', () {
      final past = DateTime.now().subtract(const Duration(days: 2));
      expect(AppUtils.timeAgo(past), '2d ago');
    });

    test('older than 30 days returns formatted date', () {
      final old = DateTime.now().subtract(const Duration(days: 35));
      final result = AppUtils.timeAgo(old);
      // Should NOT contain "ago"
      expect(result, isNot(contains('ago')));
      // Should be a short date like "10 May"
      expect(result.split(' ').length, 2);
    });
  });
}
