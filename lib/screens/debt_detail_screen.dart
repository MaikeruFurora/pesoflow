import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/debt.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/date_filter.dart';
import '../widgets/money_text.dart';
import '../widgets/row_actions.dart';
import '../widgets/soft_card.dart';
import 'debt_edit_sheet.dart';
import 'wallet_detail_screen.dart';

class DebtDetailScreen extends StatefulWidget {
  const DebtDetailScreen({super.key, required this.debtId});
  final String debtId;

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  DateFilter _filter = const DateFilter();
  String get debtId => widget.debtId;

  Color _statusColor(DebtStatus s) {
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

  String _statusLabel(DebtStatus s) {
    switch (s) {
      case DebtStatus.paid:
        return 'Paid in full';
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
    final state = context.watch<AppState>();
    final debt = state.debts.where((d) => d.id == debtId).firstOrNull;
    if (debt == null) {
      return const Scaffold(body: Center(child: Text('Debt removed')));
    }
    final isOwedToMe = debt.direction == DebtDirection.owedToMe;
    final accent = isOwedToMe ? AppColors.success : AppColors.danger;
    final progress = debt.originalAmount == 0
        ? 0.0
        : (debt.totalPaid / debt.originalAmount).clamp(0.0, 1.0);
    final statusColor = _statusColor(debt.status);

    final allPayments = [...debt.payments]
      ..sort((a, b) => b.date.compareTo(a.date));
    final payments =
        allPayments.where((p) => _filter.includes(p.date)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(debt.party),
        actions: [
          AppBarIconAction(
            icon: Icons.edit_outlined,
            tooltip: 'Edit',
            onTap: () => showDebtEditSheet(context, debt: debt),
          ),
          AppBarIconAction(
            icon: Icons.delete_outline,
            tooltip: 'Delete debt',
            danger: true,
            onTap: () => _confirmDeleteDebt(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          SoftCard(
            gradient: LinearGradient(
              colors: [accent, accent.withOpacity(0.78)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOwedToMe
                                ? Icons.south_west
                                : Icons.north_east,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOwedToMe ? 'Owes me' : 'I owe',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor == AppColors.success
                                  ? const Color(0xFFB6F8D0)
                                  : (statusColor == AppColors.warning
                                      ? const Color(0xFFFFE5B4)
                                      : const Color(0xFFFFC0BD)),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _statusLabel(debt.status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Remaining',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                MoneyText(
                  debt.remaining,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Paid ${(progress * 100).toStringAsFixed(0)}%',
                      style:
                          const TextStyle(color: Colors.white),
                    ),
                    const Spacer(),
                    if (debt.dueDate != null)
                      Text(
                        'Due ${DateFormat.MMMd().format(debt.dueDate!)}',
                        style:
                            const TextStyle(color: Colors.white70),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (debt.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            SoftCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sticky_note_2_outlined,
                      size: 18, color: accent),
                  const SizedBox(width: 10),
                  Expanded(child: Text(debt.notes)),
                ],
              ),
            ),
          ],
          if (debt.walletId != null) ...[
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final appState = context.read<AppState>();
              final w = appState.walletById(debt.walletId!);
              if (w == null) return const SizedBox.shrink();
              final wColor = Color(w.colorValue);
              final balance = appState.walletBalance(w.id);
              return SoftCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        WalletDetailScreen(walletId: w.id),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: wColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(w.emoji,
                            style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOwedToMe
                                ? 'Lent from ${w.name}'
                                : 'Received to ${w.name}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'Current balance · ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.55),
                                ),
                              ),
                              MoneyText(
                                balance,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: wColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.4),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MainAction(
                  icon: Icons.add_rounded,
                  label: debt.isPaid ? 'Add payment' : 'Record payment',
                  color: accent,
                  onTap: debt.isPaid
                      ? null
                      : () => showDebtPaymentSheet(context, debt: debt),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MainAction(
                  icon: Icons.edit_outlined,
                  label: 'Edit debt',
                  color: AppColors.primary,
                  outlined: true,
                  onTap: () => showDebtEditSheet(context, debt: debt),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StatRow(
            label: 'Original amount',
            value: debt.originalAmount,
          ),
          _StatRow(
            label: 'Total paid',
            value: debt.totalPaid,
            color: AppColors.success,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Payment history',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              if (allPayments.isNotEmpty)
                Text(
                  payments.length == allPayments.length
                      ? '${allPayments.length} total'
                      : '${payments.length} of ${allPayments.length}',
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
          if (allPayments.isNotEmpty) ...[
            const SizedBox(height: 8),
            DateFilterBar(
              value: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
          ],
          const SizedBox(height: 10),
          if (allPayments.isEmpty)
            SoftCard(
              padding: const EdgeInsets.all(22),
              child: Center(
                child: Text(
                  'No payments yet — record one to start tracking.',
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
          else if (payments.isEmpty)
            SoftCard(
              padding: const EdgeInsets.all(22),
              child: Center(
                child: Text(
                  'No payments in this range.',
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
            ...payments.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PaymentRow(
                    debtId: debt.id,
                    payment: p,
                    accent: accent,
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteDebt(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete debt?'),
        content: const Text(
            'Payment history will also be removed. This cannot be undone.'),
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
      await context.read<AppState>().deleteDebt(debtId);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

// --------------------------------------------------------------------------
// Payment row with inline edit/delete (no swipe needed)
// --------------------------------------------------------------------------
class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.debtId,
    required this.payment,
    required this.accent,
  });
  final String debtId;
  final DebtPayment payment;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.check_rounded, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MoneyText(
                  payment.amount,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Text(
                  [
                    DateFormat.yMMMd().format(payment.date),
                    if (payment.note.isNotEmpty) payment.note,
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.55),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (payment.walletId != null) ...[
                  const SizedBox(height: 4),
                  Builder(builder: (context) {
                    final appState = context.read<AppState>();
                    final w = appState.walletById(payment.walletId!);
                    if (w == null) return const SizedBox.shrink();
                    final wColor = Color(w.colorValue);
                    final balance = appState.walletBalance(w.id);
                    return InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              WalletDetailScreen(walletId: w.id),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: wColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(w.emoji,
                                style: const TextStyle(fontSize: 11)),
                            const SizedBox(width: 4),
                            Text(
                              w.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: wColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 1,
                              height: 10,
                              color: wColor.withOpacity(0.30),
                            ),
                            const SizedBox(width: 6),
                            MoneyText(
                              balance,
                              compact: true,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: wColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          RowMoreMenu(
            onEdit: () => showDebtPaymentSheet(
              context,
              debt: context.read<AppState>().debts.firstWhere(
                    (d) => d.id == debtId,
                  ),
              payment: payment,
            ),
            onDelete: () => _confirmDeletePayment(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePayment(BuildContext context) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this payment?'),
        content: const Text(
            'The amount will be added back to the remaining balance.'),
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
      await state.deleteDebtPayment(
        debtId: debtId,
        paymentId: payment.id,
      );
    }
  }
}

// --------------------------------------------------------------------------
// Reusable bits
// --------------------------------------------------------------------------

class _MainAction extends StatelessWidget {
  const _MainAction({
    required this.icon,
    required this.label,
    required this.color,
    this.outlined = false,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool outlined;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final bg = outlined ? Colors.white : color;
    final fg = outlined ? color : Colors.white;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: outlined ? Border.all(color: color) : null,
              boxShadow: outlined
                  ? null
                  : [
                      BoxShadow(
                        color: color.withOpacity(0.30),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.color,
  });
  final String label;
  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const Spacer(),
          MoneyText(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

