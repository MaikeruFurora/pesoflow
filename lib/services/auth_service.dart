import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

import 'storage_service.dart';

class AuthService {
  AuthService(this.storage);

  final StorageService storage;
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool get hasPin => storage.pinHash != null && storage.pinHash!.isNotEmpty;

  String _hash(String pin) =>
      sha256.convert(utf8.encode('iponlock::$pin')).toString();

  Future<void> setPin(String pin) async {
    storage.pinHash = _hash(pin);
  }

  Future<bool> verifyPin(String pin) async {
    return storage.pinHash == _hash(pin);
  }

  // ----- Vault PIN ---------------------------------------------------------

  bool get hasVaultPin =>
      storage.vaultPinHash != null && storage.vaultPinHash!.isNotEmpty;

  Future<void> setVaultPin(String pin) async {
    storage.vaultPinHash = _hash('vault::$pin');
  }

  Future<void> clearVaultPin() async {
    storage.vaultPinHash = null;
  }

  Future<bool> verifyVaultPin(String pin) async {
    return storage.vaultPinHash == _hash('vault::$pin');
  }

  /// Returns true only if hardware is present, the OS supports biometrics,
  /// and at least one biometric (fingerprint/face) is enrolled.
  Future<bool> biometricAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) return false;
      final enrolled = await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Best-effort human-readable reason for why biometric is not usable.
  Future<String?> biometricUnavailableReason() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return 'Device does not support biometrics.';
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return 'Biometrics turned off in system settings.';
      final enrolled = await _localAuth.getAvailableBiometrics();
      if (enrolled.isEmpty) {
        return 'No fingerprint or face enrolled. Add one in your phone\'s settings.';
      }
      return null;
    } catch (e) {
      return 'Could not check biometrics ($e).';
    }
  }

  /// Returns (success, errorMessage). errorMessage is null on success.
  Future<({bool ok, String? error})> authenticateBiometric() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Unlock PesoFlow',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return (ok: ok, error: ok ? null : 'Authentication cancelled');
    } on PlatformException catch (e) {
      String msg;
      switch (e.code) {
        case auth_error.notAvailable:
          msg = 'Biometrics not available on this device.';
          break;
        case auth_error.notEnrolled:
          msg =
              'No biometric enrolled. Add a fingerprint or face in system settings.';
          break;
        case auth_error.lockedOut:
        case auth_error.permanentlyLockedOut:
          msg = 'Too many failed attempts. Use your PIN instead.';
          break;
        case auth_error.passcodeNotSet:
          msg = 'Set a device passcode first.';
          break;
        default:
          msg = e.message ?? 'Biometric error (${e.code}).';
      }
      return (ok: false, error: msg);
    } catch (e) {
      return (ok: false, error: 'Biometric error: $e');
    }
  }
}
