import 'dart:math';

/// Semantic version comparison utility.
///
/// Splits version strings on `.` and compares each numeric segment, padding
/// shorter versions with zeroes. Handles any number of segments so that
/// `1.2.10 > 1.2.9` is evaluated correctly — unlike a plain string compare.
class VersionCompare {
  VersionCompare._();

  /// Returns a negative integer if [a] < [b],
  /// zero if [a] == [b],
  /// or a positive integer if [a] > [b].
  static int compare(String a, String b) {
    final aParts = _parse(a);
    final bParts = _parse(b);
    final length = max(aParts.length, bParts.length);

    for (int i = 0; i < length; i++) {
      final aVal = i < aParts.length ? aParts[i] : 0;
      final bVal = i < bParts.length ? bParts[i] : 0;
      final diff = aVal.compareTo(bVal);
      if (diff != 0) return diff;
    }
    return 0;
  }

  static bool isLessThan(String a, String b) => compare(a, b) < 0;
  static bool isGreaterThan(String a, String b) => compare(a, b) > 0;
  static bool isEqual(String a, String b) => compare(a, b) == 0;

  static List<int> _parse(String version) {
    return version
        .trim()
        .split('.')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .toList();
  }
}
