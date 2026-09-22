/// UPI ID format validator.
/// Note: This validates format only. It does NOT verify the UPI ID exists.
class UpiValidator {
  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) return 'UPI ID is required';
    final parts = value.trim().split('@');
    if (parts.length != 2) return 'Enter a valid UPI ID (e.g., name@upi)';
    if (parts[0].isEmpty) return 'Enter the part before @';
    if (parts[1].isEmpty) return 'Enter the part after @';
    return null;
  }

  static String normalize(String upiId) => upiId.trim().toLowerCase();
}
