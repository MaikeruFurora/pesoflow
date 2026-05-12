import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/wallet_txn.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/money_text.dart';
import '../widgets/soft_card.dart';

/// Spending insights screen.
///
/// Aggregates wallet transactions for a selected month and surfaces:
/// - Income / Expense / Net headline chips
/// - Expense breakdown by category (donut + legend)
/// - Daily expense trend (bar chart)
///
/// Internal transfers (transferIn/transferOut) are excluded because they
/// don't change net worth — only true income and expense are counted.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final monthStart = _month;
    final monthEnd = DateTime(_month.year, _month.month + 1);
    final txns = state.walletTxns
        .where((t) =>
            !t.date.isBefore(monthStart) && t.date.isBefore(monthEnd))
        .where((t) => !t.isTransfer)
        .toList();

    double income = 0;
    double expense = 0;
    final byCategory = <String, double>{};
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final dailyExpense = List<double>.filled(daysInMonth, 0);

    for (final t in txns) {
      if (t.type == WalletTxnType.income) {
        income += t.amount;
      } else if (t.type == WalletTxnType.expense) {
        expense += t.amount;
        final key = t.category.trim().isEmpty
            ? 'Uncategorized'
            : t.category.trim();
        byCategory[key] = (byCategory[key] ?? 0) + t.amount;
        final dayIdx = t.date.day - 1;
        if (dayIdx >= 0 && dayIdx < dailyExpense.length) {
          dailyExpense[dayIdx] += t.amount;
        }
      }
    }
    final net = income - expense;

    final now = DateTime.now();
    final isCurrentMonth =
        _month.year == now.year && _month.month == now.month;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _MonthSwitcher(
            label: DateFormat.yMMMM().format(_month),
            onPrev: () => _shiftMonth(-1),
            onNext: isCurrentMonth ? null : () => _shiftMonth(1),
          ),
          const SizedBox(height: 16),
          _SummaryRow(income: income, expense: expense, net: net),
          const SizedBox(height: 18),
          if (expense > 0) ...[
            _CategoryDonutCard(byCategory: byCategory, total: expense),
            const SizedBox(height: 14),
            _DailyTrendCard(
              dailyExpense: dailyExpense,
              month: _month,
            ),
            const SizedBox(height: 14),
            _TopCategoriesCard(byCategory: byCategory, total: expense),
          ] else
            const _EmptyState(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Month --
class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ArrowBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
        Expanded(
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        _ArrowBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  const _ArrowBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return IconButton(
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: enabled
            ? AppColors.primarySoft
            : AppColors.primarySoft.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        minimumSize: const Size(44, 44),
      ),
      icon: Icon(
        icon,
        color: enabled
            ? AppColors.primary
            : AppColors.primary.withOpacity(0.4),
      ),
    );
  }
}

// -------------------------------------------------------------- Summary --
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.income,
    required this.expense,
    required this.net,
  });

  final double income;
  final double expense;
  final double net;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            label: 'Income',
            value: income,
            color: AppColors.success,
            icon: Icons.south_west_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Expense',
            value: expense,
            color: AppColors.danger,
            icon: Icons.north_east_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Net',
            value: net,
            color: net >= 0 ? AppColors.primary : AppColors.warning,
            icon: net >= 0
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.55),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          MoneyText(
            value,
            compact: true,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- Donut --
class _CategoryDonutCard extends StatelessWidget {
  const _CategoryDonutCard({required this.byCategory, required this.total});

  final Map<String, double> byCategory;
  final double total;

  static const _palette = [
    AppColors.primary,
    Color(0xFF22D3EE),
    Color(0xFFFFB26B),
    Color(0xFFEF6F6C),
    Color(0xFF52C28F),
    Color(0xFFB088F9),
    Color(0xFFF5C26B),
    Color(0xFF6B7785),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // Top 7 + "Other"
    const maxSlices = 7;
    final shown = entries.take(maxSlices).toList();
    final otherTotal = entries
        .skip(maxSlices)
        .fold<double>(0, (s, e) => s + e.value);
    final slices = [
      ...shown,
      if (otherTotal > 0) MapEntry('Other', otherTotal),
    ];

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spending by category',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: PieChart(
                      PieChartData(
                        sections: [
                          for (var i = 0; i < slices.length; i++)
                            PieChartSectionData(
                              value: slices[i].value,
                              color: _palette[i % _palette.length],
                              title: '',
                              radius: 34,
                              showTitle: false,
                            ),
                        ],
                        centerSpaceRadius: 32,
                        sectionsSpace: 2,
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < slices.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _palette[i % _palette.length],
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  slices[i].key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '${((slices[i].value / total) * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------- Daily trend --
class _DailyTrendCard extends StatelessWidget {
  const _DailyTrendCard({required this.dailyExpense, required this.month});

  final List<double> dailyExpense;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final maxV = dailyExpense.fold<double>(0, math.max);
    final dayCount = dailyExpense.length;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily expense',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxV == 0 ? 10 : maxV * 1.15,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (v, meta) {
                        final day = v.toInt() + 1;
                        // Show labels at 1, 7, 14, 21, 28, last
                        final isLabel = day == 1 ||
                            day == 7 ||
                            day == 14 ||
                            day == 21 ||
                            day == 28 ||
                            day == dayCount;
                        if (!isLabel) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '$day',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < dailyExpense.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: dailyExpense[i],
                          color: dailyExpense[i] == maxV && maxV > 0
                              ? AppColors.danger
                              : AppColors.primary,
                          width: 5,
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------- Top categories --
class _TopCategoriesCard extends StatelessWidget {
  const _TopCategoriesCard({required this.byCategory, required this.total});

  final Map<String, double> byCategory;
  final double total;

  @override
  Widget build(BuildContext context) {
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(5).toList();
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top categories',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < top.length; i++) ...[
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '#${i + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        top[i].key,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: top[i].value / total,
                          minHeight: 5,
                          backgroundColor:
                              AppColors.primarySoft.withOpacity(0.5),
                          valueColor: const AlwaysStoppedAnimation(
                              AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                MoneyText(
                  top[i].value,
                  compact: true,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (i < top.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Empty --
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.insights_rounded,
              size: 56,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.18),
            ),
            const SizedBox(height: 14),
            const Text(
              'No expenses this month yet',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Log a few wallet transactions and your spending\nbreakdown will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.55),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
