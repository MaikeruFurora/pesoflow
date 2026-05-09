import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pin_keypad.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _pinLength = 6;
  String _pin = '';
  String _confirmPin = '';
  bool _confirming = false;
  bool _mismatch = false;

  void _onKey(String k) {
    setState(() {
      _mismatch = false;
      if (!_confirming) {
        if (_pin.length < _pinLength) _pin += k;
        if (_pin.length == _pinLength) _confirming = true;
      } else {
        if (_confirmPin.length < _pinLength) _confirmPin += k;
        if (_confirmPin.length == _pinLength) _check();
      }
    });
  }

  void _onBackspace() {
    setState(() {
      _mismatch = false;
      if (_confirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _confirming = false;
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Future<void> _check() async {
    if (_pin == _confirmPin) {
      final auth = context.read<AuthService>();
      await auth.setPin(_pin);
      if (await auth.biometricAvailable()) {
        auth.storage.biometricEnabled = true;
      }
      auth.storage.onboardingComplete = true;
      if (!mounted) return;
      widget.onDone();
    } else {
      setState(() {
        _mismatch = true;
        _confirmPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activePin = _confirming ? _confirmPin : _pin;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.savings_outlined,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'PesoFlow',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Save smart. Stay secure.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const Spacer(),
            Text(
              _confirming ? 'Confirm your PIN' : 'Set up a 6-digit PIN',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _confirming
                  ? 'Re-enter to confirm'
                  : 'You\'ll use this to unlock the app',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
            const SizedBox(height: 28),
            PinDots(
              length: activePin.length,
              maxLength: _pinLength,
              error: _mismatch,
            ),
            if (_mismatch) ...[
              const SizedBox(height: 14),
              const Text(
                'PINs do not match. Try again.',
                style: TextStyle(color: AppColors.danger),
              ),
            ],
            const Spacer(),
            PinKeypad(
              onKey: _onKey,
              onBackspace: _onBackspace,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
