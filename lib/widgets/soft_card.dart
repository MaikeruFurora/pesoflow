import 'package:flutter/material.dart';

class SoftCard extends StatefulWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.onTap,
    this.gradient,
    this.borderRadius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final double borderRadius;

  @override
  State<SoftCard> createState() => _SoftCardState();
}

class _SoftCardState extends State<SoftCard> {
  bool _pressed = false;

  bool get _interactive => widget.onTap != null;

  void _setPressed(bool v) {
    if (!_interactive) return;
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.color ??
        Theme.of(context).cardTheme.color ??
        Colors.white;

    final cardShape = BorderRadius.circular(widget.borderRadius);

    final card = AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOut,
      child: Material(
        color: widget.gradient == null ? bg : Colors.transparent,
        borderRadius: cardShape,
        child: Ink(
          decoration: BoxDecoration(
            gradient: widget.gradient,
            color: widget.gradient == null ? bg : null,
            borderRadius: cardShape,
            boxShadow: widget.gradient != null || isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: InkWell(
            borderRadius: cardShape,
            onTap: widget.onTap,
            splashColor: Colors.white.withOpacity(0.12),
            highlightColor: Colors.white.withOpacity(0.06),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );

    if (!_interactive) return card;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: card,
    );
  }
}
