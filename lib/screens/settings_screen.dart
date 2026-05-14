import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/pulse_dot.dart';
import '../widgets/soft_card.dart';
import '../widgets/update_download_sheet.dart';
import 'onboarding_screen.dart';
import 'pin_prompt_screen.dart';
import 'tour_screen.dart';
import 'vault_unlock_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _bio = false;
  int _autoLock = 1;
  bool _bioAvailable = false;
  String? _bioError;
  bool _busyBackup = false;

  String _appVersion = '';
  String _appBuild = '';

  @override
  void initState() {
    super.initState();
    final storage = context.read<StorageService>();
    _bio = storage.biometricEnabled;
    _autoLock = storage.autoLockMinutes;
    _checkBio();
    _loadAppVersion();
    _silentUpdateCheck();
  }

  /// Background check on Settings open — populates [_pendingUpdate] so the
  /// pulse dot shows without the user having to tap "Check for updates".
  /// Mirrors the banner's "respect dismissed builds" rule.
  Future<void> _silentUpdateCheck() async {
    final svc = UpdateService();
    final info = await svc.check();
    if (!mounted || info == null || !info.hasUpdate) return;
    final ack = context.read<StorageService>().acknowledgedUpdateBuild;
    if (info.latestBuild <= ack) return;
    setState(() => _pendingUpdate = info);
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = info.version;
      _appBuild = info.buildNumber;
    });
  }

  Future<void> _checkBio() async {
    final auth = context.read<AuthService>();
    final ok = await auth.biometricAvailable();
    String? err;
    if (!ok) {
      err = await auth.biometricUnavailableReason();
    }
    if (mounted) {
      setState(() {
        _bioAvailable = ok;
        _bioError = err;
      });
    }
  }

  bool _checkingUpdate = false;
  UpdateInfo? _pendingUpdate;

  Future<void> _checkForUpdate() async {
    setState(() => _checkingUpdate = true);
    final svc = UpdateService();
    final info = await svc.check();
    if (!mounted) return;
    setState(() {
      _checkingUpdate = false;
      // Refresh the pulse-dot state with whatever the live check returned.
      _pendingUpdate =
          (info != null && info.hasUpdate) ? info : null;
    });

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Couldn't reach the update server. Check your connection.")),
      );
      return;
    }
    if (!info.hasUpdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "You're on the latest version (v${info.currentVersion}).") ,
        ),
      );
      return;
    }

    // In-app download + install — same sheet the dashboard banner uses.
    await showUpdateDownloadSheet(context, info: info);
    if (!mounted) return;
    // After the sheet closes, the user is either on the new version (in which
    // case a re-check below will report no update) or they cancelled. Either
    // way, refresh the dot state.
    final after = await svc.check();
    if (!mounted) return;
    setState(() {
      _pendingUpdate = (after != null && after.hasUpdate) ? after : null;
    });
  }

  Future<void> _changePin() async {
    final auth = context.read<AuthService>();
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PinPromptScreen(
          title: 'Confirm current PIN',
          subtitle:
              'Enter your existing 6-digit PIN to set a new one.',
          iconData: Icons.password_rounded,
          verify: (pin) => auth.verifyPin(pin),
        ),
        fullscreenDialog: true,
      ),
    );
    if (verified != true || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnboardingScreen(
          onDone: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _confirmRemoveVault() async {
    final auth = context.read<AuthService>();
    final state = context.read<AppState>();

    // Step 1 — verify vault PIN before going anywhere near a destructive
    // dialog. This prevents someone with passing access to the unlocked app
    // from wiping the vault.
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PinPromptScreen(
          title: 'Confirm vault PIN',
          subtitle:
              'Enter your 6-digit vault PIN to remove the vault and unhide its wallets.',
          errorText: 'Wrong vault PIN.',
          iconData: Icons.shield_outlined,
          iconGradient: const [Color(0xFF1F2A44), Color(0xFF2C3E72)],
          verify: (pin) => auth.verifyVaultPin(pin),
        ),
        fullscreenDialog: true,
      ),
    );
    if (verified != true || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove vault PIN?'),
        content: const Text(
            'This clears the vault PIN and unhides all wallets currently in the vault. They will appear in your normal wallet list. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await auth.clearVaultPin();
    // Unhide all vault wallets
    for (final w in state.vaultWallets) {
      w.isVault = false;
      await state.updateWallet(w);
    }
    if (mounted) setState(() {});
  }

  Future<void> _exportBackup() async {
    setState(() => _busyBackup = true);
    try {
      final storage = context.read<StorageService>();
      final backup = BackupService(storage);
      final file = await backup.exportToFile();
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'PesoFlow backup',
        text:
            'Encrypted only by your device storage. Keep this file safe.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyBackup = false);
    }
  }

  Future<void> _importBackup() async {
    final storage = context.read<StorageService>();
    final state = context.read<AppState>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
            'This will REPLACE all your current goals, transactions, debts and wallets with the contents of the backup file. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace data',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    if (mounted) setState(() => _busyBackup = true);
    try {
      final contents = await File(path).readAsString();
      final backup = BackupService(storage);
      await backup.importFromJson(contents);
      await state.reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restored.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyBackup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.read<StorageService>();
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const _Header(text: 'Privacy'),
          SoftCard(
            child: Column(
              children: [
                _SwitchRow(
                  icon: Icons.visibility_off_outlined,
                  label: 'Hide balances',
                  subtitle:
                      'Replaces amounts with •••••• throughout the app',
                  value: state.hideBalances,
                  onChanged: (v) => state.setHideBalances(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _Header(text: 'Security'),
          SoftCard(
            child: Column(
              children: [
                _SwitchRow(
                  icon: Icons.fingerprint,
                  label: 'Biometric unlock',
                  subtitle: _bioAvailable
                      ? 'Use Face ID or fingerprint to unlock'
                      : (_bioError ?? 'Not available on this device'),
                  value: _bio && _bioAvailable,
                  onChanged: _bioAvailable
                      ? (v) {
                          setState(() => _bio = v);
                          storage.biometricEnabled = v;
                        }
                      : null,
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timer_outlined,
                      color: AppColors.primary),
                  title: const Text('Auto-lock'),
                  subtitle: Text(_autoLock == 0
                      ? 'Immediately'
                      : 'After $_autoLock minute${_autoLock == 1 ? '' : 's'}'),
                  trailing: DropdownButton<int>(
                    value: _autoLock,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Immediately')),
                      DropdownMenuItem(value: 1, child: Text('1 minute')),
                      DropdownMenuItem(value: 5, child: Text('5 minutes')),
                      DropdownMenuItem(value: 15, child: Text('15 minutes')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _autoLock = v);
                      storage.autoLockMinutes = v;
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.password_rounded,
                      color: AppColors.primary),
                  title: const Text('Change PIN'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changePin,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _Header(text: 'Secret vault'),
          SoftCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1F2A44),
                          Color(0xFF2C3E72)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: Colors.white, size: 18),
                  ),
                  title: Text(
                    context.read<AuthService>().hasVaultPin
                        ? 'Open vault'
                        : 'Set up secret vault',
                  ),
                  subtitle: Text(
                    context.read<AuthService>().hasVaultPin
                        ? 'Hidden wallets, separate PIN'
                        : 'Hide wallets behind a separate PIN',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const VaultUnlockScreen(),
                  )),
                ),
                if (context.read<AuthService>().hasVaultPin) ...[
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_reset_rounded,
                        color: AppColors.danger),
                    title: const Text('Remove vault PIN'),
                    subtitle: const Text(
                        'Hidden wallets will become visible again'),
                    onTap: _confirmRemoveVault,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _Header(text: 'Backup'),
          SoftCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.upload_file_outlined,
                      color: AppColors.primary),
                  title: const Text('Export backup'),
                  subtitle: const Text(
                      'Save a JSON snapshot you can share or store'),
                  trailing: _busyBackup
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _busyBackup ? null : _exportBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restore_outlined,
                      color: AppColors.primary),
                  title: const Text('Restore from backup'),
                  subtitle: const Text(
                      'Replaces your current data with a JSON file'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busyBackup ? null : _importBackup,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _Header(text: 'Help'),
          SoftCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tips_and_updates_rounded,
                  color: AppColors.primary),
              title: const Text('Take the tour'),
              subtitle: const Text(
                  'A quick walkthrough of every feature in PesoFlow'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TourScreen(
                      onDone: () => Navigator.of(context).pop(),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const _Header(text: 'Updates'),
          SoftCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 32,
                height: 32,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned.fill(
                      child: Icon(Icons.system_update_alt_rounded,
                          color: AppColors.primary),
                    ),
                    if (_pendingUpdate != null)
                      const Positioned(
                        right: -4,
                        top: -4,
                        child: PulseDot(),
                      ),
                  ],
                ),
              ),
              title: Row(
                children: [
                  const Text('Check for updates'),
                  if (_pendingUpdate != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'v${_pendingUpdate!.latestVersion}',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                _pendingUpdate != null
                    ? 'A newer version is ready — tap to install'
                    : 'Looks for a newer release on the website',
              ),
              trailing: _checkingUpdate
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _checkingUpdate ? null : _checkForUpdate,
            ),
          ),
          const SizedBox(height: 16),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  'PesoFlow keeps all your savings, wallets, and debt data on this device. Nothing is sent to a server.',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.65),
                  ),
                ),
                const SizedBox(height: 6),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryDark,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            'MF',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Developer',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.55),
                            ),
                          ),
                          const Text(
                            'MaikeruFurora',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _appVersion.isEmpty
                      ? 'Version …'
                      : 'Version $_appVersion (build $_appBuild)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      subtitle: Text(subtitle),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
