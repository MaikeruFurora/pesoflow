import 'package:hive_flutter/hive_flutter.dart';

import '../models/debt.dart';
import '../models/goal.dart';
import '../models/txn_entry.dart';
import '../models/wallet.dart';
import '../models/wallet_txn.dart';

class StorageService {
  static const _goalsBox = 'goals';
  static const _txnBox = 'transactions';
  static const _debtsBox = 'debts';
  static const _walletsBox = 'wallets';
  static const _walletTxnBox = 'wallet_txns';
  static const _settingsBox = 'settings';

  late Box<String> goals;
  late Box<String> transactions;
  late Box<String> debts;
  late Box<String> wallets;
  late Box<String> walletTxns;
  late Box settings;

  Future<void> init() async {
    await Hive.initFlutter();
    goals = await Hive.openBox<String>(_goalsBox);
    transactions = await Hive.openBox<String>(_txnBox);
    debts = await Hive.openBox<String>(_debtsBox);
    wallets = await Hive.openBox<String>(_walletsBox);
    walletTxns = await Hive.openBox<String>(_walletTxnBox);
    settings = await Hive.openBox(_settingsBox);
  }

  // Goals -----------------------------------------------------------------
  List<Goal> loadGoals() => goals.values
      .map((s) => Goal.fromRawJson(s))
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  Future<void> saveGoal(Goal g) => goals.put(g.id, g.toRawJson());
  Future<void> deleteGoal(String id) => goals.delete(id);

  // Transactions ----------------------------------------------------------
  List<TxnEntry> loadTransactions() =>
      transactions.values.map((s) => TxnEntry.fromRawJson(s)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  Future<void> saveTransaction(TxnEntry t) =>
      transactions.put(t.id, t.toRawJson());

  Future<void> deleteTransaction(String id) => transactions.delete(id);

  Future<void> deleteTransactionsForGoal(String goalId) async {
    final keysToDelete = transactions.toMap().entries.where((e) {
      final t = TxnEntry.fromRawJson(e.value);
      return t.goalId == goalId;
    }).map((e) => e.key).toList();
    await transactions.deleteAll(keysToDelete);
  }

  // Debts -----------------------------------------------------------------
  List<Debt> loadDebts() =>
      debts.values.map((s) => Debt.fromRawJson(s)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> saveDebt(Debt d) => debts.put(d.id, d.toRawJson());
  Future<void> deleteDebt(String id) => debts.delete(id);

  // Wallets ---------------------------------------------------------------
  List<Wallet> loadWallets() =>
      wallets.values.map((s) => Wallet.fromRawJson(s)).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  Future<void> saveWallet(Wallet w) => wallets.put(w.id, w.toRawJson());
  Future<void> deleteWallet(String id) => wallets.delete(id);

  List<WalletTxn> loadWalletTxns() => walletTxns.values
      .map((s) => WalletTxn.fromRawJson(s))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  Future<void> saveWalletTxn(WalletTxn t) =>
      walletTxns.put(t.id, t.toRawJson());

  Future<void> deleteWalletTxn(String id) => walletTxns.delete(id);

  Future<void> deleteWalletTxnsForWallet(String walletId) async {
    final keysToDelete = walletTxns.toMap().entries.where((e) {
      final t = WalletTxn.fromRawJson(e.value);
      return t.walletId == walletId;
    }).map((e) => e.key).toList();
    await walletTxns.deleteAll(keysToDelete);
  }

  // Settings --------------------------------------------------------------
  String? get pinHash => settings.get('pinHash') as String?;
  set pinHash(String? v) => settings.put('pinHash', v);

  bool get biometricEnabled =>
      (settings.get('biometricEnabled') as bool?) ?? false;
  set biometricEnabled(bool v) => settings.put('biometricEnabled', v);

  int get autoLockMinutes =>
      (settings.get('autoLockMinutes') as int?) ?? 1;
  set autoLockMinutes(int v) => settings.put('autoLockMinutes', v);

  bool get onboardingComplete =>
      (settings.get('onboardingComplete') as bool?) ?? false;
  set onboardingComplete(bool v) => settings.put('onboardingComplete', v);

  bool get hideBalances =>
      (settings.get('hideBalances') as bool?) ?? false;
  set hideBalances(bool v) => settings.put('hideBalances', v);

  String? get vaultPinHash => settings.get('vaultPinHash') as String?;
  set vaultPinHash(String? v) => settings.put('vaultPinHash', v);
}
