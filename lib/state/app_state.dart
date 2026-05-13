import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/debt.dart';
import '../models/goal.dart';
import '../models/txn_entry.dart';
import '../models/wallet.dart';
import '../models/wallet_txn.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/wallet_asset_service.dart';

class AppState extends ChangeNotifier {
  AppState(this.storage) {
    _hideBalances = storage.hideBalances;
    _refresh();
    _rescheduleInactivityReminders();
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

  /// Look up a wallet by id across both public and vault sets.
  Wallet? walletById(String id) {
    for (final w in _wallets) {
      if (w.id == id) return w;
    }
    return null;
  }

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
    _rescheduleInactivityReminders();
  }

  /// Most recent timestamp across all tracked activity (wallet txns, goal
  /// deposits/withdrawals, debt payments). Used to compute when to remind a
  /// dormant user to log again.
  DateTime get lastActivityDate {
    DateTime latest = DateTime.fromMillisecondsSinceEpoch(0);
    for (final t in _walletTxns) {
      if (t.date.isAfter(latest)) latest = t.date;
    }
    for (final t in _txns) {
      if (t.date.isAfter(latest)) latest = t.date;
    }
    if (latest.millisecondsSinceEpoch == 0) {
      // No activity yet — pretend "today" so the 3-day reminder fires 3 days
      // after install, not from epoch.
      return DateTime.now();
    }
    return latest;
  }

  void _rescheduleInactivityReminders() {
    // Fire-and-forget; service handles its own init/cancel.
    NotificationService.instance
        .scheduleInactivityReminders(lastActivity: lastActivityDate);
  }

  // ---- Milestone thresholds ---------------------------------------------
  static const _goalMilestones = [25, 50, 75, 100];
  static const _assetMilestones = [
    10000, 20000, 30000, 50000, 100000, 250000, 500000, 1000000,
  ];

  Future<void> _checkGoalMilestone(String goalId) async {
    final g = _goals.firstWhere((x) => x.id == goalId,
        orElse: () => Goal(id: '', name: ''));
    if (g.id.isEmpty || g.targetAmount == null || g.targetAmount! <= 0) return;
    final pct = ((balanceFor(g.id) / g.targetAmount!) * 100).floor();
    // Collect every milestone newly crossed by this update so we can mark
    // them all fired (preventing future re-fires) but only NOTIFY for the
    // highest one. A single big deposit that jumps from 0% to 100% should
    // ring once with the 100% celebration, not four times in a row.
    final newlyCrossed = _goalMilestones
        .where((t) => pct >= t && !g.notifiedMilestones.contains(t))
        .toList();
    if (newlyCrossed.isEmpty) return;
    g.notifiedMilestones.addAll(newlyCrossed);
    await storage.saveGoal(g);
    final highest = newlyCrossed.last; // _goalMilestones is ascending
    await NotificationService.instance.celebrateGoalMilestone(
      goalId: g.id,
      goalName: g.name,
      emoji: g.emoji,
      percent: highest,
    );
  }

