import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wallet.dart';
import '../state/app_state.dart';
import '../widgets/money_text.dart';
import '../widgets/soft_card.dart';
import 'wallet_detail_screen.dart';
import 'wallet_edit_sheet.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final wallets = state.vaultWallets;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined,
                color: Color(0xFF2C3E72), size: 18),
            SizedBox(width: 8),
            Text('Secret vault'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add hidden wallet',
            onPressed: () => showWalletEditSheet(context, asVault: true),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Lock vault',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.lock_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: SoftCard(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F2A44), Color(0xFF2C3E72)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
                      const Text('Vault assets',
                          style: TextStyle(color: Colors.white70)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_off_outlined,
                                size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Hidden from dashboard',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MoneyText(
                    state.totalVaultAssets,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: wallets.isEmpty
                ? _Empty(onAdd: () =>
                    showWalletEditSheet(context, asVault: true))
                : ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    itemCount: wallets.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        _VaultWalletCard(wallet: wallets[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _VaultWalletCard extends StatelessWidget {
  const _VaultWalletCard({required this.wallet});
  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final balance = state.walletBalance(wallet.id);
    final color = Color(wallet.colorValue);
    final color2 = wallet.colorValue2 == 0
        ? color.withOpacity(0.7)
        : Color(wallet.colorValue2);
    return SoftCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WalletDetailScreen(walletId: wallet.id),
      )),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.18), color2.withOpacity(0.18)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
                child: Text(wallet.emoji,
                    style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallet.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2A44).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined,
                          size: 11, color: Color(0xFF1F2A44)),
                      const SizedBox(width: 4),
                      Text(
                        wallet.category.label,
                        style: const TextStyle(
                          color: Color(0xFF1F2A44),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          MoneyText(
            balance,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F2A44), Color(0xFF2C3E72)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.shield_outlined,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              'Your vault is empty',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Add a hidden wallet for emergency money or savings only you can see.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add hidden wallet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F2A44),
                minimumSize: const Size(220, 52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
