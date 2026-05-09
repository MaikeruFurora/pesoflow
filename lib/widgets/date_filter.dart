import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

enum DateFilterMode { all, day, month, year, custom }

/// Inclusive date-range filter. [start] and [end] include the full day
/// boundaries (00:00:00.000 → 23:59:59.999).
class DateFilter {
  const DateFilter({
    this.mode = DateFilterMode.all,
    this.start,
    this.end,
  });

  final DateFilterMode mode;
  final DateTime? start;
  final DateTime? end;

  bool includes(DateTime d) {
    if (mode == DateFilterMode.all) return true;
    if (start != null && d.isBefore(start!)) return false;
    if (end != null && d.isAfter(end!)) return false;
    return true;
  }

  String get label {
    final f = DateFormat('MMM d, y');
    switch (mode) {
      case DateFilterMode.all:
        return 'All time';
      case DateFilterMode.day:
        return start == null ? 'Day' : f.format(start!);
      case DateFilterMode.month:
        return start == null
            ? 'Month'
            : DateFormat('MMMM y').format(start!);
      case DateFilterMode.year:
        return start == null
            ? 'Year'
            : DateFormat('y').format(start!);
      case DateFilterMode.custom:
        if (start == null || end == null) return 'Custom';
        return '${f.format(start!)} – ${f.format(end!)}';
    }
  }

  static DateFilter day(DateTime d) {
    final s = DateTime(d.year, d.month, d.day);
    final e = s.add(const Duration(days: 1)).subtract(
        const Duration(milliseconds: 1));
    return DateFilter(mode: DateFilterMode.day, start: s, end: e);
  }

  static DateFilter month(DateTime d) {
    final s = DateTime(d.year, d.month, 1);
    final e = DateTime(d.year, d.month + 1, 1)
        .subtract(const Duration(milliseconds: 1));
    return DateFilter(mode: DateFilterMode.month, start: s, end: e);
  }

  static DateFilter year(DateTime d) {
    final s = DateTime(d.year, 1, 1);
    final e = DateTime(d.year + 1, 1, 1)
        .subtract(const Duration(milliseconds: 1));
    return DateFilter(mode: DateFilterMode.year, start: s, end: e);
  }

  static DateFilter custom(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    return DateFilter(mode: DateFilterMode.custom, start: s, end: e);
  }
}

class DateFilterBar extends StatelessWidget {
  const DateFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateFilter value;
  final ValueChanged<DateFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _Chip(
            label: 'All',
            selected: value.mode == DateFilterMode.all,
            onTap: () => onChanged(const DateFilter()),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: value.mode == DateFilterMode.day ? value.label : 'Day',
            icon: Icons.today_outlined,
            selected: value.mode == DateFilterMode.day,
            onTap: () => _pickDay(context),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: value.mode == DateFilterMode.month
                ? value.label
                : 'Month',
            icon: Icons.calendar_view_month_outlined,
            selected: value.mode == DateFilterMode.month,
            onTap: () => _pickMonth(context),
          ),
          const SizedBox(width: 8),
          _Chip(
            label:
                value.mode == DateFilterMode.year ? value.label : 'Year',
            icon: Icons.calendar_today_outlined,
            selected: value.mode == DateFilterMode.year,
            onTap: () => _pickYear(context),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: value.mode == DateFilterMode.custom
                ? value.label
                : 'Custom range',
            icon: Icons.date_range_outlined,
            selected: value.mode == DateFilterMode.custom,
            onTap: () => _pickRange(context),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDay(BuildContext context) async {
    final initial = (value.mode == DateFilterMode.day && value.start != null)
        ? value.start!
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) onChanged(DateFilter.day(picked));
  }

  Future<void> _pickMonth(BuildContext context) async {
    final initial =
        (value.mode == DateFilterMode.month && value.start != null)
            ? value.start!
            : DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPickerDialog(initial: initial),
    );
    if (picked != null) onChanged(DateFilter.month(picked));
  }

  Future<void> _pickYear(BuildContext context) async {
    final initial =
        (value.mode == DateFilterMode.year && value.start != null)
            ? value.start!
            : DateTime.now();
    final picked = await showDialog<int>(
      context: context,
      builder: (_) => _YearPickerDialog(initialYear: initial.year),
    );
    if (picked != null) onChanged(DateFilter.year(DateTime(picked, 1, 1)));
  }

  Future<void> _pickRange(BuildContext context) async {
    final initial = value.mode == DateFilterMode.custom &&
            value.start != null &&
            value.end != null
        ? DateTimeRange(start: value.start!, end: value.end!)
        : DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: initial,
    );
    if (picked != null) {
      onChanged(DateFilter.custom(picked.start, picked.end));
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary
          : AppColors.primarySoft.withOpacity(0.7),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 14,
                    color: selected ? Colors.white : AppColors.primary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initial});
  final DateTime initial;
  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = widget.initial.year;
  late int _month = widget.initial.month;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick month'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '$_year',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: _year >= DateTime.now().year
                      ? null
                      : () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: List.generate(12, (i) {
                final m = i + 1;
                final selected = m == _month;
                final disabled = _year == DateTime.now().year &&
                    m > DateTime.now().month;
                return GestureDetector(
                  onTap: disabled ? null : () => setState(() => _month = m),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.primarySoft.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        DateFormat('MMM')
                            .format(DateTime(_year, m, 1)),
                        style: TextStyle(
                          color: disabled
                              ? Colors.grey
                              : (selected
                                  ? Colors.white
                                  : AppColors.primary),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(DateTime(_year, _month, 1)),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class _YearPickerDialog extends StatefulWidget {
  const _YearPickerDialog({required this.initialYear});
  final int initialYear;
  @override
  State<_YearPickerDialog> createState() => _YearPickerDialogState();
}

class _YearPickerDialogState extends State<_YearPickerDialog> {
  late int _year = widget.initialYear;
  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    return AlertDialog(
      title: const Text('Pick year'),
      content: SizedBox(
        width: 280,
        height: 240,
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: List.generate(12, (i) {
            final y = currentYear - i;
            final selected = y == _year;
            return GestureDetector(
              onTap: () => setState(() => _year = y),
              child: Container(
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.primarySoft.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '$y',
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_year),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
