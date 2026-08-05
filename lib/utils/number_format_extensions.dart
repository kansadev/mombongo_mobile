import 'package:intl/intl.dart';

/// Helper extension to safely format values that may be stored as strings.
///
/// The default [NumberFormat.format] expects a numeric input; passing a
/// `String` will crash with a `NoSuchMethodError` (see issue filed by user).
/// This extension parses string values to `double` before delegating to
/// the original method, falling back to `0` when parsing fails.
///
/// Use `formatSafe` instead of `format` when the input might be dynamic.
/// It mirrors the behaviour of `format` for numeric inputs.

extension NumberFormatSafe on NumberFormat {
  String formatSafe(dynamic value) {
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) {
        return format(parsed);
      }
      // If parsing fails we don't want to throw inside the library.
      // Fall back to formatting zero so callers still get a string.
      return format(0);
    }
    // delegate for all other types (num, BigInt, etc.).
    return format(value);
  }
}
