import 'package:flutter/material.dart';

/// Tiny attention badge — a solid dot with a soft halo that scales and fades
/// outward on a loop. Use to signal "something new here" without grabbing
/// focus the way a banner would.
class PulseDot extends StatefulWidget {
  const PulseDot({
    super.key,
    this.color = const Color(0xFFEF6F6C),
    this.size = 9,
  });

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final solid = widget.size;
    final halo = widget.size * 2.6;
    return SizedBox(
      width: halo,
      height: halo,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: Container(
                  width: solid + (halo - solid) * t,
                  height: solid + (halo - solid) * t,
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.45),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Container(
                width: solid,
                height: solid,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
