import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/debt.dart';
import '../models/txn_entry.dart';
import '../models/wallet.dart';
import '../models/wallet_txn.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/money_text.dart';
import '../widgets/soft_card.dart';
import 'debts_screen.dart';
import 'goal_detail_screen.dart';
import 'wallet_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _q = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final results = _q.trim().isEmpty
        ? const _SearchResults.empty()
        : _runSearch(state, _q.trim().toLowerCase());

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: 'Search wallets, goals, debts, transactions…',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
            hintStyle: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.45),
              fontSize: 16,
            ),
          ),
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600),
          onChanged: (v) => setState(() => _q = v),
        ),
        actions: [
          if (_q.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _ctrl.clear();
                setState(() => _q = '');
              },
            ),
        ],
      ),
      body: _q.trim().isEmpty
          ? _Suggestions(state: state)
          : _ResultsList(results: results, query: _q.trim()),
    );
  }

  _SearchResults _runSearch(AppState state, String q) {
    final wallets = state.wallets
        .where((w) =>
            w.name.toLowerCase().contains(q) ||
            w.notes.toLowerCase().contains(q) ||
            w.category.label.toLowerCase().contains(q))
        .toList();

    final goals = state.goals
        .where((g) =>
            g.name.toLowerCase().contains(q) ||
            g.notes.toLowerCase().contains(q))
        .toList();

    final debts = state.debts
        .where((d) =>
            d.party.toLowerCase().contains(q) ||
            d.notes.toLowerCase().contains(q))
        .toList();

    final goalTxns = state.transactions
        .where((t) =>
            t.note.toLowerCase().contains(q) ||
            (state.goals
                    .where((g) => g.id == t.goalId)
                    .map((g) => g.name.toLowerCase())
                    .firstOrNull
                    ?.contains(q) ??
                false))
        .toList();

    final walletTxns = state.walletTxns
        .where((t) =>
            t.note.toLowerCase().contains(q) ||
            t.category.toLowerCase().contains(q) ||
            (state.wallets
                    .where((w) => w.id == t.walletId)
                    .map((w) => w.name.toLowerCase())
                    .firstOrNull
                    ?.contains(q) ??
                false))
        .toList();

    return _SearchResults(
      wallets: wallets,
      goals: goals,
      debts: debts,
      goalTxns: goalTxns,
      walletTxns: walletTxns,
    );
  }
}

class _SearchResults {
  const _SearchResults({
    this.wallets = const [],
    this.goals = const [],
    this.debts = const [],
    this.goalTxns = const [],
    this.walletTxns = const [],
  });
  const _SearchResults.empty()
      : wallets = const [],
        goals = const [],
        debts = const [],
        goalTxns = const [],
        walletTxns = const [];

  final List<Wallet> wallets;
  final List goals;
  final List<Debt> debts;
  final List<TxnEntry> goalTxns;
  final List<WalletTxn> walletTxns;

  bool get isEmpty =>
      wallets.isEmpty &&
      goals.isEmpty &&
      debts.isEmpty &&
      goalTxns.isEmpty &&
      walletTxns.isEmpty;

  int get total =>
      wallets.length +
      goals.length +
      debts.length +
      goalTxns.length +
      walletTxns.length;
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _hint(
            context,
            'Try searching by',
            const [
              '"BDO", "GCash", "Maya"',
              '"motor", "japan", "emergency"',
              '"salary", "snacks", "bills"',
              'a person\'s name for debts',
            ]),
        const SizedBox(height: 18),
        if (state.wallets.isNotEmpty)
          _quickRow(
            context,
            label: 'Wallets',
            chips: state.wallets.take(4).map((w) {
              return _Chip(emoji: w.emoji, text: w.name);
            }).toList(),
          ),
        if (state.goals.isNotEmpty)
          _quickRow(
            context,
            label: 'Goals',
            chips: state.goals.take(4).map((g) {
              return _Chip(emoji: g.emoji, text: g.name);
            }).toList(),
          ),
      ],
    );
  }

  Widget _hint(BuildContext context, String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.search,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _quickRow(BuildContext context,
      {required String label, required List<_Chip> chips}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.emoji, required this.text});
  final String emoji;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results, required this.query});
  final _SearchResults results;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded,
                  size: 36, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                'No matches for "$query"',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Try a wallet name, person, goal, or note.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            '${results.total} result${results.total == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 12,
              color:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
        ),
        if (results.wallets.isNotEmpty)
          _Group(
            title: 'Wallets',
            count: results.wallets.length,
            children: results.wallets
                .map((w) => _WalletResult(wallet: w))
                .toList(),
          ),
        if (results.goals.isNotEmpty)
          _Group(
            title: 'Goals',
            count: results.goals.length,
            children: results.goals
                .map<Widget>((g) => _GoalResult(goalId: (g as dynamic).id))
                .toList(),
          ),
        if (results.debts.isNotEmpty)
          _Group(
            title: 'Debts',
            count: results.debts.length,
            children:
                results.debts.map((d) => _DebtResult(debt: d)).toList(),
          ),
        if (results.walletTxns.isNotEmpty)
          _Group(
            title: 'Wallet transactions',
            count: results.walletTxns.length,
            children: results.walletTxns
                .map((t) => _WalletTxnResult(txn: t))
                .toList(),
          ),
        if (results.goalTxns.isNotEmpty)
          _Group(
            title: 'Goal transactions',
            count: results.goalTxns.length,
            children: results.goalTxns
                .map((t) => _GoalTxnResult(txn: t))
                .toList(),
          ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.count,
    required this.children,
  });
  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
            child: Text(
              '$title · $count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.6),
              ),
            ),
          ),
          ...children
              .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: c,
                  ))
              ,
        ],
      ),
    );
  }
}

