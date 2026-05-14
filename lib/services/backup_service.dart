import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'storage_service.dart';

/// JSON snapshot of all user data. PIN/biometric settings are not exported.
class BackupService {
  BackupService(this.storage);
  final StorageService storage;

  Map<String, dynamic> _snapshot() {
    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'goals': storage.goals.values.toList(),
      'transactions': storage.transactions.values.toList(),
      'debts': storage.debts.values.toList(),
      'wallets': storage.wallets.values.toList(),
      'walletTxns': storage.walletTxns.values.toList(),
    };
  }

  Future<File> exportToFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File('${dir.path}/pesoflow-backup-$ts.json');
    final pretty = const JsonEncoder.withIndent('  ').convert(_snapshot());
    await file.writeAsString(pretty);
    return file;
  }

  /// Replaces all user data with the snapshot's contents.
  Future<void> importFromJson(String contents) async {
    final data = jsonDecode(contents) as Map<String, dynamic>;
    await storage.goals.clear();
    await storage.transactions.clear();
    await storage.debts.clear();
    await storage.wallets.clear();
    await storage.walletTxns.clear();

    Future<void> restore(String key, dynamic box) async {
      final entries = (data[key] as List?) ?? const [];
      for (final raw in entries) {
        if (raw is! String) continue;
        final id = (jsonDecode(raw) as Map<String, dynamic>)['id'] as String;
        await box.put(id, raw);
      }
    }

    await restore('goals', storage.goals);
    await restore('transactions', storage.transactions);
    await restore('debts', storage.debts);
    await restore('wallets', storage.wallets);
    await restore('walletTxns', storage.walletTxns);
  }
}
