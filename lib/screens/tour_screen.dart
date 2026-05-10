import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Quick Tour — shown automatically once after onboarding (PIN setup), and
/// re-openable any time from Settings → "Take the tour".
class TourScreen extends StatefulWidget {
  const TourScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<TourScreen> {
  final _ctrl = PageController();
  int _index = 0;

  late final List<_TourStep> _steps = const [
    _TourStep(
      icon: Icons.dashboard_rounded,
      title: 'Your money,\nat a glance.',
      body:
          'The Dashboard shows your net worth, total savings, and recent activity in one place. Tap the eye icon to hide balances when you hand your phone to someone.',
      tip: 'Tip: pull down to refresh.',
      accent: AppColors.primary,
    ),
    _TourStep(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Add every\nwallet you have.',
      body:
          'BDO, GCash, Maya, cash on hand, crypto — anything goes. Open Wallets, tap +, give it a name and emoji. You can paste your account number and even attach a QR code so others can pay you.',
      tip: 'Try it: Wallets → "+ Wallet" → "GCash".',
      accent: Color(0xFF4F8DF7),
    ),
    _TourStep(
      icon: Icons.swap_horiz_rounded,
      title: 'Income, expenses,\ntransfers.',
      body:
          'Inside any wallet, log income or expenses. Need to move money between wallets? Use Transfer — both wallets update at once and stay linked.',
      tip: 'Tip: transfers don\'t change your net worth.',
      accent: Color(0xFF52C28F),
    ),
    _TourStep(
      icon: Icons.local_drink_rounded,
      title: 'Goals fill\nlike a jar.',
      body:
          'Create a goal with a target — Motor, Japan trip, Emergency Fund. Add deposits and watch the savings jar fill in real time. The % readout tells you exactly where you are.',
      tip: 'Tip: goals without a target work too — they just track totals.',
      accent: AppColors.primary,
    ),
    _TourStep(
      icon: Icons.handshake_rounded,
      title: 'Debts —\nlinked to wallets.',
      body:
          'Track who owes you and what you owe. When you record a payment, pick a wallet — PesoFlow automatically logs the matching expense or income there. No double-entry.',
      tip: 'New: payment → "Pay from wallet" / "Receive to wallet".',
      accent: Color(0xFFFFB26B),
    ),
    _TourStep(
      icon: Icons.search_rounded,
      title: 'Search\nfinds everything.',
      body:
          'Tap the magnifying glass on the home screen to search across wallets, goals, debts, and transactions. Type "GCash" or a person\'s name — results jump straight to where you need to go.',
      tip: 'Tip: search is keyboard-first — start typing right away.',
      accent: Color(0xFF7C5CFF),
    ),
    _TourStep(
      icon: Icons.shield_moon_rounded,
      title: 'Secret Vault\nfor private wallets.',
      body:
          'The vault hides chosen wallets behind a separate PIN. Their balances don\'t show up on the dashboard or in net worth. Set it up in Settings → Secret vault.',
      tip: 'Tip: a different PIN = your "decoy unlock" still works without it.',
      accent: Color(0xFF2A2F3A),
    ),
    _TourStep(
      icon: Icons.cloud_off_rounded,
      title: 'Private &\nportable.',
      body:
          'Everything lives on this device only — no accounts, no cloud. Settings → Backup lets you export an encrypted JSON you can re-import on a new phone.',
      tip: 'You\'re ready. Have fun. 🇵🇭',
      accent: AppColors.primary,
    ),
  ];

  bool get _isLast => _index == _steps.length - 1;

  void _next() {
    if (_isLast) {
      widget.onDone();
    } else {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Quick tour',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isLast ? null : widget.onDone,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isLast ? 0 : 1,
                      child: const Text('Skip'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _TourStepView(step: _steps[i]),
              ),
            ),
            _Dots(count: _steps.length, index: _index),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _isLast ? 'Got it' : 'Next',
                      key: ValueKey(_isLast),
                      style:
                          const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TourStep {
  const _TourStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.tip,
    required this.accent,
  });
  final IconData icon;
  final String title;
  final String body;
  final String tip;
  final Color accent;
}

class _TourStepView extends StatelessWidget {
  const _TourStepView({required this.step});
  final _TourStep step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(child: _Hero(step: step)),
          ),
          Text(
            step.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step.body,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.65),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: step.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: 16, color: step.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.tip,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: step.accent,
                    ),
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

class _Hero extends StatelessWidget {
  const _Hero({required this.step});
  final _TourStep step;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: step.accent.withOpacity(0.08),
            ),
          ),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: step.accent.withOpacity(0.16),
            ),
          ),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [step.accent, step.accent.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: step.accent.withOpacity(0.30),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(step.icon, color: Colors.white, size: 46),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
