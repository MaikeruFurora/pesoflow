import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/wallet.dart';
import '../models/wallet_txn.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/date_filter.dart';
import '../widgets/money_text.dart';
import '../widgets/row_actions.dart';
import '../widgets/soft_card.dart';
import '../widgets/wallet_receive_card.dart';
import 'transfer_sheet.dart';
import 'wallet_edit_sheet.dart';
import 'wallet_txn_sheet.dart';

class WalletDetailScreen extends StatefulWidget {
  const WalletDetailScreen({super.key, required this.walletId});
  final String walletId;
  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  DateFilter _filter = DateFilter.month(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final wallet =
        state.wallets.where((w) => w.id == widget.walletId).firstOrNull;
    if (wallet == null) {
      return const Scaffold(body: Center(child: Text('Wallet removed')));
    }
    final color = Color(wallet.colorValue);
    final balance = state.walletBalance(widget.walletId);

    final allTxns = state.walletTxnsFor(widget.walletId);
    final filtered = allTxns.where((t) => _filter.includes(t.date)).toList();

    final filteredIncome = filtered
        .where((t) => t.type == WalletTxnType.income)
        .fold<double>(0, (s, t) => s + t.amount);
    final filteredExpense = filtered
        .where((t) => t.type == WalletTxnType.expense)
        .fold<double>(0, (s, t) => s + t.amount);
    final filteredTransferIn = filtered
        .where((t) => t.type == WalletTxnType.transferIn)
        .fold<double>(0, (s, t) => s + t.amount);
    final filteredTransferOut = filtered
        .where((t) => t.type == WalletTxnType.transferOut)
        .fold<double>(0, (s, t) => s + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text('${wallet.emoji}  ${wallet.name}'),
        actions: [
          AppBarIconAction(
            icon: Icons.edit_outlined,
            tooltip: 'Edit wallet',
            onTap: () => showWalletEditSheet(context, wallet: wallet),
          ),
          AppBarIconAction(
            icon: Icons.delete_outline,
            tooltip: 'Delete wallet',
            danger: true,
            onTap: _confirmDelete,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          SoftCard(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wallet.category.label,
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                MoneyText(
                  balance,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Current balance (all time)',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          if (wallet.qrFileName.isNotEmpty ||
              wallet.accountNumber.isNotEmpty) ...[
            const SizedBox(height: 12),
            WalletReceiveCard(wallet: wallet),
          ],
          if (wallet.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            SoftCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sticky_note_2_outlined,
                      size: 18, color: color),
                  const SizedBox(width: 10),
                  Expanded(child: Text(wallet.notes)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.south_west,
                  label: 'Income',
                  color: AppColors.success,
                  onTap: () => showWalletTxnSheet(
                    context,
                    walletId: widget.walletId,
                    type: WalletTxnType.income,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.north_east,
                  label: 'Expense',
                  color: AppColors.danger,
                  onTap: () => showWalletTxnSheet(
                    context,
                    walletId: widget.walletId,
                    type: WalletTxnType.expense,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Transfer',
                  color: AppColors.primary,
                  onTap: state.wallets.length < 2
                      ? null
                      : () => showTransferSheet(
                            context,
                            defaultFromId: widget.walletId,
                          ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text('Income & Expense',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              Text(
                _filter.label,
                style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DateFilterBar(
            value: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Income',
                  value: filteredIncome,
                  color: AppColors.success,
                  icon: Icons.south_west,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  label: 'Expense',
                  value: filteredExpense,
                  color: AppColors.danger,
                  icon: Icons.north_east,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Transferred in',
                  value: filteredTransferIn,
                  color: AppColors.primary,
                  icon: Icons.south_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  label: 'Transferred out',
                  value: filteredTransferOut,
                  color: AppColors.primary,
                  icon: Icons.north_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SoftCard(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Text('Net for period',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                MoneyText(
                  filteredIncome +
                      filteredTransferIn -
                      filteredExpense -
                      filteredTransferOut,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: (filteredIncome +
                                filteredTransferIn -
                                filteredExpense -
                                filteredTransferOut) >=
                            0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            filtered.isEmpty
                ? 'Transactions'
                : 'Transactions (${filtered.length})',
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            SoftCard(
              padding: const EdgeInsets.all(22),
              child: Center(
                child: Text(
                  allTxns.isEmpty
                      ? 'No transactions yet — add income or an expense to start.'
                      : 'No transactions in this range.',
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
            ..._groupByDay(filtered).entries.expand((e) {
              return [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                  child: Text(
                    DateFormat('EEE, MMM d, y').format(e.key),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.55),
                    ),
                  ),
                ),
                ...e.value.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TxnTile(
                        t: t,
                        onDelete: () => _confirmDeleteTxn(t),
                      ),
                    )),
              ];
            }),
        ],
      ),
    );
  }

  Map<DateTime, List<WalletTxn>> _groupByDay(List<WalletTxn> txns) {
    final map = <DateTime, List<WalletTxn>>{};
    for (final t in txns) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      (map[key] ??= []).add(t);
    }
    return map;
  }

  Future<void> _confirmDeleteTxn(WalletTxn t) async {
    final state = context.read<AppState>();
    final isTransfer = t.linkedTxnId != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isTransfer
            ? 'Delete this transfer?'
            : 'Delete this transaction?'),
        content: Text(isTransfer
            ? 'Both the in and out sides of this transfer will be removed.'
            : 'This will remove the transaction and adjust the wallet\'s balance.'),
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
      await state.deleteWalletTxn(t.id);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete wallet?'),
        content: const Text(
            'This will remove the wallet and all of its transactions. This cannot be undone.'),
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
    if (ok == true && mounted) {
      await context.read<AppState>().deleteWallet(widget.walletId);
      if (mounted) Navigator.of(context).pop();
    }
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.18)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
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

class _Stat extends StatelessWidget {
  const _Stat({
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MoneyText(
            value,
            compact: true,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  const _TxnTile({required this.t, this.onDelete});
  final WalletTxn t;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    Color color;
    IconData icon;
    String typeLabel;
    String? counterparty;
    switch (t.type) {
      case WalletTxnType.income:
        color = AppColors.success;
        icon = Icons.south_west;
        typeLabel = 'Income';
        break;
      case WalletTxnType.expense:
        color = AppColors.danger;
        icon = Icons.north_east;
        typeLabel = 'Expense';
        break;
      case WalletTxnType.transferIn:
        color = AppColors.primary;
        icon = Icons.south_rounded;
        typeLabel = 'Transfer in';
        counterparty = _findCounterparty(state, t);
        break;
      case WalletTxnType.transferOut:
        color = AppColors.primary;
        icon = Icons.north_rounded;
        typeLabel = 'Transfer out';
        counterparty = _findCounterparty(state, t);
        break;
    }

    final isCredit = t.signedAmount >= 0;
    return SoftCard(
      padding: EdgeInsets.fromLTRB(14, 12, onDelete == null ? 14 : 6, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.note.isNotEmpty
                      ? t.note
                      : (t.category.isNotEmpty ? t.category : typeLabel),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  [
                    if (counterparty != null) counterparty,
                    if (t.category.isNotEmpty && counterparty == null)
                      t.category,
                    DateFormat.jm().format(t.date),
                  ].join(' · '),
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
            style: TextStyle(
              color: isCredit ? color : AppColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onDelete != null) RowMoreMenu(onDelete: onDelete),
        ],
      ),
    );
  }

  String? _findCounterparty(AppState state, WalletTxn t) {
    if (t.linkedTxnId == null) return null;
    final pair = state.walletTxns
        .where((x) => x.linkedTxnId == t.linkedTxnId && x.id != t.id)
        .firstOrNull;
    if (pair == null) return null;
    final w =
        state.wallets.where((x) => x.id == pair.walletId).firstOrNull;
    if (w == null) return null;
    return t.type == WalletTxnType.transferIn
        ? 'from ${w.name}'
        : 'to ${w.name}';
  }
}
