import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formats numeric input with comma thousand-separators while typing.
/// Pairs with `double.tryParse(text.replaceAll(',', ''))` on save.
///
/// Allows digits, optional decimal point, and up to [maxDecimals] decimals.
class ThousandsInputFormatter extends TextInputFormatter {
  ThousandsInputFormatter({this.maxDecimals = 2});
  final int maxDecimals;

  static final _intFmt = NumberFormat('#,###');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Strip out everything except digits and a single decimal point.
    final raw = text.replaceAll(',', '');
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(raw)) return oldValue;

    // Limit decimals
    if (raw.contains('.')) {
      final dec = raw.split('.')[1];
      if (dec.length > maxDecimals) return oldValue;
    }

    String formatted;
    if (raw.contains('.')) {
      final parts = raw.split('.');
      final intStr = parts[0].isEmpty ? '0' : parts[0];
      final decStr = parts.length > 1 ? parts[1] : '';
      final intVal = int.tryParse(intStr) ?? 0;
      formatted = '${_intFmt.format(intVal)}.$decStr';
    } else {
      final intVal = int.tryParse(raw) ?? 0;
      formatted = _intFmt.format(intVal);
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formats a stored numeric value for use as a TextField initial value
/// (no symbol, just thousand-grouped). Returns empty string for null/zero.
String formatAmountForField(num? value, {bool keepZero = false}) {
  if (value == null) return '';
  if (!keepZero && value == 0) return '';
  if (value == value.truncateToDouble()) {
    return NumberFormat('#,###').format(value);
  }
  return NumberFormat('#,###.##').format(value);
}
