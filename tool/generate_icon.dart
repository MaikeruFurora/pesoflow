// PesoFlow app icon generator.
// Run with: dart run tool/generate_icon.dart
//
// Produces:
//   assets/icon/app_icon.png            — 1024x1024 launcher icon
//   assets/icon/app_icon_foreground.png — transparent foreground for adaptive

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const int kSize = 1024;

// Brand palette
const int navyDeep = 0xFF0E1F49;
const int navyMid = 0xFF1B3578;
const int navyLight = 0xFF2752C0;
const int blueBright = 0xFF3B82F6;
const int cyan = 0xFF22D3EE;
const int cyanLight = 0xFFA5F3FC;
const int white = 0xFFFFFFFF;

void main() {
  final dir = Directory('assets/icon');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  File('${dir.path}/app_icon.png')
      .writeAsBytesSync(img.encodePng(_drawIcon(withBackground: true)));
  File('${dir.path}/app_icon_foreground.png')
      .writeAsBytesSync(img.encodePng(_drawIcon(withBackground: false)));

  stdout.writeln('Wrote ${dir.path}/app_icon.png');
  stdout.writeln('Wrote ${dir.path}/app_icon_foreground.png');
}

img.Image _drawIcon({required bool withBackground}) {
  final image = img.Image(width: kSize, height: kSize, numChannels: 4);
  _fillTransparent(image);

  if (withBackground) {
    // Navy squircle background with diagonal gradient
    _fillSquircle(
      image,
      cornerRadius: kSize ~/ 5,
      gradient: (x, y) {
        final tt = ((x + y) / (2 * kSize)).clamp(0.0, 1.0);
        return _lerpColor3(navyDeep, navyMid, navyLight, tt);
      },
    );

    // Decorative atmosphere
    _softCircle(image,
        cx: kSize * 0.20,
        cy: kSize * 0.18,
        r: kSize * 0.22,
        color: 0xFF60A5FA,
        alpha: 60);
    _softCircle(image,
        cx: kSize * 0.85,
        cy: kSize * 0.85,
        r: kSize * 0.24,
        color: 0xFF000000,
        alpha: 50);
  }

  // Three upward flow arrows in the upper-right area, layered back-to-front
  // so the trailing arrows feel slower / further away.
  _drawFlowArrow(image,
      from: const _Pt(0.30, 0.78),
      to: const _Pt(0.86, 0.18),
      thickness: kSize * 0.078,
      colorStart: blueBright,
      colorEnd: cyanLight,
      headSize: kSize * 0.16,
      alpha: 200);

  _drawFlowArrow(image,
      from: const _Pt(0.18, 0.86),
      to: const _Pt(0.74, 0.30),
      thickness: kSize * 0.060,
      colorStart: cyan,
      colorEnd: cyanLight,
      headSize: kSize * 0.13,
      alpha: 150);

  _drawFlowArrow(image,
      from: const _Pt(0.10, 0.96),
      to: const _Pt(0.62, 0.42),
      thickness: kSize * 0.044,
      colorStart: cyanLight,
      colorEnd: white,
      headSize: kSize * 0.10,
      alpha: 100);

  // Bold ₱ glyph in white → cyan vertical gradient, centered slightly left.
  _drawPesoGlyph(
    image,
    cx: (kSize * 0.42).round(),
    cy: (kSize * 0.50).round(),
    height: (kSize * 0.62).round(),
    gradient: (y, top, bottom) {
      final t = ((y - top) / (bottom - top)).clamp(0.0, 1.0);
      return _lerpColor(white, cyanLight, t);
    },
  );

  return image;
}

// ---------------------------------------------------------------------------
// Composition primitives
// ---------------------------------------------------------------------------

class _Pt {
  const _Pt(this.x, this.y);
  final double x; // 0..1
  final double y; // 0..1
}

