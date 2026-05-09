import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Animated savings jar visualization. The fill height tracks [progress]
/// (0..1), with a wavy surface that gently animates and a few coin
/// silhouettes floating inside.
class SavingsJar extends StatefulWidget {
  const SavingsJar({
    super.key,
    required this.progress,
    this.fillColor = AppColors.primary,
    this.height = 220,
  });

  final double progress;
  final Color fillColor;
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
      aspectRatio: 0.9,
      child: AnimatedBuilder(
        animation: Listenable.merge([_wave, _fill]),
        builder: (_, __) {
          return CustomPaint(
            painter: _JarPainter(
              fill: _currentFill,
              wavePhase: _wave.value * math.pi * 2,
              color: widget.fillColor,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      '${(_currentFill * 100).round()}%',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: widget.fillColor,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _JarPainter extends CustomPainter {
  _JarPainter({
    required this.fill,
    required this.wavePhase,
    required this.color,
  });

  final double fill;
  final double wavePhase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Jar geometry
    final neckTop = h * 0.04;
    final neckBottom = h * 0.13;
    final neckHalfWidth = w * 0.20;

    final bodyTop = neckBottom + 6;
    final bodyBottom = h - 4;
    final bodyHalfWidth = w * 0.36;
    final bodyRadius = 24.0;

    final cx = w / 2;

    // ---- Lid (rounded rect at top) ----
    final lidRect = Rect.fromCenter(
      center: Offset(cx, neckTop + 6),
      width: neckHalfWidth * 2 + 18,
      height: 16,
    );
    final lidPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.85), color.withOpacity(0.55)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(lidRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(lidRect, const Radius.circular(8)),
      lidPaint,
    );

    // ---- Jar outline (neck + body) ----
    final jarPath = Path()
      ..moveTo(cx - neckHalfWidth, neckTop + 14)
      ..lineTo(cx - neckHalfWidth, neckBottom)
      ..quadraticBezierTo(
          cx - neckHalfWidth, neckBottom + 8, cx - bodyHalfWidth + 8, bodyTop)
      ..lineTo(cx - bodyHalfWidth, bodyTop + 8)
      ..arcToPoint(
        Offset(cx - bodyHalfWidth + bodyRadius, bodyBottom),
        radius: Radius.circular(bodyRadius),
        clockwise: false,
      )
      ..lineTo(cx + bodyHalfWidth - bodyRadius, bodyBottom)
      ..arcToPoint(
        Offset(cx + bodyHalfWidth, bodyBottom - bodyRadius),
        radius: Radius.circular(bodyRadius),
        clockwise: false,
      )
      ..lineTo(cx + bodyHalfWidth, bodyTop + 8)
      ..lineTo(cx + bodyHalfWidth - 8, bodyTop)
      ..quadraticBezierTo(
          cx + neckHalfWidth, neckBottom + 8, cx + neckHalfWidth, neckBottom)
      ..lineTo(cx + neckHalfWidth, neckTop + 14)
      ..close();

    // ---- Glass background ----
    final glassPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0.06),
          color.withOpacity(0.10),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(jarPath, glassPaint);

    // ---- Liquid fill (clipped to jar shape) ----
    if (fill > 0) {
      canvas.save();
      canvas.clipPath(jarPath);

      final innerTop = bodyTop + 4;
      final innerBottom = bodyBottom - 2;
      final fillH = (innerBottom - innerTop) * fill;
      final fillTopY = innerBottom - fillH;

      const segments = 24;
      final liquidPath = Path()..moveTo(0, h);
      // Wave across the top of the fill
      for (var i = 0; i <= segments; i++) {
        final x = (w / segments) * i;
        final phase = wavePhase + (i / segments) * math.pi * 2;
        final dy = math.sin(phase) * 4;
        if (i == 0) {
          liquidPath.lineTo(x, fillTopY + dy);
        } else {
          liquidPath.lineTo(x, fillTopY + dy);
        }
      }
      liquidPath
        ..lineTo(w, h)
        ..close();

      final liquidPaint = Paint()
        ..shader = LinearGradient(
          colors: [color.withOpacity(0.85), color.withOpacity(0.55)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTRB(0, fillTopY, w, h));
      canvas.drawPath(liquidPath, liquidPaint);

      // Highlight band along the wave crest
      final highlight = Path()..moveTo(0, fillTopY);
      for (var i = 0; i <= segments; i++) {
        final x = (w / segments) * i;
        final phase = wavePhase + (i / segments) * math.pi * 2;
        final dy = math.sin(phase) * 4;
        highlight.lineTo(x, fillTopY + dy);
      }
      canvas.drawPath(
        highlight,
        Paint()
          ..color = Colors.white.withOpacity(0.32)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );

      // Bubbles & coins
      _drawBubbles(canvas, w, fillTopY, innerBottom);
      _drawCoins(canvas, w, fillTopY, innerBottom);

      canvas.restore();
    }

    // ---- Glass border + shine ----
    final borderPaint = Paint()
      ..color = color.withOpacity(0.55)
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(jarPath, borderPaint);

    // Diagonal shine
    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.30)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - bodyHalfWidth + 14, bodyTop + 18),
      Offset(cx - bodyHalfWidth + 30, bodyBottom - 36),
      shinePaint,
    );
  }

  void _drawBubbles(
      Canvas canvas, double w, double surfaceY, double bottomY) {
    final paint = Paint()..color = Colors.white.withOpacity(0.40);
    final positions = [
      Offset(w * 0.30, surfaceY + 18),
      Offset(w * 0.62, surfaceY + 32),
      Offset(w * 0.45, bottomY - 20),
    ];
    final radii = [3.5, 2.5, 4.0];
    for (var i = 0; i < positions.length; i++) {
      final dy = math.sin(wavePhase + i) * 2;
      canvas.drawCircle(
        positions[i].translate(0, dy),
        radii[i],
        paint,
      );
    }
  }

  void _drawCoins(
      Canvas canvas, double w, double surfaceY, double bottomY) {
    // Only draw coins if there's enough space
    if (bottomY - surfaceY < 30) return;
    final coinPaint = Paint()..color = const Color(0xFFFFD166);
    final coinShade = Paint()..color = const Color(0xFFFFA94D);

    final coins = [
      _Coin(Offset(w * 0.40, bottomY - 12), 10),
      _Coin(Offset(w * 0.60, bottomY - 14), 12),
      _Coin(Offset(w * 0.50, bottomY - 28), 9),
    ];

    for (final c in coins) {
      if (c.center.dy - c.radius < surfaceY + 4) continue;
      // Lower half — shadow
      canvas.drawCircle(
        c.center.translate(1, 1),
        c.radius,
        coinShade,
      );
      canvas.drawCircle(c.center, c.radius, coinPaint);
      // Inner ring
      canvas.drawCircle(
        c.center,
        c.radius - 2,
        Paint()
          ..color = const Color(0xFFFFE39C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _JarPainter old) =>
      old.fill != fill || old.wavePhase != wavePhase || old.color != color;
}

class _Coin {
  _Coin(this.center, this.radius);
  final Offset center;
  final double radius;
}
