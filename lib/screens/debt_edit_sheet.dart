import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/debt.dart';
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

    if (widget.debt == null) {
      await state.addDebt(
        party: party,
        direction: _direction,
        originalAmount: amount,
        dueDate: _dueDate,
        notes: _notes.text.trim(),
      );
    } else {
      final d = widget.debt!
        ..party = party
        ..direction = _direction
        ..originalAmount = amount
        ..dueDate = _dueDate
        ..notes = _notes.text.trim();
      await state.updateDebt(d);
    }
    if (mounted) Navigator.of(context).pop();
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
    if (_isEdit) {
      await state.updateDebtPayment(
        debtId: widget.debt.id,
        paymentId: widget.payment!.id,
        amount: amount,
        note: _note.text.trim(),
        date: _date,
      );
    } else {
      await state.addDebtPayment(
        debtId: widget.debt.id,
        amount: amount,
        note: _note.text.trim(),
        date: _date,
      );
    }
    if (mounted) Navigator.of(context).pop();
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
