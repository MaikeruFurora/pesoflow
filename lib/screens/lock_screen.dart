import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pin_keypad.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  static const int _pinLength = 6;
  String _pin = '';
  bool _error = false;
  String? _bioError;
  bool _biometricAvailable = false;
  bool _checkingBio = true;

  @override
  void initState() {
    super.initState();
    _setupBiometric();
  }

  Future<void> _setupBiometric() async {
    final auth = context.read<AuthService>();
    final available =
        auth.storage.biometricEnabled && await auth.biometricAvailable();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _checkingBio = false;
    });
    if (available) _tryBiometric(silentOnFail: true);
  }

  Future<void> _tryBiometric({bool silentOnFail = false}) async {
    final auth = context.read<AuthService>();
    final result = await auth.authenticateBiometric();
    if (!mounted) return;
    if (result.ok) {
      widget.onUnlocked();
    } else if (!silentOnFail) {
      setState(() => _bioError = result.error);
    }
  }

  void _onKey(String k) {
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin += k;
      _error = false;
      _bioError = null;
    });
    if (_pin.length == _pinLength) _verify();
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = false;
    });
  }

  Future<void> _verify() async {
    final auth = context.read<AuthService>();
    final ok = await auth.verifyPin(_pin);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() {
        _error = true;
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_checkingBio) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: AppColors.primary,
                size: 38,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome back',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter your PIN',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 32),
            PinDots(
              length: _pin.length,
              maxLength: _pinLength,
              error: _error,
            ),
            if (_error) ...[
              const SizedBox(height: 14),
              const Text(
                'Wrong PIN. Try again.',
                style: TextStyle(color: AppColors.danger),
              ),
            ] else if (_bioError != null) ...[
              const SizedBox(height: 14),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _bioError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const Spacer(),
            PinKeypad(
              onKey: _onKey,
              onBackspace: _onBackspace,
              onBiometric: _biometricAvailable
                  ? () => _tryBiometric(silentOnFail: false)
                  : null,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
