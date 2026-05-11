import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/txn_entry.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/date_filter.dart';
import '../widgets/money_text.dart';
import '../widgets/row_actions.dart';
import '../widgets/savings_jar.dart';
import '../widgets/soft_card.dart';
import 'goal_edit_sheet.dart';
import 'transaction_sheet.dart';

class GoalDetailScreen extends StatefulWidget {
  const GoalDetailScreen({super.key, required this.goalId});
  final String goalId;

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  DateFilter _filter = const DateFilter();
  String get goalId => widget.goalId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final goal = state.goals.where((g) => g.id == goalId).firstOrNull;
    if (goal == null) {
      return const Scaffold(body: Center(child: Text('Goal removed')));
    }
    final balance = state.balanceFor(goalId);
    final allTxns = state.txnsForGoal(goalId);
    final txns =
        allTxns.where((t) => _filter.includes(t.date)).toList();
    final progress = goal.targetAmount == null || goal.targetAmount == 0
        ? null
        : (balance / goal.targetAmount!).clamp(0.0, 1.0);
    final eta = _estimateCompletionDate(state, goalId);

    return Scaffold(
      appBar: AppBar(
        title: Text('${goal.emoji}  ${goal.name}'),
        actions: [
          AppBarIconAction(
            icon: Icons.edit_outlined,
            tooltip: 'Edit goal',
            onTap: () => showGoalEditSheet(context, goal: goal),
          ),
          AppBarIconAction(
            icon: Icons.delete_outline,
            tooltip: 'Delete goal',
            danger: true,
            onTap: () => _confirmDelete(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          if (progress != null) ...[
            SoftCard(
              padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 5,
                    child: SavingsJar(progress: progress),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Saved',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.55),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        MoneyText(
                          balance,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.flag_rounded,
                                  size: 12,
                                  color: AppColors.primary),
                              const SizedBox(width: 4),
                              MoneyText(
                                goal.targetAmount!,
                                compact: true,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (eta != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.event_available_outlined,
                                size: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.55),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ETA ${DateFormat.yMMMd().format(eta)}',
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else
            SoftCard(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saved',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  MoneyText(
                    balance,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'No target set — add one to see your jar fill up.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          if (goal.completedAt != null) ...[
            const SizedBox(height: 12),
            SoftCard(
              color: AppColors.success.withOpacity(0.12),
              child: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Goal reached on ${DateFormat.yMMMd().format(goal.completedAt!)}!',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (goal.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            SoftCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(goal.notes)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: goal.completedAt != null
                      ? null
                      : () => showTransactionSheet(
                            context,
                            goalId: goalId,
                            type: TxnType.deposit,
                          ),
                  icon: const Icon(Icons.add),
                  label: Text(goal.completedAt != null
                      ? 'Goal reached'
                      : 'Add money'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: balance <= 0
                      ? null
                      : () => showTransactionSheet(
                            context,
                            goalId: goalId,
                            type: TxnType.withdrawal,
                          ),
                  icon: const Icon(Icons.remove),
                  label: const Text('Withdraw'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          if (goal.completedAt != null && goal.targetAmount != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.55)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'You\'ve hit your target. Raise the goal amount to keep saving, or withdraw what you need.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Transaction history',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              if (allTxns.isNotEmpty)
                Text(
                  txns.length == allTxns.length
                      ? '${allTxns.length} total'
                      : '${txns.length} of ${allTxns.length}',
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
          if (allTxns.isNotEmpty) ...[
            const SizedBox(height: 8),
            DateFilterBar(
              value: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
          ],
          const SizedBox(height: 10),
          if (allTxns.isEmpty)
            SoftCard(
              padding: const EdgeInsets.all(22),
              child: Center(
                child: Text(
                  'No transactions yet — add money to start tracking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ),
            )
          else if (txns.isEmpty)
            SoftCard(
              padding: const EdgeInsets.all(22),
              child: Center(
                child: Text(
                  'No transactions in this range.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ),
            )
          else
            ...txns.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TxnTile(
                    t: t,
                    onDelete: () => _confirmDeleteTxn(t.id),
                  ),
                )),
        ],
      ),
    );
  }

  DateTime? _estimateCompletionDate(AppState state, String goalId) {
    final goal = state.goals.firstWhere((g) => g.id == goalId);
    if (goal.targetAmount == null) return null;
    final balance = state.balanceFor(goalId);
    final remaining = goal.targetAmount! - balance;
    if (remaining <= 0) return null;
    final txns = state.txnsForGoal(goalId)
        .where((t) => t.type == TxnType.deposit)
        .toList();
    if (txns.length < 2) return null;
    final earliest =
        txns.map((t) => t.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final days = DateTime.now().difference(earliest).inDays;
    if (days <= 0) return null;
    final totalDeposits =
        txns.fold<double>(0, (s, t) => s + t.amount);
    final perDay = totalDeposits / days;
    if (perDay <= 0) return null;
    final daysLeft = (remaining / perDay).ceil();
    return DateTime.now().add(Duration(days: daysLeft));
  }

  Future<void> _confirmDeleteTxn(String txnId) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this transaction?'),
        content: const Text(
            'The amount will be removed from your goal\'s balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.deleteTransaction(txnId);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete goal?'),
        content: const Text(
            'This will remove the goal and all its transactions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppState>().deleteGoal(goalId);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _TxnTile extends StatelessWidget {
  const _TxnTile({required this.t, this.onDelete});
  final TxnEntry t;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isDeposit = t.type == TxnType.deposit;
    final color = isDeposit ? AppColors.success : AppColors.danger;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDeposit ? Icons.south_west : Icons.north_east,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.note.isEmpty
                      ? (isDeposit ? 'Deposit' : 'Withdraw')
                      : t.note,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  DateFormat.yMMMd().add_jm().format(t.date),
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
            t.amount,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          if (onDelete != null) RowMoreMenu(onDelete: onDelete),
        ],
      ),
    );
  }
}