void _drawFlowArrow(
  img.Image im, {
  required _Pt from,
  required _Pt to,
  required double thickness,
  required int colorStart,
  required int colorEnd,
  required double headSize,
  required int alpha,
}) {
  final fx = from.x * kSize;
  final fy = from.y * kSize;
  final tx = to.x * kSize;
  final ty = to.y * kSize;

  // Stroke: filled circles along the line with gradient + alpha falloff.
  final dx = tx - fx;
  final dy = ty - fy;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 1) return;
  final steps = len.ceil();
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    final x = fx + dx * t;
    final y = fy + dy * t;
    final c = _lerpColor(colorStart, colorEnd, t);
    // Slight thickness taper so the arrow feels brush-like
    final taper = 0.85 + 0.30 * t;
    _filledCircle(im,
        cx: x.round(),
        cy: y.round(),
        r: (thickness * taper / 2).round(),
        color: _withAlpha(c, alpha));
  }

  // Arrowhead: filled triangle pointing along (dx, dy) at (tx, ty).
  final ang = math.atan2(dy, dx);
  final ah = headSize;
  final p1 = _Off(tx + ah * math.cos(ang), ty + ah * math.sin(ang));
  final p2 = _Off(
    tx + ah * math.cos(ang + 2.5),
    ty + ah * math.sin(ang + 2.5),
  );
  final p3 = _Off(
    tx + ah * math.cos(ang - 2.5),
    ty + ah * math.sin(ang - 2.5),
  );
  _filledTriangle(im, p1, p2, p3, _withAlpha(colorEnd, alpha));
}

class _Off {
  _Off(this.x, this.y);
  final double x;
  final double y;
}

// ---------------------------------------------------------------------------
// Peso glyph — bold "₱" with two horizontal bars across the stem.
// gradient: function (y, top, bottom) → color
// ---------------------------------------------------------------------------

void _drawPesoGlyph(
  img.Image im, {
  required int cx,
  required int cy,
  required int height,
  required int Function(int y, int top, int bottom) gradient,
}) {
  final stemThickness = (height * 0.18).round();
  final stemHeight = height;
  final stemTop = cy - stemHeight ~/ 2;
  final stemBottom = stemTop + stemHeight;
  final stemX = cx - (height * 0.10).round();

  // Vertical stem
  _filledRectGrad(im,
      x: stemX - stemThickness ~/ 2,
      y: stemTop,
      w: stemThickness,
      h: stemHeight,
      gradient: (y) => gradient(y, stemTop, stemBottom));

  // Bowl (top half) — D-shape: horizontal top bar + horizontal mid bar +
  // outward semi-circle on the right.
  final bowlH = (height * 0.50).round();
  final bowlTop = stemTop;
  _filledRectGrad(im,
      x: stemX - stemThickness ~/ 2,
      y: bowlTop,
      w: (height * 0.46).round(),
      h: stemThickness,
      gradient: (y) => gradient(y, stemTop, stemBottom));
  _filledRectGrad(im,
      x: stemX - stemThickness ~/ 2,
      y: bowlTop + bowlH - stemThickness,
      w: (height * 0.46).round(),
      h: stemThickness,
      gradient: (y) => gradient(y, stemTop, stemBottom));
  // Right semicircle
  final bowlCx = stemX + (height * 0.46).round() - stemThickness ~/ 2;
  final bowlCy = bowlTop + bowlH ~/ 2;
  final bowlR = bowlH ~/ 2;
  _ringSegmentGrad(im,
      cx: bowlCx,
      cy: bowlCy,
      rOuter: bowlR,
      rInner: bowlR - stemThickness,
      startAngle: -math.pi / 2,
      endAngle: math.pi / 2,
      gradient: (y) => gradient(y, stemTop, stemBottom));

  // Two horizontal "peso" bars across the stem
  final barW = (height * 0.62).round();
  final barX = stemX - (barW ~/ 2);
  final barH = (stemThickness * 0.65).round();
  final bar1Y = stemTop + (stemHeight * 0.46).round();
  final bar2Y = stemTop + (stemHeight * 0.66).round();
  _filledRectGrad(im,
      x: barX,
      y: bar1Y,
      w: barW,
      h: barH,
      gradient: (y) => gradient(y, stemTop, stemBottom));
  _filledRectGrad(im,
      x: barX,
      y: bar2Y,
      w: barW,
      h: barH,
      gradient: (y) => gradient(y, stemTop, stemBottom));
}

