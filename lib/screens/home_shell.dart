import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'debt_edit_sheet.dart';
import 'debts_screen.dart';
import 'goal_edit_sheet.dart';
import 'goals_screen.dart';
import 'settings_screen.dart';
import 'transfer_sheet.dart';
import 'wallet_edit_sheet.dart';
import 'wallets_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

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
      fab = FloatingActionButton.extended(
        onPressed: () => _showQuickAddMenu(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
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
}
