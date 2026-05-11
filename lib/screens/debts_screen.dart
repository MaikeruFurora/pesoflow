import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/debt.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/money_text.dart';
import '../widgets/soft_card.dart';
import 'debt_detail_screen.dart';
import 'debt_edit_sheet.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});
  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  // null = "All"; otherwise filter by this single status
  DebtStatus? _statusFilter;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool _matches(Debt d) =>
      _statusFilter == null || d.status == _statusFilter;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final owed = state.debts
        .where((d) => d.direction == DebtDirection.owedToMe)
        .toList();
    final iOwe =
        state.debts.where((d) => d.direction == DebtDirection.iOwe).toList();
    final owedFiltered = owed.where(_matches).toList();
    final iOweFiltered = iOwe.where(_matches).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debt Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showDebtEditSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    title: 'Total owed to me',
                    amount: state.totalOwedToMe,
                    color: AppColors.success,
                    icon: Icons.south_west,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryTile(
                    title: 'Total I owe',
                    amount: state.totalIOwe,
                    color: AppColors.danger,
                    icon: Icons.north_east,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabs,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              dividerColor: Colors.transparent,
              unselectedLabelColor: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.55),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              tabs: [
                Tab(text: 'Owed to me (${owedFiltered.length})'),
                Tab(text: 'I owe (${iOweFiltered.length})'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _StatusFilterBar(
              value: _statusFilter,
              onChanged: (s) => setState(() => _statusFilter = s),
              counts: _countsByStatus([...owed, ...iOwe]),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _DebtList(debts: owedFiltered),
                _DebtList(debts: iOweFiltered),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<DebtStatus, int> _countsByStatus(List<Debt> all) {
    final m = <DebtStatus, int>{};
    for (final d in all) {
      m[d.status] = (m[d.status] ?? 0) + 1;
    }
    return m;
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({
    required this.value,
    required this.onChanged,
    required this.counts,
  });

  final DebtStatus? value;
  final ValueChanged<DebtStatus?> onChanged;
  final Map<DebtStatus, int> counts;

  static const _statusOrder = [
    DebtStatus.overdue,
    DebtStatus.dueSoon,
    DebtStatus.upcoming,
    DebtStatus.paid,
  ];

  Color _color(DebtStatus s) {
    switch (s) {
      case DebtStatus.paid:
        return AppColors.success;
      case DebtStatus.upcoming:
        return AppColors.success;
      case DebtStatus.dueSoon:
        return AppColors.warning;
      case DebtStatus.overdue:
        return AppColors.danger;
    }
  }

  String _label(DebtStatus s) {
    switch (s) {
      case DebtStatus.paid:
        return 'Paid';
      case DebtStatus.upcoming:
        return 'On track';
      case DebtStatus.dueSoon:
        return 'Due soon';
      case DebtStatus.overdue:
        return 'Overdue';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _Chip(
            label: 'All',
            selected: value == null,
            color: AppColors.primary,
            onTap: () => onChanged(null),
          ),
          ..._statusOrder.map((s) {
            final n = counts[s] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _Chip(
                label: n == 0 ? _label(s) : '${_label(s)} ($n)',
                color: _color(s),
                selected: value == s,
                onTap: () => onChanged(s),
                showDot: true,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.showDot = false,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDot) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Colors.white : color,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : color,
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

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });
  final String title;
  final double amount;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MoneyText(
            amount,
            compact: true,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DebtList extends StatelessWidget {
  const _DebtList({required this.debts});
  final List<Debt> debts;

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No entries here yet.',
            style: TextStyle(
              color:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: debts.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _DebtTile(debt: debts[i]),
      ),
    );
  }
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({required this.debt});
  final Debt debt;

  Color _statusColor() {
    switch (debt.status) {
      case DebtStatus.paid:
        return AppColors.success;
      case DebtStatus.upcoming:
        return AppColors.success;
      case DebtStatus.dueSoon:
        return AppColors.warning;
      case DebtStatus.overdue:
        return AppColors.danger;
    }
  }

  String _statusLabel() {
    switch (debt.status) {
      case DebtStatus.paid:
        return 'Paid';
      case DebtStatus.upcoming:
        return 'On track';
      case DebtStatus.dueSoon:
        return 'Due soon';
      case DebtStatus.overdue:
        return 'Overdue';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = debt.originalAmount == 0
        ? 0.0
        : (debt.totalPaid / debt.originalAmount).clamp(0.0, 1.0);
    final color = _statusColor();
    return SoftCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DebtDetailScreen(debtId: debt.id),
      )),
      padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    debt.direction == DebtDirection.owedToMe
                        ? Icons.south_west
                        : Icons.north_east,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.party,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _statusLabel(),
                            style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (debt.dueDate != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '· ${DateFormat.MMMd().format(debt.dueDate!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MoneyText(
                      debt.remaining,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'of ${_compact(debt.originalAmount)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      );
  }

  String _compact(double v) => formatMoneyCompact(v);
}
