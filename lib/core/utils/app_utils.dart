import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AppUtils {
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return DateFormat('dd MMM').format(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    Color? color,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: color ?? (isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Returns the best display first name, skipping single-letter initials.
  /// "G. Srikanth" → "Srikanth", "Rohit" → "Rohit", "Admin System" → "Admin"
  static String displayFirstName(String fullName) {
    final parts = fullName.trim().split(' ');
    for (final part in parts) {
      if (part.length > 1 && !part.endsWith('.')) return part;
    }
    return parts.last;
  }

  // ── Password generation ────────────────────────────────────────────────────

  /// Generates an admin password based on the apartment name.
  /// e.g., "Samhith Residency" → "Adm@Samh1th#X9"
  static String generateAdminPassword(String aptName) {
    final word = aptName.trim().split(RegExp(r'\s+')).first;
    final prefix = word.length >= 4 ? word.substring(0, 4) : word;
    final rest = word.length > 4 ? word.substring(4) : '';
    final transformed = rest.split('').map((c) {
      switch (c.toLowerCase()) {
        case 'i': return '1';
        case 'a': return '4';
        case 'e': return '3';
        case 'o': return '0';
        case 'u': return 'v';
        default: return c;
      }
    }).join();
    return 'Adm@$prefix$transformed#${_randomPasswordSuffix()}';
  }

  /// Generates a resident password based on name and flat number.
  /// e.g., "Ravi", "102" → "Usr@Rav102#K7"
  static String generateUserPassword(String userName, String flatNo) {
    final name = userName.trim();
    final first3 = name.length >= 3 ? name.substring(0, 3) : name;
    return 'Usr@$first3$flatNo#${_randomPasswordSuffix()}';
  }

  static String _randomPasswordSuffix() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    final rng = Random();
    return '${letters[rng.nextInt(letters.length)]}${rng.nextInt(10)}';
  }

  /// Shows a dialog with the generated login credentials for a new account.
  static Future<void> showGeneratedCredentials(
    BuildContext context, {
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.key_rounded, color: Color(0xFF1E3A8A), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Login Credentials',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            _credRow('Name', name),
            const Divider(height: 16),
            _credRow('Role', role),
            const Divider(height: 16),
            _credRow('Email', email),
            const Divider(height: 16),
            _credRow('Password', password, highlight: true),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Note this password — it cannot be recovered later.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: password));
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: const Text('Password copied!',
                      style: TextStyle(fontFamily: 'Poppins')),
                  backgroundColor: const Color(0xFF22C55E),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text(
              'Copy Password',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              elevation: 0,
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _credRow(String label, String value, {bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Text('  ',
            style: TextStyle(color: Color(0xFF64748B))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
              color: highlight ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A),
              letterSpacing: highlight ? 0.5 : 0,
            ),
          ),
        ),
      ],
    );
  }

  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (confirmColor ?? const Color(0xFF1E3A8A))
                    .withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.help_outline_rounded,
                color: confirmColor ?? const Color(0xFF1E3A8A),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),

            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF64748B)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      cancelText,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          confirmColor ?? const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      confirmText,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