  Future<void> _checkAssetMilestone(double previousAssets) async {
    final current = totalAssets;
    if (current <= previousAssets) return;
    // Same anti-spam approach as goal milestones — a single big inflow that
    // vaults past several thresholds should only ping the highest one.
    final newlyCrossed = <int>[];
    for (final m in _assetMilestones) {
      if (previousAssets < m && current >= m && !storage.assetMilestoneFired(m)) {
        newlyCrossed.add(m);
      }
    }
    if (newlyCrossed.isEmpty) return;
    for (final m in newlyCrossed) {
      await storage.markAssetMilestoneFired(m);
    }
    await NotificationService.instance
        .celebrateAssetMilestone(peso: newlyCrossed.last);
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
    String emoji2 = '',
    double? targetAmount,
    String notes = '',
  }) async {
    final goal = Goal(
      id: _uuid.v4(),
      name: name,
      emoji: emoji,
      emoji2: emoji2,
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
      // Withdrawal dropped us below the target — un-complete the goal AND
      // forget any milestones no longer satisfied so re-completion celebrates
      // again instead of going silent forever.
      goal.completedAt = null;
      final pct = ((newBalance / goal.targetAmount!) * 100).floor();
      goal.notifiedMilestones.removeWhere((m) => pct < m);
      await storage.saveGoal(goal);
    }

    _refresh();
    notifyListeners();
    _checkGoalMilestone(goalId);
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
    String? walletId,
  }) async {
    final prevAssets = totalAssets;
    final debt = Debt(
      id: _uuid.v4(),
      party: party,
      direction: direction,
      originalAmount: originalAmount,
      dueDate: dueDate,
      notes: notes,
      walletId: (walletId == null || walletId.isEmpty) ? null : walletId,
    );
    if (debt.walletId != null) {
      final txn = await _writeDebtPrincipalTxn(debt: debt);
      debt.linkedWalletTxnId = txn.id;
    }
    await storage.saveDebt(debt);
    _refresh();
    notifyListeners();
    _rescheduleInactivityReminders();
    _rescheduleDebtReminders(debt);
    _checkAssetMilestone(prevAssets);
    return debt;
  }

  Future<void> _rescheduleDebtReminders(Debt d) async {
    await NotificationService.instance.scheduleDebtReminders(
      debtId: d.id,
      party: d.party,
      iOwe: d.direction == DebtDirection.iOwe,
      dueDate: d.dueDate,
      remaining: d.remaining,
    );
  }

  /// Edit an existing debt. If [walletId] is provided (even as ""/null),
  /// the principal wallet linkage is reconciled to match.
  Future<void> updateDebt(
    Debt debt, {
    String? walletId,
    bool walletIdProvided = false,
  }) async {
    if (walletIdProvided) {
      final newWalletId =
          (walletId == null || walletId.isEmpty) ? null : walletId;
      final oldLinkedId = debt.linkedWalletTxnId;
      final oldWalletId = debt.walletId;

      if (oldLinkedId != null &&
          (newWalletId == null || newWalletId != oldWalletId)) {
        await storage.deleteWalletTxn(oldLinkedId);
        debt.linkedWalletTxnId = null;
      }
      debt.walletId = newWalletId;

      if (newWalletId != null) {
        if (debt.linkedWalletTxnId != null) {
          final existing = _walletTxns.firstWhere(
              (t) => t.id == debt.linkedWalletTxnId,
              orElse: () => _missingTxn);
          if (!identical(existing, _missingTxn)) {
            existing.amount = debt.originalAmount;
            existing.note = _principalTxnNote(debt);
            await storage.saveWalletTxn(existing);
          } else {
            final txn = await _writeDebtPrincipalTxn(debt: debt);
            debt.linkedWalletTxnId = txn.id;
          }
        } else {
          final txn = await _writeDebtPrincipalTxn(debt: debt);
          debt.linkedWalletTxnId = txn.id;
        }
      }
    } else if (debt.linkedWalletTxnId != null) {
      // No wallet change requested but amount or party name may have. Keep
      // both the linked txn amount and its note (which embeds the party)
      // in sync so the wallet history doesn't go stale on a rename.
      final existing = _walletTxns.firstWhere(
          (t) => t.id == debt.linkedWalletTxnId,
          orElse: () => _missingTxn);
      if (!identical(existing, _missingTxn)) {
        final freshNote = _principalTxnNote(debt);
        if (existing.amount != debt.originalAmount ||
            existing.note != freshNote) {
          existing.amount = debt.originalAmount;
          existing.note = freshNote;
          await storage.saveWalletTxn(existing);
        }
      }
    }
    await storage.saveDebt(debt);
    _refresh();
    notifyListeners();
    _rescheduleInactivityReminders();
    _rescheduleDebtReminders(debt);
  }

  String _principalTxnNote(Debt debt) =>
      debt.direction == DebtDirection.iOwe
          ? 'Borrowed from ${debt.party}'
          : 'Lent to ${debt.party}';

  Future<WalletTxn> _writeDebtPrincipalTxn({required Debt debt}) async {
    // iOwe → money came IN to your wallet (income). owedToMe → money went OUT (expense).
    final type = debt.direction == DebtDirection.iOwe
        ? WalletTxnType.income
        : WalletTxnType.expense;
    final txn = WalletTxn(
      id: _uuid.v4(),
      walletId: debt.walletId!,
      type: type,
      amount: debt.originalAmount,
      category: 'Debt',
      note: _principalTxnNote(debt),
      date: debt.createdAt,
    );
    await storage.saveWalletTxn(txn);
    return txn;
  }

  Future<void> deleteDebt(String id) async {
    final debt = _debts.firstWhere((d) => d.id == id,
        orElse: () => Debt(
            id: '', party: '', direction: DebtDirection.iOwe, originalAmount: 0));
    if (debt.id.isNotEmpty) {
      if (debt.linkedWalletTxnId != null) {
        await storage.deleteWalletTxn(debt.linkedWalletTxnId!);
      }
      for (final p in debt.payments) {
        if (p.linkedWalletTxnId != null) {
          await storage.deleteWalletTxn(p.linkedWalletTxnId!);
        }
      }
    }
    await storage.deleteDebt(id);
    await NotificationService.instance.cancelDebtReminders(id);
    _refresh();
    notifyListeners();
    _rescheduleInactivityReminders();
  }

  Future<void> addDebtPayment({
    required String debtId,
    required double amount,
    String note = '',
    DateTime? date,
    String? walletId,
  }) async {
    final debt = _debts.firstWhere((d) => d.id == debtId);
    final payment = DebtPayment(
      id: _uuid.v4(),
      amount: amount,
      note: note,
      date: date,
      walletId: walletId,
    );
    if (walletId != null && walletId.isNotEmpty) {
      final txn = await _writeDebtWalletTxn(
        debt: debt,
        payment: payment,
        walletId: walletId,
      );
      payment.linkedWalletTxnId = txn.id;
    }
    debt.payments.add(payment);
    await storage.saveDebt(debt);
    _refresh();
    notifyListeners();
    _rescheduleInactivityReminders();
    _rescheduleDebtReminders(debt);
  }

  Future<void> updateDebtPayment({
    required String debtId,
    required String paymentId,
    required double amount,
    String note = '',
    DateTime? date,
    String? walletId,
  }) async {
    final debt = _debts.firstWhere((d) => d.id == debtId);
    final p = debt.payments.firstWhere((p) => p.id == paymentId);
    p.amount = amount;
    p.note = note;
    if (date != null) p.date = date;

    final newWalletId = (walletId == null || walletId.isEmpty) ? null : walletId;
    final oldLinkedId = p.linkedWalletTxnId;
    final oldWalletId = p.walletId;

    if (oldLinkedId != null && (newWalletId == null || newWalletId != oldWalletId)) {
      // Wallet removed or changed — drop the previous linked txn.
      await storage.deleteWalletTxn(oldLinkedId);
      p.linkedWalletTxnId = null;
    }

    p.walletId = newWalletId;

    if (newWalletId != null) {
      if (p.linkedWalletTxnId != null) {
        // Same wallet, just update amount/note/date on the existing txn.
        final existing = _walletTxns
            .firstWhere((t) => t.id == p.linkedWalletTxnId, orElse: () => _missingTxn);
        if (!identical(existing, _missingTxn)) {
          existing.amount = amount;
          existing.note = _debtTxnNote(debt, note);
          existing.date = p.date;
          await storage.saveWalletTxn(existing);
        } else {
          // Linked txn was independently deleted — recreate it.
          final txn = await _writeDebtWalletTxn(
            debt: debt, payment: p, walletId: newWalletId);
          p.linkedWalletTxnId = txn.id;
        }
      } else {
        final txn = await _writeDebtWalletTxn(
          debt: debt, payment: p, walletId: newWalletId);
        p.linkedWalletTxnId = txn.id;
      }
    }

    await storage.saveDebt(debt);
    _refresh();
    notifyListeners();
    _rescheduleInactivityReminders();
    _rescheduleDebtReminders(debt);
  }

  Future<void> deleteDebtPayment({
    required String debtId,
    required String paymentId,
  }) async {
    final debt = _debts.firstWhere((d) => d.id == debtId);
    final p = debt.payments.firstWhere((x) => x.id == paymentId,
        orElse: () => DebtPayment(id: '', amount: 0));
    if (p.id.isNotEmpty && p.linkedWalletTxnId != null) {
      await storage.deleteWalletTxn(p.linkedWalletTxnId!);
    }
    debt.payments.removeWhere((p) => p.id == paymentId);
    await storage.saveDebt(debt);
    _refresh();
    notifyListeners();
    _rescheduleInactivityReminders();
    _rescheduleDebtReminders(debt);
  }

  static final WalletTxn _missingTxn = WalletTxn(
    id: '', walletId: '', type: WalletTxnType.income, amount: 0);

  String _debtTxnNote(Debt debt, String userNote) {
    final base = debt.direction == DebtDirection.iOwe
        ? 'Debt payment: ${debt.party}'
        : 'Debt collected: ${debt.party}';
    return userNote.isEmpty ? base : '$base — $userNote';
  }

  Future<WalletTxn> _writeDebtWalletTxn({
    required Debt debt,
    required DebtPayment payment,
    required String walletId,
  }) async {
    final type = debt.direction == DebtDirection.iOwe
        ? WalletTxnType.expense
        : WalletTxnType.income;
    final txn = WalletTxn(
      id: _uuid.v4(),
      walletId: walletId,
      type: type,
      amount: payment.amount,
      category: 'Debt',
      note: _debtTxnNote(debt, payment.note),
      date: payment.date,
    );
    await storage.saveWalletTxn(txn);
    return txn;
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
    String? id,
    required String name,
    required WalletCategory category,
    String emoji = '💳',
    int colorValue = 0xFF2BB3A4,
    int colorValue2 = 0,
    double openingBalance = 0,
    String notes = '',
    bool isVault = false,
    String accountNumber = '',
    String qrFileName = '',
  }) async {
    final w = Wallet(
      id: id ?? _uuid.v4(),
      name: name,
      category: category,
      emoji: emoji,
      colorValue: colorValue,
      colorValue2: colorValue2,
      openingBalance: openingBalance,
      notes: notes,
      sortOrder: _wallets.length,
      isVault: isVault,
      accountNumber: accountNumber,
      qrFileName: qrFileName,
    );
    await storage.saveWallet(w);
    _refresh();
    notifyListeners();
    return w;
  }

  Future<void> updateWallet(Wallet w) async {
    final prevAssets = totalAssets;
    await storage.saveWallet(w);
    _refresh();
    notifyListeners();
    // openingBalance edits change totalAssets without going through a txn,
    // so the milestone check needs to run here too.
    _checkAssetMilestone(prevAssets);
  }

  Future<void> deleteWallet(String id) async {
    // Cascade: any debt/payment that points into this wallet via a linked
    // WalletTxn must have its reference cleared, otherwise later edits would
    // resurrect a txn pointing at a deleted wallet (silent balance corruption).
    final removedTxnIds = _walletTxns
        .where((t) => t.walletId == id)
        .map((t) => t.id)
        .toSet();
    if (removedTxnIds.isNotEmpty) {
      for (final debt in _debts) {
        var dirty = false;
        final before = debt.payments.length;
        debt.payments.removeWhere(
          (p) =>
              p.linkedWalletTxnId != null &&
              removedTxnIds.contains(p.linkedWalletTxnId),
        );
        if (debt.payments.length != before) dirty = true;
        if (debt.linkedWalletTxnId != null &&
            removedTxnIds.contains(debt.linkedWalletTxnId)) {
          debt.linkedWalletTxnId = null;
          debt.walletId = null;
          dirty = true;
        }
        if (dirty) await storage.saveDebt(debt);
      }
    }
    await storage.deleteWallet(id);
    await storage.deleteWalletTxnsForWallet(id);
    await WalletAssetService().deleteForWallet(id);
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
    final prevAssets = totalAssets;
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
    _rescheduleInactivityReminders();
    _checkAssetMilestone(prevAssets);
    return t;
  }

  Future<void> deleteWalletTxn(String id) async {
    final t = _walletTxns.firstWhere((x) => x.id == id);
    final removedTxnIds = <String>{};
    if (t.linkedTxnId != null) {
      // delete the paired side too
      final pairs = _walletTxns
          .where((x) => x.linkedTxnId == t.linkedTxnId)
          .toList();
      for (final p in pairs) {
        await storage.deleteWalletTxn(p.id);
        removedTxnIds.add(p.id);
      }
    } else {
      await storage.deleteWalletTxn(id);
      removedTxnIds.add(id);
    }
    // Cascade: any debt payments linked to these wallet txns must go too,
    // since the source-of-truth (the wallet entry) is now gone.
    for (final debt in _debts) {
      var dirty = false;
      final before = debt.payments.length;
      debt.payments.removeWhere(
        (p) =>
            p.linkedWalletTxnId != null &&
            removedTxnIds.contains(p.linkedWalletTxnId),
      );
      if (debt.payments.length != before) dirty = true;
      // Principal link: if the wallet txn that opened this debt got deleted,
      // keep the debt itself but drop the orphaned link.
      if (debt.linkedWalletTxnId != null &&
          removedTxnIds.contains(debt.linkedWalletTxnId)) {
        debt.linkedWalletTxnId = null;
        debt.walletId = null;
        dirty = true;
      }
      if (dirty) await storage.saveDebt(debt);
    }
    _refresh();
    notifyListeners();
    _rescheduleInactivityReminders();
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