// ---------------------------------------------------------------------------
// Pixel primitives
// ---------------------------------------------------------------------------

void _fillTransparent(img.Image im) {
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      im.setPixelRgba(x, y, 0, 0, 0, 0);
    }
  }
}

void _fillSquircle(
  img.Image im, {
  required int cornerRadius,
  required int Function(int x, int y) gradient,
}) {
  final w = im.width;
  final h = im.height;
  final r = cornerRadius;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (_inRoundedRect(x, y, w, h, r)) {
        _setColor(im, x, y, gradient(x, y));
      }
    }
  }
}

bool _inRoundedRect(int x, int y, int w, int h, int r) {
  if (x >= r && x <= w - r) return true;
  if (y >= r && y <= h - r) return true;
  final cornerCx = (x < r) ? r : (w - r);
  final cornerCy = (y < r) ? r : (h - r);
  if ((x < r || x > w - r) && (y < r || y > h - r)) {
    final dx = x - cornerCx;
    final dy = y - cornerCy;
    return dx * dx + dy * dy <= r * r;
  }
  return true;
}

void _filledCircle(img.Image im,
    {required int cx, required int cy, required int r, required int color}) {
  if (r <= 0) return;
  final r2 = r * r;
  for (var y = cy - r; y <= cy + r; y++) {
    if (y < 0 || y >= im.height) continue;
    for (var x = cx - r; x <= cx + r; x++) {
      if (x < 0 || x >= im.width) continue;
      final dx = x - cx;
      final dy = y - cy;
      if (dx * dx + dy * dy <= r2) {
        _blendColor(im, x, y, color);
      }
    }
  }
}

void _softCircle(img.Image im,
    {required double cx,
    required double cy,
    required double r,
    required int color,
    required int alpha}) {
  final r2 = r * r;
  for (var y = (cy - r).floor(); y <= (cy + r).ceil(); y++) {
    if (y < 0 || y >= im.height) continue;
    for (var x = (cx - r).floor(); x <= (cx + r).ceil(); x++) {
      if (x < 0 || x >= im.width) continue;
      final dx = x - cx;
      final dy = y - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 <= r2) {
        final t = (1.0 - math.sqrt(d2) / r).clamp(0.0, 1.0);
        final a = (alpha * t).round();
        _blendColor(im, x, y, _withAlpha(color, a));
      }
    }
  }
}

void _filledRectGrad(img.Image im,
    {required int x,
    required int y,
    required int w,
    required int h,
    required int Function(int y) gradient}) {
  for (var yy = y; yy < y + h; yy++) {
    if (yy < 0 || yy >= im.height) continue;
    final color = gradient(yy);
    for (var xx = x; xx < x + w; xx++) {
      if (xx < 0 || xx >= im.width) continue;
      _blendColor(im, xx, yy, color);
    }
  }
}

void _ringSegmentGrad(img.Image im,
    {required int cx,
    required int cy,
    required int rOuter,
    required int rInner,
    required double startAngle,
    required double endAngle,
    required int Function(int y) gradient}) {
  final r2o = rOuter * rOuter;
  final r2i = rInner * rInner;
  for (var y = cy - rOuter; y <= cy + rOuter; y++) {
    if (y < 0 || y >= im.height) continue;
    final color = gradient(y);
    for (var x = cx - rOuter; x <= cx + rOuter; x++) {
      if (x < 0 || x >= im.width) continue;
      final dx = x - cx;
      final dy = y - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 > r2o || d2 < r2i) continue;
      var ang = math.atan2(dy.toDouble(), dx.toDouble());
      if (ang < startAngle) ang += 2 * math.pi;
      if (ang >= startAngle && ang <= endAngle) {
        _blendColor(im, x, y, color);
      }
    }
  }
}

