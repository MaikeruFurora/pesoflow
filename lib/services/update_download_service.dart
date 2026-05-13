import 'dart:io';

import 'package:dio/dio.dart';
import 'package:install_plugin/install_plugin.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Step-by-step status of an in-app update download + install flow.
enum UpdateDownloadPhase {
  idle,
  preparing,
  downloading,
  verifying,
  readyToInstall,
  installing,
  failed,
  cancelled,
}

class UpdateDownloadState {
  const UpdateDownloadState({
    required this.phase,
    this.bytesReceived = 0,
    this.bytesTotal = 0,
    this.error,
    this.apkPath,
  });

  final UpdateDownloadPhase phase;
  final int bytesReceived;
  final int bytesTotal;
  final String? error;
  final String? apkPath;

  double get progress =>
      bytesTotal <= 0 ? 0 : (bytesReceived / bytesTotal).clamp(0.0, 1.0);

  UpdateDownloadState copyWith({
    UpdateDownloadPhase? phase,
    int? bytesReceived,
    int? bytesTotal,
    String? error,
    String? apkPath,
  }) {
    return UpdateDownloadState(
      phase: phase ?? this.phase,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      bytesTotal: bytesTotal ?? this.bytesTotal,
      error: error ?? this.error,
      apkPath: apkPath ?? this.apkPath,
    );
  }
}

/// Downloads the APK directly into the app's cache dir (overwriting any
/// previous download so users don't accumulate `pesoflow(2).apk` clutter)
/// and fires the system package installer when ready. No browser hop.
class UpdateDownloadService {
  UpdateDownloadService();

  static const _apkFileName = 'pesoflow-update.apk';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(minutes: 5),
    followRedirects: true,
  ));
  CancelToken? _cancel;

  Future<File> _targetFile() async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/$_apkFileName');
  }

  /// Wipes any leftover *.apk in the cache dir. Called before every fresh
  /// download so a previously-interrupted attempt doesn't leave bytes behind.
  Future<void> _sweepCache() async {
    try {
      final dir = await getTemporaryDirectory();
      final entries = dir.listSync();
      for (final e in entries) {
        if (e is File && e.path.toLowerCase().endsWith('.apk')) {
          try {
            await e.delete();
          } catch (_) {/* best-effort */}
        }
      }
    } catch (_) {/* swallow — cache dir not readable is non-fatal */}
  }

  /// Streams the download. Emits state transitions for the UI to render
  /// progress + phase. Resolves when the user-initiated phase ends
  /// (readyToInstall / failed / cancelled).
  Stream<UpdateDownloadState> download({required String url}) async* {
    if (_cancel != null) {
      yield const UpdateDownloadState(
        phase: UpdateDownloadPhase.failed,
        error: 'A download is already in progress.',
      );
      return;
    }
    yield const UpdateDownloadState(phase: UpdateDownloadPhase.preparing);
    await _sweepCache();

    final target = await _targetFile();
    final token = CancelToken();
    _cancel = token;

    var state = UpdateDownloadState(
      phase: UpdateDownloadPhase.downloading,
      bytesReceived: 0,
      bytesTotal: 0,
      apkPath: target.path,
    );
    yield state;

    final controller = _ProgressBus();
    final future = _dio.download(
      url,
      target.path,
      cancelToken: token,
      onReceiveProgress: (received, total) {
        controller.push(received, total);
      },
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
      ),
    );

    // Multiplex progress events into state changes; surface a final state
    // when the download future completes.
    await for (final ev in controller.streamUntil(future)) {
      state = state.copyWith(
        phase: UpdateDownloadPhase.downloading,
        bytesReceived: ev.received,
        bytesTotal: ev.total,
      );
      yield state;
    }

    try {
      await future;
    } on DioException catch (e) {
      _cancel = null;
      if (CancelToken.isCancel(e)) {
        await _deleteIfExists(target);
        yield const UpdateDownloadState(
          phase: UpdateDownloadPhase.cancelled,
        );
        return;
      }
      await _deleteIfExists(target);
      yield UpdateDownloadState(
        phase: UpdateDownloadPhase.failed,
        error: _humanError(e),
      );
      return;
    } catch (e) {
      _cancel = null;
      await _deleteIfExists(target);
      yield UpdateDownloadState(
        phase: UpdateDownloadPhase.failed,
        error: 'Download failed: $e',
      );
      return;
    }

    _cancel = null;

    // Sanity-check the file actually landed and isn't empty. A 0-byte APK
    // would fail the install with a generic error — better to surface here.
    final size = await target.length();
    if (size < 1024) {
      await _deleteIfExists(target);
      yield const UpdateDownloadState(
        phase: UpdateDownloadPhase.failed,
        error: 'Downloaded file is too small — the server returned an empty response.',
      );
      return;
    }

    yield UpdateDownloadState(
      phase: UpdateDownloadPhase.readyToInstall,
      bytesReceived: size,
      bytesTotal: size,
      apkPath: target.path,
    );
  }

  void cancel() {
    _cancel?.cancel('user-cancelled');
    _cancel = null;
  }

  /// Asks the user for "Install unknown apps" if not granted, then fires the
  /// system package installer. Returns true if the installer was launched.
  Future<bool> installApk(String apkPath) async {
    // On Android 8+ the app needs this toggle once per source. If not yet
    // granted, the package installer would just refuse silently.
    final status = await Permission.requestInstallPackages.status;
    if (!status.isGranted) {
      final newStatus =
          await Permission.requestInstallPackages.request();
      if (!newStatus.isGranted) {
        return false;
      }
    }
    try {
      final pkg = await PackageInfo.fromPlatform();
      await InstallPlugin.installApk(apkPath, appId: pkg.packageName);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _deleteIfExists(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {/* best-effort */}
  }

  String _humanError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Network timed out. Check your connection and try again.';
      case DioExceptionType.badResponse:
        return 'Server returned ${e.response?.statusCode}. The update may have been moved.';
      case DioExceptionType.connectionError:
        return 'Can\'t reach the update server. Check your internet and try again.';
      case DioExceptionType.cancel:
        return 'Download cancelled.';
      default:
        return 'Download failed (${e.message ?? 'unknown'}).';
    }
  }
}

// ---- Internal: progress bus -----------------------------------------------
class _ProgressEvent {
  _ProgressEvent(this.received, this.total);
  final int received;
  final int total;
}

class _ProgressBus {
  final _events = <_ProgressEvent>[];
  bool _done = false;

  void push(int received, int total) {
    _events.add(_ProgressEvent(received, total));
  }

  Stream<_ProgressEvent> streamUntil(Future done) async* {
    done.whenComplete(() => _done = true);
    while (!_done) {
      while (_events.isNotEmpty) {
        yield _events.removeAt(0);
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    // Flush any final events queued after _done flipped.
    while (_events.isNotEmpty) {
      yield _events.removeAt(0);
    }
  }
}
