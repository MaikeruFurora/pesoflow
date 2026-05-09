import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pin_keypad.dart';
import 'vault_screen.dart';

class VaultUnlockScreen extends StatefulWidget {
  const VaultUnlockScreen({super.key});

  @override
  State<VaultUnlockScreen> createState() => _VaultUnlockScreenState();
}

class _VaultUnlockScreenState extends State<VaultUnlockScreen> {
  static const int _pinLength = 6;
  String _pin = '';
  bool _error = false;

  bool _settingUp = false;
  String _setupPin = '';
  String _setupConfirm = '';
  bool _confirming = false;
  bool _mismatch = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _settingUp = !auth.hasVaultPin;
  }

  void _onKey(String k) {
    setState(() {
      if (_settingUp) {
        if (!_confirming) {
          if (_setupPin.length < _pinLength) _setupPin += k;
          if (_setupPin.length == _pinLength) _confirming = true;
        } else {
          if (_setupConfirm.length < _pinLength) _setupConfirm += k;
          if (_setupConfirm.length == _pinLength) _completeSetup();
        }
      } else {
        if (_pin.length < _pinLength) _pin += k;
        _error = false;
        if (_pin.length == _pinLength) _verify();
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_settingUp) {
        if (_confirming) {
          if (_setupConfirm.isNotEmpty) {
            _setupConfirm =
                _setupConfirm.substring(0, _setupConfirm.length - 1);
          } else {
            _confirming = false;
            if (_setupPin.isNotEmpty) {
              _setupPin = _setupPin.substring(0, _setupPin.length - 1);
            }
          }
        } else {
          if (_setupPin.isNotEmpty) {
            _setupPin = _setupPin.substring(0, _setupPin.length - 1);
          }
        }
        _mismatch = false;
      } else {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
        _error = false;
      }
    });
  }

  Future<void> _verify() async {
    final auth = context.read<AuthService>();
    final ok = await auth.verifyVaultPin(_pin);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => const VaultScreen(),
      ));
    } else {
      setState(() {
        _error = true;
        _pin = '';
      });
    }
  }

  Future<void> _completeSetup() async {
    if (_setupPin == _setupConfirm) {
      final auth = context.read<AuthService>();
      await auth.setVaultPin(_setupPin);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => const VaultScreen(),
      ));
    } else {
      setState(() {
        _mismatch = true;
        _setupConfirm = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String title;
    String subtitle;
    int pinLen;
    if (_settingUp) {
      title = _confirming ? 'Confirm vault PIN' : 'Set vault PIN';
      subtitle = _confirming
          ? 'Enter the same 6 digits to confirm'
          : 'Pick a 6-digit PIN that\'s different from your unlock PIN';
      pinLen = _confirming ? _setupConfirm.length : _setupPin.length;
    } else {
      title = 'Enter vault PIN';
      subtitle = 'A different 6-digit PIN unlocks your secret vault';
      pinLen = _pin.length;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secret vault'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F2A44), Color(0xFF2C3E72)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1F2A44).withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.shield_outlined,
                  color: Colors.white, size: 38),
            ),
            const SizedBox(height: 22),
            Text(title,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(height: 26),
            PinDots(
              length: pinLen,
              maxLength: _pinLength,
              error: _error || _mismatch,
            ),
            if (_error) ...[
              const SizedBox(height: 12),
              const Text('Wrong vault PIN.',
                  style: TextStyle(color: AppColors.danger)),
            ] else if (_mismatch) ...[
              const SizedBox(height: 12),
              const Text('PINs do not match. Try again.',
                  style: TextStyle(color: AppColors.danger)),
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
