import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/debt.dart';
import '../models/wallet.dart';
import '../state/app_state.dart';
import '../widgets/money_input.dart';

Future<void> showDebtEditSheet(BuildContext context, {Debt? debt}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _DebtEditSheet(debt: debt),
  );
}

class _DebtEditSheet extends StatefulWidget {
  const _DebtEditSheet({this.debt});
  final Debt? debt;

  @override
  State<_DebtEditSheet> createState() => _DebtEditSheetState();
}

class _DebtEditSheetState extends State<_DebtEditSheet> {
  late final TextEditingController _party;
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  late DebtDirection _direction;
  DateTime? _dueDate;
  String? _walletId;
  bool _walletTouched = false;

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    _party = TextEditingController(text: d?.party ?? '');
    _amount = TextEditingController(
      text: formatAmountForField(d?.originalAmount),
    );
    _notes = TextEditingController(text: d?.notes ?? '');
    _direction = d?.direction ?? DebtDirection.owedToMe;
    _dueDate = d?.dueDate;
    _walletId = d?.walletId;
  }

  @override
  void dispose() {
    _party.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final party = _party.text.trim();
    final amount =
        double.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0;
    if (party.isEmpty || amount <= 0) return;

    // Only "Owed to me" with a linked wallet writes a debit; that's the
    // case where the wallet could go negative if we're not careful.
    if (_walletId != null && _direction == DebtDirection.owedToMe) {
      final balance = state.walletBalance(_walletId!);
      // For an edit, the existing principal txn (if any on the same wallet)
      // already contributes to the balance — adjusting only the delta.
      final priorContribution = (widget.debt?.walletId == _walletId &&
              widget.debt?.linkedWalletTxnId != null)
          ? widget.debt!.originalAmount
          : 0;
      final effectiveBalance = balance + priorContribution;
      if (amount > effectiveBalance + 0.001) {
        final wallet = state.walletById(_walletId!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not enough balance in ${wallet?.name ?? "this wallet"} '
              '(₱ ${effectiveBalance.toStringAsFixed(2)}). Lower the amount '
              'or pick another wallet.',
            ),
          ),
        );
        return;
      }
    }

    if (widget.debt == null) {
      await state.addDebt(
        party: party,
        direction: _direction,
        originalAmount: amount,
        dueDate: _dueDate,
        notes: _notes.text.trim(),
        walletId: _walletId,
      );
    } else {
      final d = widget.debt!
        ..party = party
        ..direction = _direction
        ..originalAmount = amount
        ..dueDate = _dueDate
        ..notes = _notes.text.trim();
      await state.updateDebt(
        d,
        walletId: _walletId,
        walletIdProvided: _walletTouched,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDebtWallet(List<Wallet> wallets) async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Choose wallet',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.block, size: 20),
              title: const Text('No wallet (just record the debt)'),
              onTap: () => Navigator.of(context).pop(''),
            ),
            const Divider(height: 1),
            ...wallets.map(
              (w) => ListTile(
                leading: Text(w.emoji, style: const TextStyle(fontSize: 22)),
                title: Text(w.name),
                trailing: _walletId == w.id
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () => Navigator.of(context).pop(w.id),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _walletId = picked.isEmpty ? null : picked;
      _walletTouched = true;
    });
  }

  Future<void> _pickDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.debt != null;
    final wallets = context.watch<AppState>().wallets;
    final selectedWallet = _walletId == null
        ? null
        : wallets.where((w) => w.id == _walletId).firstOrNull;
    final isIOwe = _direction == DebtDirection.iOwe;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
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
            const SizedBox(height: 16),
            Text(
              isEdit ? 'Edit debt' : 'Add debt',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            SegmentedButton<DebtDirection>(
              segments: const [
                ButtonSegment(
                  value: DebtDirection.owedToMe,
                  label: Text('Owed to me'),
                  icon: Icon(Icons.south_west),
                ),
                ButtonSegment(
                  value: DebtDirection.iOwe,
                  label: Text('I owe'),
                  icon: Icon(Icons.north_east),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (s) =>
                  setState(() => _direction = s.first),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _party,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _direction == DebtDirection.owedToMe
                    ? 'Who owes you?'
                    : 'Who do you owe?',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [ThousandsInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₱ ',
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: wallets.isEmpty ? null : () => _pickDebtWallet(wallets),
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: isIOwe
                      ? 'Money received to wallet (optional)'
                      : 'Money lent from wallet (optional)',
                ),
                child: Row(
                  children: [
                    if (selectedWallet != null) ...[
                      Text(selectedWallet.emoji,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(selectedWallet.name)),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() {
                          _walletId = null;
                          _walletTouched = true;
                        }),
                      ),
                    ] else
                      Expanded(
                        child: Text(
                          wallets.isEmpty
                              ? 'No wallets — add one in Wallets'
                              : 'No wallet linked',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.55),
                          ),
                        ),
                      ),
                    const Icon(Icons.account_balance_wallet_outlined, size: 18),
                  ],
                ),
              ),
            ),
            if (selectedWallet != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  isIOwe
                      ? 'An income entry will be added to ${selectedWallet.name} for the principal.'
                      : 'An expense will be deducted from ${selectedWallet.name} for the principal.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.55),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDue,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Due date (optional)',
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dueDate == null
                            ? 'No due date'
                            : DateFormat.yMMMMd().format(_dueDate!),
                      ),
                    ),
                    if (_dueDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () =>
                            setState(() => _dueDate = null),
                      ),
                    const Icon(Icons.calendar_today_outlined, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _save,
              child: Text(isEdit ? 'Save changes' : 'Add debt'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showDebtPaymentSheet(
  BuildContext context, {
  required Debt debt,
  DebtPayment? payment,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _DebtPaymentSheet(debt: debt, payment: payment),
  );
}

class _DebtPaymentSheet extends StatefulWidget {
  const _DebtPaymentSheet({required this.debt, this.payment});
  final Debt debt;
  final DebtPayment? payment;
  @override
  State<_DebtPaymentSheet> createState() => _DebtPaymentSheetState();
}

class _DebtPaymentSheetState extends State<_DebtPaymentSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late DateTime _date;
  String? _walletId;

  bool get _isEdit => widget.payment != null;

  @override
  void initState() {
    super.initState();
    final p = widget.payment;
    _amount.text = p == null
        ? formatAmountForField(widget.debt.remaining, keepZero: true)
        : formatAmountForField(p.amount, keepZero: true);
    _note.text = p?.note ?? '';
    _date = p?.date ?? DateTime.now();
    _walletId = p?.walletId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  /// What the headroom is on this payment edit. For a new payment that's
  /// the remaining balance. For an edit it's remaining + the payment's
  /// existing amount (so you can raise this row up to the original amount
  /// of headroom + this entry).
  double get _maxAllowed {
    final base = widget.debt.remaining;
    if (_isEdit) return base + widget.payment!.amount;
    return base;
  }

  Future<void> _save() async {
    final amount =
        double.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0;
    if (amount <= 0) return;
    if (amount > _maxAllowed + 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Payment exceeds remaining balance.')),
      );
      return;
    }
    final state = context.read<AppState>();
    // For "I owe" debts paid from a wallet, an expense will post — guard
    // against pushing the wallet below zero.
    if (_walletId != null &&
        widget.debt.direction == DebtDirection.iOwe) {
      final balance = state.walletBalance(_walletId!);
      final priorContribution = (widget.payment != null &&
              widget.payment!.walletId == _walletId &&
              widget.payment!.linkedWalletTxnId != null)
          ? widget.payment!.amount
          : 0;
      final effectiveBalance = balance + priorContribution;
      if (amount > effectiveBalance + 0.001) {
        final wallet = state.walletById(_walletId!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not enough balance in ${wallet?.name ?? "this wallet"} '
              '(₱ ${effectiveBalance.toStringAsFixed(2)}). Lower the amount '
              'or pick another wallet.',
            ),
          ),
        );
        return;
      }
    }
    if (_isEdit) {
      await state.updateDebtPayment(
        debtId: widget.debt.id,
        paymentId: widget.payment!.id,
        amount: amount,
        note: _note.text.trim(),
        date: _date,
        walletId: _walletId,
      );
    } else {
      await state.addDebtPayment(
        debtId: widget.debt.id,
        amount: amount,
        note: _note.text.trim(),
        date: _date,
        walletId: _walletId,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickWallet(List<Wallet> wallets) async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Choose wallet',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.block, size: 20),
              title: const Text('No wallet (just record)'),
              onTap: () => Navigator.of(context).pop(''),
            ),
            const Divider(height: 1),
            ...wallets.map(
              (w) => ListTile(
                leading: Text(w.emoji, style: const TextStyle(fontSize: 22)),
                title: Text(w.name),
                trailing: _walletId == w.id
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () => Navigator.of(context).pop(w.id),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return; // dismissed
    setState(() => _walletId = picked.isEmpty ? null : picked);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final wallets = context.watch<AppState>().wallets;
    final selectedWallet = _walletId == null
        ? null
        : wallets.where((w) => w.id == _walletId).firstOrNull;
    final isIOwe = widget.debt.direction == DebtDirection.iOwe;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
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
            const SizedBox(height: 16),
            Text(
              _isEdit ? 'Edit payment' : 'Record payment',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [ThousandsInputFormatter()],
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                prefixText: '₱ ',
                prefixStyle: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Payment date'),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          DateFormat.yMMMMd().format(_date)),
                    ),
                    const Icon(Icons.calendar_today_outlined, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: wallets.isEmpty ? null : () => _pickWallet(wallets),
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: isIOwe
                      ? 'Pay from wallet (optional)'
                      : 'Receive to wallet (optional)',
                ),
                child: Row(
                  children: [
                    if (selectedWallet != null) ...[
                      Text(selectedWallet.emoji,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(selectedWallet.name)),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _walletId = null),
                      ),
                    ] else
                      Expanded(
                        child: Text(
                          wallets.isEmpty
                              ? 'No wallets — add one in Wallets'
                              : 'No wallet linked',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.55),
                          ),
                        ),
                      ),
                    const Icon(Icons.account_balance_wallet_outlined, size: 18),
                  ],
                ),
              ),
            ),
            if (selectedWallet != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  isIOwe
                      ? 'An expense will be recorded on ${selectedWallet.name}.'
                      : 'Income will be recorded on ${selectedWallet.name}.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.55),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _save,
              child: Text(_isEdit ? 'Save changes' : 'Record payment'),
            ),
          ],
        ),
      ),
    );
  }
}
