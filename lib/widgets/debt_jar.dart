import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Debt payoff jar — visually drains as a debt is paid down.
///
/// [remaining] (0..1) is the share of the debt still unpaid: 1.0 = full debt
/// owed (jar is full), 0.0 = fully paid (jar is empty, signaling freedom).
/// The palette starts warm (coral/amber, "burden") and lightens as the level
/// drops — mirroring [SavingsJar]'s shape but with opposite semantics.
class DebtJar extends StatefulWidget {
  const DebtJar({
    super.key,
    required this.remaining,
    this.height = 240,
    this.paidOff = false,
    this.showPercent = true,
  });

  final double remaining;
  final double height;
  final bool paidOff;

  /// Show the "%" / "Cleared!" label centered in the jar. Disable for tiny
  /// inline thumbnails where text would just be clutter.
  final bool showPercent;

  @override
  State<DebtJar> createState() => _DebtJarState();
}

class _DebtJarState extends State<DebtJar> with TickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late double _from = 0;
  late double _to = widget.remaining.clamp(0.0, 1.0);

  @override
  void didUpdateWidget(DebtJar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remaining != widget.remaining) {
      _from = _currentFill;
      _to = widget.remaining.clamp(0.0, 1.0);
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
            painter: _DebtJarPainter(
              fill: _currentFill,
              wavePhase: _wave.value * math.pi * 2,
            ),
            child: widget.showPercent
                ? LayoutBuilder(builder: (_, c) {
                    const topPct = 0.27;
                    return Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: c.maxHeight * topPct,
                          child: Center(
                            child: Column(
                              children: [
                                Text(
                                  widget.paidOff
                                      ? 'Cleared!'
                                      : '${(_currentFill * 100).round()}%',
                                  style: TextStyle(
                                    fontSize: widget.paidOff ? 24 : 32,
                                    fontWeight: FontWeight.w800,
                                    color: widget.paidOff
                                        ? AppColors.success
                                        : const Color(0xFFB14A2F),
                                    height: 1.0,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                if (!widget.paidOff)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Text(
                                      'remaining',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF9A6650),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  })
                : const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

class _DebtJarPainter extends CustomPainter {
  _DebtJarPainter({required this.fill, required this.wavePhase});

  final double fill;
  final double wavePhase;

  // Warm palette — coral on top, amber at the bottom, signaling burden.
  static const _stroke = Color(0xFFE07A5F);
  static const _strokeDeep = Color(0xFFB14A2F);
  static const _liquidTop = Color(0xFFFFB26B); // peach/amber
  static const _liquidBottom = Color(0xFFEF6F6C); // coral
  static const _coin = Color(0xFFFFD166);
  static const _coinDeep = Color(0xFFFFA94D);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

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

    // Lid
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

    // Jar outline
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

    // Glass interior tint
    canvas.drawPath(
      jarPath,
      Paint()..color = const Color(0xFFFFE4DA).withOpacity(0.45),
    );

    // Liquid (clipped to jar)
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

      // Highlight crest
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

    // Glass stroke
    canvas.drawPath(
      jarPath,
      Paint()
        ..color = _stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // Interior shine
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
    final coinFace = Paint()..color = _coin;
    final coinShade = Paint()..color = _coinDeep;
    final innerStroke = Paint()
      ..color = const Color(0xFFFFE39C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final coins = [
      _CoinPos(Offset(w * 0.33, bottomY - 16), 12),
      _CoinPos(Offset(w * 0.62, bottomY - 18), 14),
      _CoinPos(Offset(w * 0.48, bottomY - 36), 11),
    ];

    for (final c in coins) {
      if (c.center.dy - c.radius < surfaceY + 6) continue;
      canvas.drawCircle(c.center.translate(1.5, 1.5), c.radius, coinShade);
      canvas.drawCircle(c.center, c.radius, coinFace);
      canvas.drawCircle(c.center, c.radius - 2, innerStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _DebtJarPainter old) =>
      old.fill != fill || old.wavePhase != wavePhase;
}

class _CoinPos {
  _CoinPos(this.center, this.radius);
  final Offset center;
  final double radius;
}
