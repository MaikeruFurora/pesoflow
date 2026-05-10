import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Per-wallet QR images live at:
///   <appDocs>/wallet_qr/<walletId>.<ext>
class WalletAssetService {
  static const _dirName = 'wallet_qr';

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_dirName');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Returns the absolute path to a wallet's stored QR file, or null if
  /// none has been saved or the file no longer exists on disk.
  Future<String?> qrPath(String walletId, String fileName) async {
    if (fileName.isEmpty) return null;
    final dir = await _dir();
    final f = File('${dir.path}/$fileName');
    if (!f.existsSync()) return null;
    return f.path;
  }

  /// Copies [source] into the wallet's slot, replacing any existing QR.
  /// Returns the saved filename (e.g. "abc123.jpg").
  Future<String> saveQr({
    required String walletId,
    required File source,
  }) async {
    final dir = await _dir();
    final ext = _extOf(source.path);
    final fileName =
        '$walletId-${DateTime.now().millisecondsSinceEpoch}$ext';
    await _deleteAllForWallet(dir, walletId);
    final dest = File('${dir.path}/$fileName');
    await source.copy(dest.path);
    return fileName;
  }

  /// Writes raw bytes (typically a re-encoded JPG after cropping) to the
  /// wallet's slot. Returns the saved filename.
  Future<String> saveQrBytes({
    required String walletId,
    required List<int> bytes,
    String ext = '.jpg',
  }) async {
    final dir = await _dir();
    final fileName =
        '$walletId-${DateTime.now().millisecondsSinceEpoch}$ext';
    await _deleteAllForWallet(dir, walletId);
    final dest = File('${dir.path}/$fileName');
    await dest.writeAsBytes(bytes, flush: true);
    return fileName;
  }

  Future<void> deleteForWallet(String walletId) async {
    final dir = await _dir();
    await _deleteAllForWallet(dir, walletId);
  }

  Future<void> _deleteAllForWallet(Directory dir, String walletId) async {
    if (!dir.existsSync()) return;
    final entries = dir.listSync();
    for (final e in entries) {
      if (e is File) {
        final base = e.uri.pathSegments.last;
        if (base.startsWith('$walletId-') || base.startsWith('$walletId.')) {
          try {
            await e.delete();
          } catch (_) {}
        }
      }
    }
  }

  String _extOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '.jpg';
    return path.substring(dot).toLowerCase();
  }
}
