import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pageCtrl = PageController();
  int _index = 0;

  late final List<_IntroPage> _pages = const [
    _IntroPage(
      icon: Icons.account_balance_wallet_rounded,
      illustration: _Illustration.wallets,
      title: 'All your money,\nin one place.',
      subtitle:
          'Track BDO, GCash, Maya, cash, crypto — every wallet in your life — and see your real net worth update live.',
      accent: AppColors.primary,
    ),
    _IntroPage(
      icon: Icons.flag_rounded,
      illustration: _Illustration.goals,
      title: 'Save with\npurpose.',
      subtitle:
          'Create unlimited ipon goals — Motor, Emergency Fund, Japan Trip — with progress bars and ETA from your saving habits.',
      accent: Color(0xFF52C28F),
    ),
    _IntroPage(
      icon: Icons.handshake_rounded,
      illustration: _Illustration.debts,
      title: 'Never forget\nwho owes who.',
      subtitle:
          'Track money owed to you and money you owe — with partial payments, due dates, and color-coded status.',
      accent: Color(0xFFFFB26B),
    ),
    _IntroPage(
      icon: Icons.lock_rounded,
      illustration: _Illustration.privacy,
      title: 'Private by\ndefault.',
      subtitle:
          'Your data lives only on this device. Lock with a PIN or biometric. Hide balances anytime. No accounts. No cloud.',
      accent: AppColors.primary,
    ),
  ];

  bool get _isLast => _index == _pages.length - 1;

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _finish() {
    // Intentionally do NOT persist anything here. The intro is tied to the
    // onboarding-complete flag in the root gate, so closing the app before
    // setting a PIN will show the intro again next launch.
    widget.onDone();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            '₱',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'PesoFlow',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _isLast ? null : _finish,
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
                controller: _pageCtrl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _IntroPageView(page: _pages[i]),
              ),
            ),
            _Dots(count: _pages.length, index: _index),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _isLast ? 'Get started' : 'Next',
                      key: ValueKey(_isLast),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700),
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

enum _Illustration { wallets, goals, debts, privacy }

class _IntroPage {
  const _IntroPage({
    required this.icon,
    required this.illustration,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final _Illustration illustration;
  final String title;
  final String subtitle;
  final Color accent;
}

class _IntroPageView extends StatelessWidget {
  const _IntroPageView({required this.page});
  final _IntroPage page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Expanded(child: _IntroIllustration(page: page)),
          const SizedBox(height: 20),
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroIllustration extends StatelessWidget {
  const _IntroIllustration({required this.page});
  final _IntroPage page;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _BackdropBlobs(color: page.accent),
                _IllustrationContent(page: page),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BackdropBlobs extends StatelessWidget {
  const _BackdropBlobs({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 12,
          left: 18,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.10),
            ),
          ),
        ),
        Positioned(
          bottom: 24,
          right: 16,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.16),
            ),
          ),
        ),
        Positioned(
          top: 44,
          right: 36,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.55),
            ),
          ),
        ),
      ],
    );
  }
}

class _IllustrationContent extends StatelessWidget {
  const _IllustrationContent({required this.page});
  final _IntroPage page;

  @override
  Widget build(BuildContext context) {
    switch (page.illustration) {
      case _Illustration.wallets:
        return _WalletsArt(accent: page.accent);
      case _Illustration.goals:
        return _GoalsArt(accent: page.accent);
      case _Illustration.debts:
        return _DebtsArt(accent: page.accent);
      case _Illustration.privacy:
        return _PrivacyArt(accent: page.accent);
    }
  }
}

class _WalletsArt extends StatelessWidget {
  const _WalletsArt({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) {
    Widget card(
        {required String emoji,
        required String name,
        required String amount,
        required Color c,
        required Alignment align,
        required double rotation}) {
      return Align(
        alignment: align,
        child: Transform.rotate(
          angle: rotation,
          child: Container(
            width: 200,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c, c.withOpacity(0.78)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: c.withOpacity(0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(amount,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        card(
          emoji: '🏦',
          name: 'BDO',
          amount: '₱45,000',
          c: AppColors.primary,
          align: const Alignment(-0.25, -0.55),
          rotation: -0.06,
        ),
        card(
          emoji: '📱',
          name: 'GCash',
          amount: '₱8,250',
          c: const Color(0xFF4F8DF7),
          align: const Alignment(0.30, -0.05),
          rotation: 0.04,
        ),
        card(
          emoji: '💵',
          name: 'Cash',
          amount: '₱2,400',
          c: const Color(0xFF52C28F),
          align: const Alignment(-0.30, 0.45),
          rotation: -0.04,
        ),
      ],
    );
  }
}

class _GoalsArt extends StatelessWidget {
  const _GoalsArt({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) {
    Widget goal(String emoji, String name, double progress) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(emoji,
                    style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: accent.withOpacity(0.18),
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(progress * 100).round()}% saved',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          goal('🏍', 'Motor fund', 0.72),
          const SizedBox(height: 12),
          goal('✈️', 'Japan trip', 0.34),
          const SizedBox(height: 12),
          goal('🛟', 'Emergency', 0.95),
        ],
      ),
    );
  }
}

class _DebtsArt extends StatelessWidget {
  const _DebtsArt({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, Color c, String label, String amount,
        bool overdue) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: c, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: overdue
                            ? const Color(0xFFEF6F6C)
                            : const Color(0xFF52C28F),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      overdue ? 'Overdue' : 'On track',
                      style: TextStyle(
                        fontSize: 10,
                        color: overdue
                            ? const Color(0xFFEF6F6C)
                            : const Color(0xFF52C28F),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 10),
            Text(
              amount,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: const Alignment(-0.85, 0),
            child: chip(Icons.south_west, const Color(0xFF52C28F),
                'Marc', '₱3,000', false),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: const Alignment(0.85, 0),
            child: chip(Icons.north_east, const Color(0xFFEF6F6C),
                'Tita J', '₱5,000', true),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: const Alignment(-0.6, 0),
            child: chip(Icons.south_west, const Color(0xFF52C28F),
                'Karen', '₱1,200', false),
          ),
        ],
      ),
    );
  }
}

class _PrivacyArt extends StatelessWidget {
  const _PrivacyArt({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.10),
            ),
          ),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.18),
            ),
          ),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.35),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          Positioned(
            top: 18,
            right: 18,
            child: _privacyChip(Icons.fingerprint, 'Biometric'),
          ),
          Positioned(
            bottom: 18,
            left: 12,
            child: _privacyChip(Icons.visibility_off_outlined, 'Hide'),
          ),
          Positioned(
            bottom: 38,
            right: 8,
            child: _privacyChip(Icons.cloud_off_outlined, 'On device'),
          ),
        ],
      ),
    );
  }

  Widget _privacyChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700),
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
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
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
