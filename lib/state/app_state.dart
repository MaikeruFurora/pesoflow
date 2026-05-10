import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/debt.dart';
import '../models/goal.dart';
import '../models/txn_entry.dart';
import '../models/wallet.dart';
import '../models/wallet_txn.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  AppState(this.storage) {
    _hideBalances = storage.hideBalances;
    _refresh();
  }

  final StorageService storage;
  final _uuid = const Uuid();

  List<Goal> _goals = [];
  List<TxnEntry> _txns = [];
  List<Debt> _debts = [];
  List<Wallet> _wallets = [];
  List<WalletTxn> _walletTxns = [];
  bool _hideBalances = false;

  List<Goal> get goals => List.unmodifiable(_goals);
  List<TxnEntry> get transactions => List.unmodifiable(_txns);
  List<Debt> get debts => List.unmodifiable(_debts);
  /// Public/non-vault wallets (default everywhere).
  List<Wallet> get wallets => List.unmodifiable(
      _wallets.where((w) => !w.archived && !w.isVault));

  /// Vault-only wallets — used inside the Secret Vault screen.
  List<Wallet> get vaultWallets => List.unmodifiable(
      _wallets.where((w) => !w.archived && w.isVault));

  Set<String> get _vaultWalletIds =>
      _wallets.where((w) => w.isVault).map((w) => w.id).toSet();

  /// Wallet transactions excluding ones from vault wallets — used for the
  /// dashboard / public activity stream.
  List<WalletTxn> get walletTxns {
    final vaultIds = _vaultWalletIds;
    return List.unmodifiable(
        _walletTxns.where((t) => !vaultIds.contains(t.walletId)));
  }

  /// All wallet transactions, including vault — for backup / vault screens.
  List<WalletTxn> get allWalletTxns => List.unmodifiable(_walletTxns);

  bool get hideBalances => _hideBalances;

  void _refresh() {
    _goals = storage.loadGoals();
    _txns = storage.loadTransactions();
    _debts = storage.loadDebts();
    _wallets = storage.loadWallets();
    _walletTxns = storage.loadWalletTxns();
  }

  Future<void> reload() async {
    _refresh();
    notifyListeners();
  }

  // ----- Hide balances ---------------------------------------------------
  Future<void> setHideBalances(bool v) async {
    _hideBalances = v;
    storage.hideBalances = v;
    notifyListeners();
  }

  Future<void> toggleHideBalances() => setHideBalances(!_hideBalances);

  // ----- Goals -----------------------------------------------------------
  List<TxnEntry> txnsForGoal(String goalId) =>
      _txns.where((t) => t.goalId == goalId).toList();

  double balanceFor(String goalId) => txnsForGoal(goalId)
      .fold<double>(0, (s, t) => s + t.signedAmount);

  double get totalSavings =>
      _txns.fold<double>(0, (s, t) => s + t.signedAmount);

  Future<Goal> addGoal({
    required String name,
    String emoji = '🎯',
    double? targetAmount,
    String notes = '',
  }) async {
    final goal = Goal(
      id: _uuid.v4(),
      name: name,
      emoji: emoji,
      targetAmount: targetAmount,
      notes: notes,
      sortOrder: _goals.length,
    );
    await storage.saveGoal(goal);
    _refresh();
    notifyListeners();
    return goal;
  }

  Future<void> updateGoal(Goal goal) async {
    await storage.saveGoal(goal);
    _refresh();
    notifyListeners();
  }

  Future<void> deleteGoal(String id) async {
    await storage.deleteGoal(id);
    await storage.deleteTransactionsForGoal(id);
    _refresh();
    notifyListeners();
  }

  Future<void> reorderGoals(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final list = [..._goals];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    for (var i = 0; i < list.length; i++) {
      list[i].sortOrder = i;
      await storage.saveGoal(list[i]);
    }
    _refresh();
    notifyListeners();
  }

  // ----- Goal Transactions ----------------------------------------------
  Future<TxnEntry> addTransaction({
    required String goalId,
    required double amount,
    required TxnType type,
    String note = '',
    DateTime? date,
  }) async {
    final txn = TxnEntry(
      id: _uuid.v4(),
      goalId: goalId,
      amount: amount,
      type: type,
      note: note,
      date: date,
    );
    await storage.saveTransaction(txn);

    final goal = _goals.firstWhere((g) => g.id == goalId);
    final newBalance = balanceFor(goalId) + txn.signedAmount;
    if (goal.targetAmount != null &&
        newBalance >= goal.targetAmount! &&
        goal.completedAt == null) {
      goal.completedAt = DateTime.now();
      await storage.saveGoal(goal);
    } else if (goal.completedAt != null &&
        goal.targetAmount != null &&
        newBalance < goal.targetAmount!) {
      goal.completedAt = null;
      await storage.saveGoal(goal);
    }

    _refresh();
    notifyListeners();
    return txn;
  }

  Future<void> deleteTransaction(String id) async {
    await storage.deleteTransaction(id);
    _refresh();
    notifyListeners();
  }

  List<double> dailyDepositsLastDays(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final out = List<double>.filled(days, 0);
    for (final t in _txns) {
      if (t.type != TxnType.deposit) continue;
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      final diff = today.difference(d).inDays;
      if (diff >= 0 && diff < days) {
        out[days - 1 - diff] += t.amount;
      }
    }
    return out;
  }

  // ----- Debts -----------------------------------------------------------
  double get totalOwedToMe => _debts
      .where((d) => d.direction == DebtDirection.owedToMe)
      .fold<double>(0, (s, d) => s + d.remaining);

  double get totalIOwe => _debts
      .where((d) => d.direction == DebtDirection.iOwe)
      .fold<double>(0, (s, d) => s + d.remaining);

  Future<Debt> addDebt({
    required String party,
    required DebtDirection direction,
    required double originalAmount,
    DateTime? dueDate,
    String notes = '',
  }) async {
    final debt = Debt(
      id: _uuid.v4(),
      party: party,
      direction: direction,
      originalAmount: originalAmount,
      dueDate: dueDate,
      notes: notes,
    );
    await storage.saveDebt(debt);
    _refresh();
    notifyListeners();
    return debt;
  }

  Future<void> updateDebt(Debt debt) async {
    await storage.saveDebt(debt);
    _refresh();
    notifyListeners();
  }

  Future<void> deleteDebt(String id) async {
    await storage.deleteDebt(id);
    _refresh();
    notifyListeners();
  }

  Future<void> addDebtPayment({
    required String debtId,
    required double amount,
    String note = '',
    DateTime? date,
  }) async {
    final debt = _debts.firstWhere((d) => d.id == debtId);
    debt.payments.add(DebtPayment(
      id: _uuid.v4(),
      amount: amount,
      note: note,
      date: date,
    ));
    await storage.saveDebt(debt);
    _refresh();
    notifyListeners();
  }

  Future<void> updateDebtPayment({
    required String debtId,
    required String paymentId,
    required double amount,
    String note = '',
    DateTime? date,
  }) async {
    final debt = _debts.firstWhere((d) => d.id == debtId);
    final p = debt.payments.firstWhere((p) => p.id == paymentId);
    p.amount = amount;
    p.note = note;
    if (date != null) p.date = date;
    await storage.saveDebt(debt);
    _refresh();
    notifyListeners();
  }

  Future<void> deleteDebtPayment({
    required String debtId,
    required String paymentId,
  }) async {
    final debt = _debts.firstWhere((d) => d.id == debtId);
    debt.payments.removeWhere((p) => p.id == paymentId);
    await storage.saveDebt(debt);
    _refresh();
    notifyListeners();
  }

  // ----- Wallets ---------------------------------------------------------
  List<WalletTxn> walletTxnsFor(String walletId) =>
      _walletTxns.where((t) => t.walletId == walletId).toList();

  double walletBalance(String walletId) {
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    return walletTxnsFor(walletId)
            .fold<double>(0, (s, t) => s + t.signedAmount) +
        wallet.openingBalance;
  }

  double get totalAssets => _wallets
      .where((w) => !w.archived && !w.isVault)
      .fold<double>(0, (s, w) => s + walletBalance(w.id));

  /// Hidden vault assets — only computed when explicitly requested.
  double get totalVaultAssets => _wallets
      .where((w) => !w.archived && w.isVault)
      .fold<double>(0, (s, w) => s + walletBalance(w.id));

  /// Net worth = public assets - debts I owe (we don't add owedToMe to keep
  /// it conservative; users can think of that as a receivable). Vault
  /// balances are deliberately excluded so the public net worth doesn't
  /// leak the existence of hidden funds.
  double get netWorth => totalAssets - totalIOwe;

  Future<Wallet> addWallet({
    required String name,
    required WalletCategory category,
    String emoji = '💳',
    int colorValue = 0xFF2BB3A4,
    double openingBalance = 0,
    String notes = '',
    bool isVault = false,
  }) async {
    final w = Wallet(
      id: _uuid.v4(),
      name: name,
      category: category,
      emoji: emoji,
      colorValue: colorValue,
      openingBalance: openingBalance,
      notes: notes,
      sortOrder: _wallets.length,
      isVault: isVault,
    );
    await storage.saveWallet(w);
    _refresh();
    notifyListeners();
    return w;
  }

  Future<void> updateWallet(Wallet w) async {
    await storage.saveWallet(w);
    _refresh();
    notifyListeners();
  }

  Future<void> deleteWallet(String id) async {
    await storage.deleteWallet(id);
    await storage.deleteWalletTxnsForWallet(id);
    _refresh();
    notifyListeners();
  }

  Future<void> reorderWallets(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final list = [..._wallets];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    for (var i = 0; i < list.length; i++) {
      list[i].sortOrder = i;
      await storage.saveWallet(list[i]);
    }
    _refresh();
    notifyListeners();
  }

  Future<WalletTxn> addWalletTxn({
    required String walletId,
    required WalletTxnType type,
    required double amount,
    String category = '',
    String note = '',
    DateTime? date,
  }) async {
    final t = WalletTxn(
      id: _uuid.v4(),
      walletId: walletId,
      type: type,
      amount: amount,
      category: category,
      note: note,
      date: date,
    );
    await storage.saveWalletTxn(t);
    _refresh();
    notifyListeners();
    return t;
  }

  Future<void> deleteWalletTxn(String id) async {
    final t = _walletTxns.firstWhere((x) => x.id == id);
    if (t.linkedTxnId != null) {
      // delete the paired side too
      final pairs = _walletTxns
          .where((x) => x.linkedTxnId == t.linkedTxnId)
          .toList();
      for (final p in pairs) {
        await storage.deleteWalletTxn(p.id);
      }
    } else {
      await storage.deleteWalletTxn(id);
    }
    _refresh();
    notifyListeners();
  }

  /// Atomic-ish transfer: writes a transferOut on source and transferIn
  /// on destination, sharing a linkedTxnId so they can be deleted together.
  Future<void> transferBetweenWallets({
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    String note = '',
    DateTime? date,
  }) async {
    if (fromWalletId == toWalletId) return;
    if (amount <= 0) return;
    final pairId = _uuid.v4();
    final out = WalletTxn(
      id: _uuid.v4(),
      walletId: fromWalletId,
      type: WalletTxnType.transferOut,
      amount: amount,
      note: note,
      date: date,
      linkedTxnId: pairId,
      category: 'Transfer',
    );
    final inn = WalletTxn(
      id: _uuid.v4(),
      walletId: toWalletId,
      type: WalletTxnType.transferIn,
      amount: amount,
      note: note,
      date: date,
      linkedTxnId: pairId,
      category: 'Transfer',
    );
    await storage.saveWalletTxn(out);
    await storage.saveWalletTxn(inn);
    _refresh();
    notifyListeners();
  }
}
