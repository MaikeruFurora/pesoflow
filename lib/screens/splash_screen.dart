import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  static const Duration minDuration = Duration(milliseconds: 2200);

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final AnimationController _blob = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
  );
  late final Animation<double> _ringFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.15, 0.7, curve: Curves.easeOut),
  );
  late final Animation<double> _titleFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
  );
  late final Animation<double> _subtitleFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
  );
  late final Animation<double> _footerFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _intro.forward();
    Future.delayed(SplashScreen.minDuration, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _blob.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Base gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1F8E82), Color(0xFF2BB3A4), Color(0xFF35C7B6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Animated background blobs
          AnimatedBuilder(
            animation: _blob,
            builder: (_, __) => CustomPaint(
              size: Size.infinite,
              painter: _BlobPainter(t: _blob.value),
            ),
          ),
          // Foreground content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 5),
                Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_intro, _shimmer]),
                    builder: (_, __) {
                      return SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer ring
                            Opacity(
                              opacity: 0.15 * _ringFade.value,
                              child: Container(
                                width: 220 * _ringFade.value,
                                height: 220 * _ringFade.value,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            // Inner ring
                            Opacity(
                              opacity: 0.22 * _ringFade.value,
                              child: Container(
                                width: 168 * _ringFade.value,
                                height: 168 * _ringFade.value,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            // Logo disc with shimmer sweep
                            Transform.scale(
                              scale: _logoScale.value,
                              child: Container(
                                width: 124,
                                height: 124,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withOpacity(0.20),
                                      blurRadius: 28,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      const _PesoMark(),
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: Transform.translate(
                                            offset: Offset(
                                              -100 +
                                                  (260 * _shimmer.value),
                                              0,
                                            ),
                                            child: Transform.rotate(
                                              angle: math.pi / 6,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      LinearGradient(
                                                    colors: [
                                                      Colors.white
                                                          .withOpacity(0),
                                                      Colors.white
                                                          .withOpacity(
                                                              0.45),
                                                      Colors.white
                                                          .withOpacity(0),
                                                    ],
                                                    stops: const [
                                                      0.35,
                                                      0.5,
                                                      0.65
                                                    ],
                                                    begin: Alignment
                                                        .centerLeft,
                                                    end: Alignment
                                                        .centerRight,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Lock badge
                            Positioned(
                              bottom: 36,
                              right: 36,
                              child: Transform.scale(
                                scale: _logoScale.value,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryDark,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withOpacity(0.25),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
                AnimatedBuilder(
                  animation: _intro,
                  builder: (_, __) => Column(
                    children: [
                      Opacity(
                        opacity: _titleFade.value,
                        child: Transform.translate(
                          offset:
                              Offset(0, (1 - _titleFade.value) * 12),
                          child: const Text(
                            'PesoFlow',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: _subtitleFade.value,
                        child: Transform.translate(
                          offset:
                              Offset(0, (1 - _subtitleFade.value) * 8),
                          child: const Text(
                            'Save smart. Stay secure.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 6),
                AnimatedBuilder(
                  animation: _intro,
                  builder: (_, __) => Opacity(
                    opacity: _footerFade.value,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined,
                                color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'On-device · End-to-end private',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _PesoMark extends StatelessWidget {
  const _PesoMark();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [AppColors.primaryDark, AppColors.primary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect),
      child: const Text(
        '₱',
        style: TextStyle(
          color: Colors.white,
          fontSize: 76,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final tau = 2 * math.pi;

    final highlight = Paint()..color = Colors.white.withOpacity(0.10);
    final dim = Paint()..color = Colors.black.withOpacity(0.10);

    // Floating soft circles
    canvas.drawCircle(
      Offset(w * 0.18 + 14 * math.sin(tau * t),
          h * 0.18 + 14 * math.cos(tau * t)),
      130,
      highlight,
    );
    canvas.drawCircle(
      Offset(w * 0.82 + 18 * math.cos(tau * t * 1.2),
          h * 0.27 + 12 * math.sin(tau * t * 1.5)),
      90,
      highlight,
    );
    canvas.drawCircle(
      Offset(w * 0.20 + 16 * math.sin(tau * (t + 0.5)),
          h * 0.78 + 16 * math.cos(tau * (t + 0.3))),
      150,
      dim,
    );
    canvas.drawCircle(
      Offset(w * 0.85 + 12 * math.cos(tau * (t + 0.7)),
          h * 0.82 + 12 * math.sin(tau * (t + 0.2))),
      72,
      highlight,
    );

    // Tiny floating dots like coins
    final dot = Paint()..color = Colors.white.withOpacity(0.55);
    final positions = [
      Offset(w * 0.12, h * 0.45),
      Offset(w * 0.92, h * 0.5),
      Offset(w * 0.78, h * 0.66),
      Offset(w * 0.22, h * 0.62),
      Offset(w * 0.5, h * 0.12),
      Offset(w * 0.65, h * 0.9),
    ];
    for (var i = 0; i < positions.length; i++) {
      final p = positions[i];
      final dy = 6 * math.sin(tau * (t + i * 0.13));
      canvas.drawCircle(p.translate(0, dy), 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) =>
      oldDelegate.t != t;
}
