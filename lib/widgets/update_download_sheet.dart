import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/update_download_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// Modal bottom sheet that downloads the APK in-app with progress, then
/// fires the system installer. No browser, no Downloads folder pollution.
Future<void> showUpdateDownloadSheet(
  BuildContext context, {
  required UpdateInfo info,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false, // prevent accidental dismiss mid-download
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _UpdateDownloadSheet(info: info),
  );
}

class _UpdateDownloadSheet extends StatefulWidget {
  const _UpdateDownloadSheet({required this.info});
  final UpdateInfo info;

  @override
  State<_UpdateDownloadSheet> createState() => _UpdateDownloadSheetState();
}

class _UpdateDownloadSheetState extends State<_UpdateDownloadSheet> {
  final _service = UpdateDownloadService();
  UpdateDownloadState _state =
      const UpdateDownloadState(phase: UpdateDownloadPhase.idle);
  StreamSubscription<UpdateDownloadState>? _sub;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  @override
  void dispose() {
    _sub?.cancel();
    // Belt-and-braces: if the user dismissed the sheet via the system back
    // button mid-download, also tell dio to stop pulling bytes.
    if (_state.phase == UpdateDownloadPhase.downloading ||
        _state.phase == UpdateDownloadPhase.preparing) {
      _service.cancel();
    }
    super.dispose();
  }

  void _startDownload() {
    _sub?.cancel();
    setState(() {
      _state = const UpdateDownloadState(phase: UpdateDownloadPhase.preparing);
      _permissionDenied = false;
    });
    _sub = _service.download(url: widget.info.url).listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
    });
  }

  Future<void> _install() async {
    final apk = _state.apkPath;
    if (apk == null) return;
    setState(() {
      _state = _state.copyWith(phase: UpdateDownloadPhase.installing);
      _permissionDenied = false;
    });
    final ok = await _service.installApk(apk);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _state = _state.copyWith(phase: UpdateDownloadPhase.readyToInstall);
        _permissionDenied = true;
      });
      return;
    }
    // Installer is now in front of the user; close the sheet so they aren't
    // stuck behind the modal when Android shows its confirm dialog.
    Navigator.of(context).pop();
  }

  void _cancel() {
    _service.cancel();
    Navigator.of(context).pop();
  }

  String _formatBytes(int b) {
    if (b >= 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '$b B';
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final phase = _state.phase;
    final received = _state.bytesReceived;
    final total = _state.bytesTotal;
    final progress = _state.progress;

    String title;
    String subtitle;
    switch (phase) {
      case UpdateDownloadPhase.idle:
      case UpdateDownloadPhase.preparing:
        title = 'Preparing update…';
        subtitle = 'Cleaning up old downloads.';
        break;
      case UpdateDownloadPhase.downloading:
        title = 'Downloading v${info.latestVersion}…';
        subtitle = total > 0
            ? '${_formatBytes(received)} / ${_formatBytes(total)}'
            : 'Starting download…';
        break;
      case UpdateDownloadPhase.verifying:
        title = 'Verifying update…';
        subtitle = 'Checking the file is intact.';
        break;
      case UpdateDownloadPhase.readyToInstall:
        title = 'Ready to install';
        subtitle = _permissionDenied
            ? 'Allow "Install unknown apps" for PesoFlow, then tap Install again.'
            : 'Tap Install — Android will ask you to confirm.';
        break;
      case UpdateDownloadPhase.installing:
        title = 'Opening installer…';
        subtitle = 'Follow the prompts in the system dialog.';
        break;
      case UpdateDownloadPhase.failed:
        title = 'Update failed';
        subtitle = _state.error ?? 'Something went wrong.';
        break;
      case UpdateDownloadPhase.cancelled:
        title = 'Download cancelled';
        subtitle = 'Tap retry to download again.';
        break;
    }

    final canRetry = phase == UpdateDownloadPhase.failed ||
        phase == UpdateDownloadPhase.cancelled;
    final canInstall = phase == UpdateDownloadPhase.readyToInstall;
    final showProgress = phase == UpdateDownloadPhase.downloading ||
        phase == UpdateDownloadPhase.preparing ||
        phase == UpdateDownloadPhase.verifying ||
        phase == UpdateDownloadPhase.installing;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.system_update_alt_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'v${info.latestVersion}',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: showProgress && total > 0 ? progress : null,
                minHeight: 8,
                backgroundColor: AppColors.primarySoft.withOpacity(0.6),
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            if (phase == UpdateDownloadPhase.downloading && total > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            if (info.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  info.notes!,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                if (_permissionDenied)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await openAppSettings();
                      },
                      icon: const Icon(Icons.settings_rounded, size: 18),
                      label: const Text('Open settings'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withOpacity(0.4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        phase == UpdateDownloadPhase.downloading ||
                                phase == UpdateDownloadPhase.preparing
                            ? 'Cancel'
                            : 'Close',
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: canRetry
                        ? _startDownload
                        : (canInstall ? _install : null),
                    icon: Icon(
                      canRetry
                          ? Icons.refresh_rounded
                          : Icons.install_mobile_rounded,
                      size: 18,
                    ),
                    label: Text(canRetry ? 'Retry' : 'Install'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(0, 48),
                      disabledBackgroundColor:
                          AppColors.primary.withOpacity(0.35),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