void _filledTriangle(img.Image im, _Off a, _Off b, _Off c, int color) {
  final minX = [a.x, b.x, c.x].reduce(math.min).floor();
  final maxX = [a.x, b.x, c.x].reduce(math.max).ceil();
  final minY = [a.y, b.y, c.y].reduce(math.min).floor();
  final maxY = [a.y, b.y, c.y].reduce(math.max).ceil();
  double sign(_Off p, _Off p1, _Off p2) =>
      (p.x - p2.x) * (p1.y - p2.y) - (p1.x - p2.x) * (p.y - p2.y);
  for (var y = minY; y <= maxY; y++) {
    if (y < 0 || y >= im.height) continue;
    for (var x = minX; x <= maxX; x++) {
      if (x < 0 || x >= im.width) continue;
      final p = _Off(x.toDouble(), y.toDouble());
      final d1 = sign(p, a, b);
      final d2 = sign(p, b, c);
      final d3 = sign(p, c, a);
      final hasNeg = d1 < 0 || d2 < 0 || d3 < 0;
      final hasPos = d1 > 0 || d2 > 0 || d3 > 0;
      if (!(hasNeg && hasPos)) {
        _blendColor(im, x, y, color);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Color helpers
// ---------------------------------------------------------------------------

int _withAlpha(int argb, int alpha) =>
    (alpha & 0xFF) << 24 | (argb & 0x00FFFFFF);

int _lerpColor3(int a, int b, int c, double t) =>
    t < 0.5 ? _lerpColor(a, b, t * 2) : _lerpColor(b, c, (t - 0.5) * 2);

int _lerpColor(int a, int b, double t) {
  final aa = (a >> 24) & 0xFF;
  final ar = (a >> 16) & 0xFF;
  final ag = (a >> 8) & 0xFF;
  final ab = a & 0xFF;
  final ba = (b >> 24) & 0xFF;
  final br = (b >> 16) & 0xFF;
  final bg = (b >> 8) & 0xFF;
  final bb = b & 0xFF;
  final ax = aa + ((ba - aa) * t).round();
  final r = ar + ((br - ar) * t).round();
  final g = ag + ((bg - ag) * t).round();
  final bl = ab + ((bb - ab) * t).round();
  return (ax << 24) | (r << 16) | (g << 8) | bl;
}

void _setColor(img.Image im, int x, int y, int argb) {
  final a = (argb >> 24) & 0xFF;
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  im.setPixelRgba(x, y, r, g, b, a);
}

void _blendColor(img.Image im, int x, int y, int argb) {
  final a = (argb >> 24) & 0xFF;
  if (a == 0) return;
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;

  final p = im.getPixel(x, y);
  final dstA = p.a.toInt();
  final dstR = p.r.toInt();
  final dstG = p.g.toInt();
  final dstB = p.b.toInt();

  final srcAf = a / 255.0;
  final dstAf = dstA / 255.0;
  final outAf = srcAf + dstAf * (1 - srcAf);
  if (outAf <= 0) {
    im.setPixelRgba(x, y, 0, 0, 0, 0);
    return;
  }
  final outR =
      ((r * srcAf + dstR * dstAf * (1 - srcAf)) / outAf).round().clamp(0, 255);
  final outG =
      ((g * srcAf + dstG * dstAf * (1 - srcAf)) / outAf).round().clamp(0, 255);
  final outB =
      ((b * srcAf + dstB * dstAf * (1 - srcAf)) / outAf).round().clamp(0, 255);
  final outA = (outAf * 255).round().clamp(0, 255);
  im.setPixelRgba(x, y, outR, outG, outB, outA);
}