class _WalletResult extends StatelessWidget {
  const _WalletResult({required this.wallet});
  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final color = Color(wallet.colorValue);
    return SoftCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WalletDetailScreen(walletId: wallet.id),
      )),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: Text(wallet.emoji,
                    style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wallet.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(wallet.category.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
          MoneyText(
            state.walletBalance(wallet.id),
            compact: true,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _GoalResult extends StatelessWidget {
  const _GoalResult({required this.goalId});
  final String goalId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final goal = state.goals.where((g) => g.id == goalId).firstOrNull;
    if (goal == null) return const SizedBox.shrink();
    final balance = state.balanceFor(goalId);
    return SoftCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GoalDetailScreen(goalId: goalId),
      )),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: Text(goal.emoji,
                    style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700)),
                Text(
                  goal.targetAmount == null
                      ? 'No target'
                      : '${(balance / goal.targetAmount! * 100).clamp(0, 100).toStringAsFixed(0)}% of target',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          MoneyText(
            balance,
            compact: true,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _DebtResult extends StatelessWidget {
  const _DebtResult({required this.debt});
  final Debt debt;

  @override
  Widget build(BuildContext context) {
    final isOwed = debt.direction == DebtDirection.owedToMe;
    final color = isOwed ? AppColors.success : AppColors.danger;
    return SoftCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const DebtsScreen(),
      )),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isOwed ? Icons.south_west : Icons.north_east,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(debt.party,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700)),
                Text(
                  isOwed ? 'Owes you' : 'You owe',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          MoneyText(
            debt.remaining,
            compact: true,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _WalletTxnResult extends StatelessWidget {
  const _WalletTxnResult({required this.txn});
  final WalletTxn txn;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final wallet =
        state.wallets.where((w) => w.id == txn.walletId).firstOrNull;
    final isCredit = txn.signedAmount >= 0;
    final color = isCredit ? AppColors.success : AppColors.danger;
    return SoftCard(
      onTap: wallet == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    WalletDetailScreen(walletId: wallet.id),
              )),
      padding: const EdgeInsets.all(14),
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
                isCredit ? Icons.south_west : Icons.north_east,
                color: color,
                size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.note.isNotEmpty
                      ? txn.note
                      : (txn.category.isNotEmpty
                          ? txn.category
                          : 'Transaction'),
                  style:
                      const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${wallet?.name ?? 'Wallet'} · ${DateFormat.MMMd().format(txn.date)}',
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
            txn.amount,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalTxnResult extends StatelessWidget {
  const _GoalTxnResult({required this.txn});
  final TxnEntry txn;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final goal =
        state.goals.where((g) => g.id == txn.goalId).firstOrNull;
    final isDeposit = txn.type == TxnType.deposit;
    final color = isDeposit ? AppColors.success : AppColors.danger;
    return SoftCard(
      onTap: goal == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => GoalDetailScreen(goalId: goal.id),
              )),
      padding: const EdgeInsets.all(14),
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
                  txn.note.isEmpty
                      ? (isDeposit ? 'Deposit' : 'Withdraw')
                      : txn.note,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${goal?.name ?? 'Goal'} · ${DateFormat.MMMd().format(txn.date)}',
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
            txn.amount,
            style: TextStyle(
                fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
