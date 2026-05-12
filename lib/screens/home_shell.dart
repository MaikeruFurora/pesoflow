import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';

import '../models/txn_entry.dart';
import '../models/wallet_txn.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'debt_edit_sheet.dart';
import 'debts_screen.dart';
import 'goal_edit_sheet.dart';
import 'goals_screen.dart';
import 'settings_screen.dart';
import 'transaction_sheet.dart';
import 'transfer_sheet.dart';
import 'wallet_edit_sheet.dart';
import 'wallet_txn_sheet.dart';
import 'wallets_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final QuickActions _quickActions = const QuickActions();
  String? _pendingShortcut;

  @override
  void initState() {
    super.initState();
    _setupQuickActions();
  }

  void _setupQuickActions() {
    _quickActions.initialize((type) {
      // The callback fires during cold-launch before the widget tree has the
      // context we need to show sheets. Buffer the action and replay it once
      // the first frame is rendered.
      _pendingShortcut = type;
      WidgetsBinding.instance.addPostFrameCallback((_) => _drainShortcut());
    });
    _quickActions.setShortcutItems(const [
      ShortcutItem(
        type: 'action_add_expense',
        localizedTitle: 'Add expense',
        icon: 'ic_shortcut_expense',
      ),
      ShortcutItem(
        type: 'action_save_goal',
        localizedTitle: 'Save to goal',
        icon: 'ic_shortcut_goal',
      ),
      ShortcutItem(
        type: 'action_transfer',
        localizedTitle: 'Transfer',
        icon: 'ic_shortcut_transfer',
      ),
    ]);
  }

  void _drainShortcut() {
    final type = _pendingShortcut;
    if (type == null || !mounted) return;
    _pendingShortcut = null;
    switch (type) {
      case 'action_add_expense':
        _quickAddExpense(context);
        break;
      case 'action_save_goal':
        _quickSaveMoney(context);
        break;
      case 'action_transfer':
        showTransferSheet(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        onSeeAllGoals: () => setState(() => _index = 2),
        onSeeWallets: () => setState(() => _index = 1),
        onSeeDebts: () => setState(() => _index = 3),
      ),
      const WalletsScreen(),
      const GoalsScreen(),
      const DebtsScreen(),
      const SettingsScreen(),
    ];

    Widget? fab;
    if (_index == 0) {
      fab = FloatingActionButton(
        onPressed: () => _showQuickAddMenu(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      );
    } else if (_index == 1) {
      fab = FloatingActionButton.extended(
        onPressed: () => showWalletEditSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('New wallet'),
      );
    } else if (_index == 2) {
      fab = FloatingActionButton.extended(
        onPressed: () => showGoalEditSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('New goal'),
      );
    } else if (_index == 3) {
      fab = FloatingActionButton.extended(
        onPressed: () => showDebtEditSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add debt'),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor:
            Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        indicatorColor: AppColors.primarySoft,
        height: 68,
        labelBehavior:
            NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Wallets',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag_rounded),
            label: 'Goals',
          ),
          NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            selectedIcon: Icon(Icons.handshake_rounded),
            label: 'Debts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Future<void> _showQuickAddMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(sheetCtx).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _quickTile(
                sheetCtx,
                icon: Icons.account_balance_wallet_rounded,
                label: 'New wallet',
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  showWalletEditSheet(context);
                },
              ),
              _quickTile(
                sheetCtx,
                icon: Icons.flag_rounded,
                label: 'New ipon goal',
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  showGoalEditSheet(context);
                },
              ),
              _quickTile(
                sheetCtx,
                icon: Icons.swap_horiz_rounded,
                label: 'Transfer between wallets',
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  showTransferSheet(context);
                },
              ),
              _quickTile(
                sheetCtx,
                icon: Icons.handshake_rounded,
                label: 'Add debt',
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  showDebtEditSheet(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickTile(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  // ---- Launcher shortcut handlers ---------------------------------------
  Future<void> _quickAddExpense(BuildContext context) async {
    final state = context.read<AppState>();
    final wallets = state.wallets;
    if (wallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a wallet first.')),
      );
      return;
    }
    String? walletId = wallets.length == 1
        ? wallets.first.id
        : await _pickFromList<String>(
            context,
            title: 'Pay from which wallet?',
            items: [
              for (final w in wallets)
                _PickerItem(
                  value: w.id,
                  emoji: w.emoji,
                  label: w.name,
                  subtitle:
                      '₱ ${state.walletBalance(w.id).toStringAsFixed(2)}',
                ),
            ],
          );
    if (walletId == null) return;
    if (!context.mounted) return;
    await showWalletTxnSheet(
      context,
      walletId: walletId,
      type: WalletTxnType.expense,
    );
  }

  Future<void> _quickSaveMoney(BuildContext context) async {
    final state = context.read<AppState>();
    final goals =
        state.goals.where((g) => g.completedAt == null).toList();
    if (goals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create an ipon goal first.')),
      );
      return;
    }
    String? goalId = goals.length == 1
        ? goals.first.id
        : await _pickFromList<String>(
            context,
            title: 'Save toward which goal?',
            items: [
              for (final g in goals)
                _PickerItem(
                  value: g.id,
                  emoji: g.emoji,
                  label: g.name,
                  subtitle: g.targetAmount == null
                      ? null
                      : '₱ ${state.balanceFor(g.id).toStringAsFixed(0)} / ₱ ${g.targetAmount!.toStringAsFixed(0)}',
                ),
            ],
          );
    if (goalId == null) return;
    if (!context.mounted) return;
    await showTransactionSheet(
      context,
      goalId: goalId,
      type: TxnType.deposit,
    );
  }

  Future<T?> _pickFromList<T>(
    BuildContext context, {
    required String title,
    required List<_PickerItem<T>> items,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            for (final it in items)
              ListTile(
                leading: Text(it.emoji,
                    style: const TextStyle(fontSize: 24)),
                title: Text(it.label,
                    style:
                        const TextStyle(fontWeight: FontWeight.w700)),
                subtitle:
                    it.subtitle == null ? null : Text(it.subtitle!),
                onTap: () => Navigator.of(sheetCtx).pop(it.value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PickerItem<T> {
  const _PickerItem({
    required this.value,
    required this.emoji,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String emoji;
  final String label;
  final String? subtitle;
}
