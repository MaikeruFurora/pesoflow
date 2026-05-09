import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

final NumberFormat _php = NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 2,
);

String formatMoney(num value) => _php.format(value);

String formatMoneyCompact(num value) {
  if (value.abs() >= 1000000) {
    return '₱${(value / 1000000).toStringAsFixed(value.abs() >= 10000000 ? 1 : 2)}M';
  }
  if (value.abs() >= 10000) {
    return '₱${(value / 1000).toStringAsFixed(value.abs() >= 100000 ? 0 : 1)}K';
  }
  return _php.format(value);
}

const String _hidden = '••••••';

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.value, {
    super.key,
    this.style,
    this.compact = false,
    this.respectHide = true,
  });

  final num value;
  final TextStyle? style;
  final bool compact;

  /// When false, always show the value (e.g. inside an edit form).
  final bool respectHide;

  @override
  Widget build(BuildContext context) {
    final hide = respectHide &&
        context.select<AppState, bool>((s) => s.hideBalances);
    final text = hide
        ? _hidden
        : (compact ? formatMoneyCompact(value) : formatMoney(value));
    return Text(text, style: style);
  }
}
