import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A single quick action surfaced by [MagneticFab] when it's expanded.
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

/// A floating action button that:
/// - tracks the user's finger with damped follow when dragged,
/// - stretches along the drag axis to feel like soft jelly,
/// - springs back to rest with an elastic curve,
/// - taps open a blurred overlay with quick-action pills,
/// - fires haptic feedback at every interaction.
///
/// Designed to be dropped into Scaffold.floatingActionButton (or anywhere
/// else — it manages its own expansion overlay so it doesn't depend on
/// surrounding layout).
class MagneticFab extends StatefulWidget {
  const MagneticFab({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  State<MagneticFab> createState() => _MagneticFabState();
}

class _MagneticFabState extends State<MagneticFab>
    with TickerProviderStateMixin {
  // Follow-finger damping. < 1 means the FAB lags behind the finger, giving
  // a magnetic "tethered" feel. Tune for taste.
  static const double _followDamping = 0.45;

  // Maximum stretch amount expressed as scale delta (1 + stretch).
  static const double _maxStretch = 0.22;

  // Distance at which the stretch reaches _maxStretch.
  static const double _stretchPxLimit = 110;

  // While true, no taps fire until pointer fully resets — prevents accidental
  // open after a vigorous drag.
  bool _suppressTap = false;

  Offset _drag = Offset.zero;
  bool _pressed = false;
  bool _expanded = false;

  late final AnimationController _springCtrl;
  late final Animation<Offset> _springAnim;
  Offset _springFrom = Offset.zero;

  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _springCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..addListener(() {
        setState(() => _drag = _springAnim.value);
      });
    _springAnim = const AlwaysStoppedAnimation(Offset.zero);
  }

  @override
  void dispose() {
    _overlay?.remove();
    _springCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Drag --

  void _onPanDown(DragDownDetails _) {
    HapticFeedback.lightImpact();
    _springCtrl.stop();
    setState(() => _pressed = true);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final next = _drag + d.delta * _followDamping;
    setState(() => _drag = next);
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() => _pressed = false);
    if (_drag.distance > 8) {
      _suppressTap = true;
      HapticFeedback.mediumImpact();
    }
    _runSpringBack();
  }

  void _onPanCancel() {
    setState(() => _pressed = false);
    _runSpringBack();
  }

  void _runSpringBack() {
    _springFrom = _drag;
    _springCtrl.reset();
    final tween = Tween<Offset>(begin: _springFrom, end: Offset.zero);
    final curved = CurvedAnimation(
      parent: _springCtrl,
      curve: Curves.elasticOut,
    );
    final newAnim = tween.animate(curved);
    setState(() {});
    _bindAnim(newAnim);
    _springCtrl.forward().whenComplete(() {
      if (mounted) {
        setState(() => _suppressTap = false);
      }
    });
  }

  void _bindAnim(Animation<Offset> anim) {
    // Reassign the listener target by swapping the public field. We rebuild
    // _springAnim by replacing it; existing listener calls _springAnim.value
    // so we need to keep that reference current.
    _springAnim = anim;
  }

  // ---------------------------------------------------------------- Tap --

  void _onTap() {
    if (_suppressTap) return;
    HapticFeedback.selectionClick();
    if (_expanded) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    setState(() => _expanded = true);
    _overlay = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context, rootOverlay: true).insert(_overlay!);
  }

  void _close() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() => _expanded = false);
  }

  // ---------------------------------------------------------------- UI --

  @override
  Widget build(BuildContext context) {
    final dragDist = _drag.distance;
    final stretch = (dragDist / _stretchPxLimit).clamp(0.0, 1.0) * _maxStretch;
    final angle =
        dragDist > 0.01 ? math.atan2(_drag.dy, _drag.dx) : 0.0;
    final pressedScale = _pressed ? 0.94 : 1.0;
    final expandedRot = _expanded ? math.pi * 0.125 : 0.0;

    // Build the directional stretch matrix: rotate so x-axis aligns with drag,
    // scale x to stretch along drag direction, rotate back.
    final stretchMatrix = Matrix4.identity()
      ..rotateZ(angle)
      ..scale(1 + stretch, 1 - stretch * 0.35)
      ..rotateZ(-angle);

    return Transform.translate(
      offset: _drag,
      child: GestureDetector(
        onPanDown: _onPanDown,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: _onPanCancel,
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: pressedScale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Transform(
            alignment: Alignment.center,
            transform: stretchMatrix,
            child: AnimatedRotation(
              turns: expandedRot / (2 * math.pi),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: _Fab(expanded: _expanded),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------- Expanded overlay --

  Widget _buildOverlay(BuildContext overlayContext) {
    return _ExpandedMenu(
      actions: widget.actions,
      onDismiss: _close,
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.45),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
    );
  }
}

// ============================================================ Overlay UI ==

class _ExpandedMenu extends StatefulWidget {
  const _ExpandedMenu({
    required this.actions,
    required this.onDismiss,
  });

  final List<QuickAction> actions;
  final VoidCallback onDismiss;

  @override
  State<_ExpandedMenu> createState() => _ExpandedMenuState();
}

class _ExpandedMenuState extends State<_ExpandedMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  Future<void> _fire(QuickAction a) async {
    HapticFeedback.mediumImpact();
    await _ctrl.reverse();
    widget.onDismiss();
    a.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Stack(
          children: [
            // Tap-to-dismiss blurred backdrop
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismiss,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 14 * t,
                    sigmaY: 14 * t,
                  ),
                  child: Container(
                    color: Colors.black.withOpacity(0.25 * t),
                  ),
                ),
              ),
            ),
            // Stack of action pills above the FAB
            Positioned(
              right: 16,
              bottom: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = widget.actions.length - 1; i >= 0; i--)
                    _Pill(
                      action: widget.actions[i],
                      progress:
                          _stagger(t, i, widget.actions.length),
                      onTap: () => _fire(widget.actions[i]),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Stagger so pills closer to the FAB appear first.
  double _stagger(double t, int reverseIndex, int total) {
    // index from FAB (0 = closest to FAB)
    final fromFab = total - 1 - reverseIndex;
    final start = (fromFab / total) * 0.35;
    final end = start + 0.65;
    return ((t - start) / (end - start)).clamp(0.0, 1.0);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.action,
    required this.progress,
    required this.onTap,
  });

  final QuickAction action;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, (1 - progress) * 20),
          child: Transform.scale(
            scale: 0.85 + 0.15 * progress,
            alignment: Alignment.bottomRight,
            child: Material(
              elevation: 8,
              shadowColor: action.color.withOpacity(0.4),
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: action.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(action.icon,
                            color: action.color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        action.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: action.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
