import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/txn_entry.dart';
import '../models/wallet.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/money_text.dart';
import '../widgets/soft_card.dart';
import 'goal_detail_screen.dart';
import 'search_screen.dart';
import 'wallet_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    this.onSeeAllGoals,
    this.onSeeDebts,
    this.onSeeWallets,
  });

  final VoidCallback? onSeeAllGoals;
  final VoidCallback? onSeeDebts;
  final VoidCallback? onSeeWallets;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final greeting = _greeting();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your Ipon',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Search',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SearchScreen(),
                        ),
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primarySoft,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: const Size(44, 44),
                      ),
                      icon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: state.hideBalances
                          ? 'Show balances'
                          : 'Hide balances',
                      onPressed: () => state.toggleHideBalances(),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primarySoft,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: const Size(44, 44),
                      ),
                      icon: Icon(
                        state.hideBalances
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            _NetWorthCard(
              assets: state.totalAssets,
              netWorth: state.netWorth,
              owedToMe: state.totalOwedToMe,
              activeGoals: state.goals
                  .where((g) => g.completedAt == null)
                  .length,
              completedGoals: state.goals
                  .where((g) => g.completedAt != null)
                  .length,
            ),
            const SizedBox(height: 16),
            _DebtSummaryRow(
              owed: state.totalOwedToMe,
              iOwe: state.totalIOwe,
              onTap: onSeeDebts,
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Wallets',
              actionLabel: 'See all',
              onAction: onSeeWallets,
            ),
            const SizedBox(height: 12),
            if (state.wallets.isEmpty)
              SoftCard(
                onTap: onSeeWallets,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add your first wallet',
                            style: TextStyle(
                                fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Track money across BDO, GCash, Maya, cash…',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              )
            else
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.wallets.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final w = state.wallets[i];
                    final color = Color(w.colorValue);
                    return SizedBox(
                      width: 200,
                      child: SoftCard(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                WalletDetailScreen(walletId: w.id),
                          ),
                        ),
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.75)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withOpacity(0.22),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(w.emoji,
                                        style: const TextStyle(
                                            fontSize: 20)),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withOpacity(0.22),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    w.category.label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              w.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            MoneyText(
                              state.walletBalance(w.id),
                              compact: true,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
            const _SectionHeader(
              title: 'Savings activity',
              subtitle: 'Last 7 days (deposits)',
            ),
            const SizedBox(height: 12),
            _ActivityChart(values: state.dailyDepositsLastDays(7)),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Active goals',
              actionLabel: 'See all',
              onAction: onSeeAllGoals,
            ),
            const SizedBox(height: 12),
            if (state.goals.isEmpty)
              SoftCard(
                child: Column(
                  children: [
                    const Icon(Icons.flag_outlined,
                        size: 36, color: AppColors.primary),
                    const SizedBox(height: 8),
                    Text(
                      'No goals yet',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create your first ipon goal to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...state.goals.take(3).map(
                    (g) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _GoalRow(goalId: g.id),
                    ),
                  ),
            const SizedBox(height: 16),
            const _SectionHeader(title: 'Recent activity'),
            const SizedBox(height: 12),
            _RecentActivity(),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Magandang umaga ☀️';
    if (h < 18) return 'Magandang hapon 🌤';
    return 'Magandang gabi 🌙';
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({
    required this.assets,
    required this.netWorth,
    required this.owedToMe,
    required this.activeGoals,
    required this.completedGoals,
  });

  final double assets;
  final double netWorth;
  final double owedToMe;
  final int activeGoals;
  final int completedGoals;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      gradient: const LinearGradient(
        colors: [AppColors.primary, AppColors.primaryDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total assets',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Local only',
                      style:
                          TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          MoneyText(
            assets,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.account_balance_outlined,
                  size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              const Text('Net worth: ',
                  style:
                      TextStyle(color: Colors.white70, fontSize: 12)),
              MoneyText(
                netWorth,
                compact: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PillStat(
                    label: 'Active goals',
                    value: activeGoals.toString()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PillStat(
                    label: 'Completed',
                    value: completedGoals.toString()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillStat extends StatelessWidget {
  const _PillStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DebtSummaryRow extends StatelessWidget {
  const _DebtSummaryRow({
    required this.owed,
    required this.iOwe,
    this.onTap,
  });
  final double owed;
  final double iOwe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SoftCard(
            onTap: onTap,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.south_west,
                          color: AppColors.success, size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Text('Owed to me',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                MoneyText(
                  owed,
                  compact: true,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SoftCard(
            onTap: onTap,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.north_east,
                          color: AppColors.danger, size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Text('I owe',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                MoneyText(
                  iOwe,
                  compact: true,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
          ],
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<double>(0, (a, b) => a > b ? a : b);
    final has = maxV > 0;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SizedBox(
        height: 140,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: has ? maxV * 1.25 : 100,
            barTouchData: BarTouchData(enabled: false),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= 7) return const SizedBox();
                    final d = DateTime.now().subtract(Duration(days: 6 - i));
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        DateFormat('E').format(d).substring(0, 1),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.55),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < values.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: values[i],
                      width: 14,
                      borderRadius: BorderRadius.circular(6),
                      color: AppColors.primary,
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: has ? maxV * 1.25 : 100,
                        color: AppColors.primarySoft.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goalId});
  final String goalId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final goal = state.goals.firstWhere((g) => g.id == goalId);
    final balance = state.balanceFor(goalId);
    final progress = goal.targetAmount == null || goal.targetAmount == 0
        ? null
        : (balance / goal.targetAmount!).clamp(0.0, 1.0);

    return SoftCard(
      padding: const EdgeInsets.all(14),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => GoalDetailScreen(goalId: goal.id),
        ));
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(goal.emoji,
                  style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        goal.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    MoneyText(
                      balance,
                      compact: true,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (progress != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor:
                          AppColors.primarySoft.withOpacity(0.6),
                      valueColor: const AlwaysStoppedAnimation(
                          AppColors.primary),
                    ),
                  )
                else
                  Text(
                    'No target set',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.55),
                    ),
                  ),
                if (progress != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}% of ${formatMoneyCompact(goal.targetAmount!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final entries = <_ActivityEntry>[
      ...state.transactions.take(8).map(
            (t) => _ActivityEntry(
              date: t.date,
              icon: t.type == TxnType.deposit
                  ? Icons.south_west
                  : Icons.north_east,
              color: t.type == TxnType.deposit
                  ? AppColors.success
                  : AppColors.danger,
              title: t.note.isEmpty
                  ? (t.type == TxnType.deposit
                      ? 'Goal deposit'
                      : 'Goal withdraw')
                  : t.note,
              subtitle: state.goals
                      .where((g) => g.id == t.goalId)
                      .map((g) => '${g.emoji} ${g.name}')
                      .firstOrNull ??
                  'Goal',
              amount: t.amount,
              isCredit: t.type == TxnType.deposit,
            ),
          ),
      ...state.walletTxns.take(8).map(
            (t) => _ActivityEntry(
              date: t.date,
              icon: switch (t.type) {
                _ => t.signedAmount >= 0
                    ? Icons.south_west
                    : Icons.north_east,
              },
              color: switch (t.type.name) {
                'income' => AppColors.success,
                'expense' => AppColors.danger,
                _ => AppColors.primary,
              },
              title: t.note.isNotEmpty
                  ? t.note
                  : (t.category.isNotEmpty
                      ? t.category
                      : _walletTxnTypeLabel(t.type.name)),
              subtitle: state.wallets
                      .where((w) => w.id == t.walletId)
                      .map((w) => '${w.emoji} ${w.name}')
                      .firstOrNull ??
                  'Wallet',
              amount: t.amount,
              isCredit: t.signedAmount >= 0,
            ),
          ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    if (entries.isEmpty) {
      return SoftCard(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No activity yet — add a wallet, goal, or transaction.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
    }

    return Column(
      children: entries.take(6).map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SoftCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: e.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(e.icon, size: 18, color: e.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${e.subtitle} · ${DateFormat.MMMd().format(e.date)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                MoneyText(
                  e.amount,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: e.isCredit
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  static String _walletTxnTypeLabel(String typeName) {
    switch (typeName) {
      case 'income':
        return 'Income';
      case 'expense':
        return 'Expense';
      case 'transferIn':
        return 'Transfer in';
      case 'transferOut':
        return 'Transfer out';
      default:
        return typeName;
    }
  }
}

class _ActivityEntry {
  _ActivityEntry({
    required this.date,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
  });
  final DateTime date;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final double amount;
  final bool isCredit;
}
