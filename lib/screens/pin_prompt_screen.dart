import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/pin_keypad.dart';

/// Modal PIN entry screen used to gate sensitive actions like changing the
/// main PIN or removing the vault PIN. Pops with `true` on success and `false`
/// if the user backs out.
class PinPromptScreen extends StatefulWidget {
  const PinPromptScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.verify,
    this.errorText = 'Wrong PIN.',
    this.iconData = Icons.lock_outline_rounded,
    this.iconGradient,
  });

  final String title;
  final String subtitle;
  final String errorText;
  final Future<bool> Function(String pin) verify;
  final IconData iconData;
  final List<Color>? iconGradient;

  @override
  State<PinPromptScreen> createState() => _PinPromptScreenState();
}

class _PinPromptScreenState extends State<PinPromptScreen> {
  static const int _pinLength = 6;
  String _pin = '';
  bool _error = false;
  bool _busy = false;

  void _onKey(String k) {
    if (_busy) return;
    setState(() {
      if (_pin.length < _pinLength) _pin += k;
      _error = false;
      if (_pin.length == _pinLength) _check();
    });
  }

  void _onBackspace() {
    if (_busy) return;
    setState(() {
      if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      _error = false;
    });
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    final ok = await widget.verify(_pin);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = true;
        _pin = '';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = widget.iconGradient ??
        const [AppColors.primary, AppColors.primaryDark];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withOpacity(0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child:
                  Icon(widget.iconData, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 22),
            Text(
              widget.title,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(height: 26),
            PinDots(
              length: _pin.length,
              maxLength: _pinLength,
              error: _error,
            ),
            if (_error) ...[
              const SizedBox(height: 12),
              Text(widget.errorText,
                  style: const TextStyle(color: AppColors.danger)),
            ],
            const Spacer(),
            PinKeypad(onKey: _onKey, onBackspace: _onBackspace),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
