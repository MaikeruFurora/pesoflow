import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Animated savings jar visualization. Renders transparent — meant to sit
/// inside any background card the parent provides. Fill height tracks
/// [progress] (0..1) with a wavy surface that animates and gold coins
/// stacked at the bottom.
class SavingsJar extends StatefulWidget {
  const SavingsJar({
    super.key,
    required this.progress,
    this.height = 240,
  });

  final double progress;
  final double height;

  @override
  State<SavingsJar> createState() => _SavingsJarState();
}

class _SavingsJarState extends State<SavingsJar>
    with TickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late double _from = 0;
  late double _to = widget.progress.clamp(0.0, 1.0);

  @override
  void didUpdateWidget(SavingsJar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _from = _currentFill;
      _to = widget.progress.clamp(0.0, 1.0);
      _fill
        ..reset()
        ..forward();
    }
  }

  double get _currentFill {
    final t = Curves.easeOutCubic.transform(_fill.value);
    return _from + (_to - _from) * t;
  }

  @override
  void dispose() {
    _wave.dispose();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.78,
      child: AnimatedBuilder(
        animation: Listenable.merge([_wave, _fill]),
        builder: (_, __) {
          return CustomPaint(
            painter: _JarPainter(
              fill: _currentFill,
              wavePhase: _wave.value * math.pi * 2,
            ),
            child: LayoutBuilder(builder: (_, c) {
              const topPct = 0.27;
              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: c.maxHeight * topPct,
                    child: Center(
                      child: Text(
                        '${(_currentFill * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                          height: 1.0,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          );
        },
      ),
    );
  }
}

class _JarPainter extends CustomPainter {
  _JarPainter({required this.fill, required this.wavePhase});

  final double fill;
  final double wavePhase;

  // Brand palette tuned for light backgrounds
  static const _stroke = AppColors.primary;       // teal jar outline
  static const _strokeDeep = AppColors.primaryDark;
  static const _liquidTop = Color(0xFF22D3EE);    // bright cyan
  static const _liquidBottom = AppColors.primary; // teal
  static const _gold = Color(0xFFFFD166);
  static const _goldDeep = Color(0xFFFFA94D);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // ---- Geometry ----
    final lidH = h * 0.055;
    final lidW = w * 0.50;
    final lidTop = h * 0.04;

    final neckTop = lidTop + lidH;
    final neckBottom = h * 0.16;
    final neckHalfW = w * 0.18;

    final bodyTop = neckBottom + 6;
    final bodyBottom = h - h * 0.04;
    final bodyHalfW = w * 0.42;
    final bodyRadius = w * 0.10;

    // ---- Lid (rounded rect, teal gradient) ----
    final lidRect = Rect.fromCenter(
      center: Offset(cx, lidTop + lidH / 2),
      width: lidW,
      height: lidH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lidRect, const Radius.circular(8)),
      Paint()
        ..shader = const LinearGradient(
          colors: [_stroke, _strokeDeep],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(lidRect),
    );

    // ---- Jar outline path ----
    final jarPath = Path()
      ..moveTo(cx - neckHalfW, neckTop)
      ..lineTo(cx - neckHalfW, neckBottom - 4)
      ..quadraticBezierTo(
        cx - neckHalfW - 2, neckBottom + 4,
        cx - bodyHalfW + bodyRadius * 0.4, bodyTop,
      )
      ..arcToPoint(
        Offset(cx - bodyHalfW, bodyTop + bodyRadius),
        radius: Radius.circular(bodyRadius),
        clockwise: false,
      )
      ..lineTo(cx - bodyHalfW, bodyBottom - bodyRadius)
      ..arcToPoint(
        Offset(cx - bodyHalfW + bodyRadius, bodyBottom),
        radius: Radius.circular(bodyRadius),
        clockwise: false,
      )
      ..lineTo(cx + bodyHalfW - bodyRadius, bodyBottom)
      ..arcToPoint(
        Offset(cx + bodyHalfW, bodyBottom - bodyRadius),
        radius: Radius.circular(bodyRadius),
        clockwise: false,
      )
      ..lineTo(cx + bodyHalfW, bodyTop + bodyRadius)
      ..arcToPoint(
        Offset(cx + bodyHalfW - bodyRadius * 0.4, bodyTop),
        radius: Radius.circular(bodyRadius),
        clockwise: false,
      )
      ..quadraticBezierTo(
        cx + neckHalfW + 2, neckBottom + 4,
        cx + neckHalfW, neckBottom - 4,
      )
      ..lineTo(cx + neckHalfW, neckTop)
      ..close();

    // ---- Glass interior tint (very subtle) ----
    canvas.drawPath(
      jarPath,
      Paint()..color = AppColors.primarySoft.withOpacity(0.35),
    );

    // ---- Liquid (clipped to jar) ----
    if (fill > 0) {
      canvas.save();
      canvas.clipPath(jarPath);

      final innerTop = bodyTop + 4;
      final innerBottom = bodyBottom - 2;
      final fillH = (innerBottom - innerTop) * fill;
      final fillTopY = innerBottom - fillH;

      const segments = 28;
      final liquidPath = Path()..moveTo(0, h);
      for (var i = 0; i <= segments; i++) {
        final x = (w / segments) * i;
        final phase = wavePhase + (i / segments) * math.pi * 2;
        final dy = math.sin(phase) * 5;
        liquidPath.lineTo(x, fillTopY + dy);
      }
      liquidPath
        ..lineTo(w, h)
        ..close();

      canvas.drawPath(
        liquidPath,
        Paint()
          ..shader = LinearGradient(
            colors: [
              _liquidTop.withOpacity(0.92),
              _liquidBottom.withOpacity(0.92),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTRB(0, fillTopY, w, h)),
      );

      // Highlight crest — white sheen along the surface
      final crest = Path()..moveTo(0, fillTopY);
      for (var i = 0; i <= segments; i++) {
        final x = (w / segments) * i;
        final phase = wavePhase + (i / segments) * math.pi * 2;
        final dy = math.sin(phase) * 5;
        crest.lineTo(x, fillTopY + dy);
      }
      canvas.drawPath(
        crest,
        Paint()
          ..color = Colors.white.withOpacity(0.55)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );

      _drawBubbles(canvas, w, fillTopY, innerBottom);
      _drawCoins(canvas, w, fillTopY, innerBottom);

      canvas.restore();
    }

    // ---- Glass stroke (teal) ----
    canvas.drawPath(
      jarPath,
      Paint()
        ..color = _stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // ---- Vertical highlight on the left interior ----
    final shineX = cx - bodyHalfW + bodyRadius * 0.55;
    canvas.drawLine(
      Offset(shineX, bodyTop + h * 0.06),
      Offset(shineX, bodyBottom - h * 0.30),
      Paint()
        ..color = Colors.white.withOpacity(0.55)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawBubbles(
      Canvas canvas, double w, double surfaceY, double bottomY) {
    final paint = Paint()..color = Colors.white.withOpacity(0.55);
    final positions = [
      Offset(w * 0.34, surfaceY + 24),
      Offset(w * 0.62, surfaceY + 48),
      Offset(w * 0.50, bottomY - (bottomY - surfaceY) * 0.55),
    ];
    final radii = [3.0, 2.0, 2.5];
    for (var i = 0; i < positions.length; i++) {
      final dy = math.sin(wavePhase + i) * 2;
      canvas.drawCircle(positions[i].translate(0, dy), radii[i], paint);
    }
  }

  void _drawCoins(
      Canvas canvas, double w, double surfaceY, double bottomY) {
    if (bottomY - surfaceY < 30) return;
    final coinFace = Paint()..color = _gold;
    final coinShade = Paint()..color = _goldDeep;
    final innerStroke = Paint()
      ..color = const Color(0xFFFFE39C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final coins = [
      _Coin(Offset(w * 0.33, bottomY - 16), 12),
      _Coin(Offset(w * 0.62, bottomY - 18), 14),
      _Coin(Offset(w * 0.48, bottomY - 36), 11),
    ];

    for (final c in coins) {
      if (c.center.dy - c.radius < surfaceY + 6) continue;
      canvas.drawCircle(c.center.translate(1.5, 1.5), c.radius, coinShade);
      canvas.drawCircle(c.center, c.radius, coinFace);
      canvas.drawCircle(c.center, c.radius - 2, innerStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _JarPainter old) =>
      old.fill != fill || old.wavePhase != wavePhase;
}

class _Coin {
  _Coin(this.center, this.radius);
  final Offset center;
  final double radius;
}
