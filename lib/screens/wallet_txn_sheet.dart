import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wallet_txn.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/money_input.dart';

const _incomeCategories = [
  'Salary', 'Sideline', 'Bonus', 'Gift', 'Refund', 'Investment', 'Other',
];

const _expenseCategories = [
  'Food', 'Bills', 'Transport', 'Shopping', 'Entertainment',
  'Health', 'Family', 'Subscription', 'Other',
];

Future<void> showWalletTxnSheet(
  BuildContext context, {
  required String walletId,
  required WalletTxnType type,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _WalletTxnSheet(walletId: walletId, type: type),
  );
}

class _WalletTxnSheet extends StatefulWidget {
  const _WalletTxnSheet({required this.walletId, required this.type});
  final String walletId;
  final WalletTxnType type;

  @override
  State<_WalletTxnSheet> createState() => _WalletTxnSheetState();
}

class _WalletTxnSheetState extends State<_WalletTxnSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _category = '';
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount =
        double.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0;
    if (amount <= 0) return;

    final state = context.read<AppState>();
    if (widget.type == WalletTxnType.expense) {
      final balance = state.walletBalance(widget.walletId);
      if (amount > balance) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Exceeds balance'),
            content: const Text(
                'This expense is larger than the wallet\'s current balance. Continue anyway?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Proceed'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    await state.addWalletTxn(
      walletId: widget.walletId,
      type: widget.type,
      amount: amount,
      category: _category,
      note: _note.text.trim(),
      date: _date,
    );
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
    final isIncome = widget.type == WalletTxnType.income;
    final color = isIncome ? AppColors.success : AppColors.danger;
    final categories = isIncome ? _incomeCategories : _expenseCategories;

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
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isIncome ? Icons.south_west : Icons.north_east,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isIncome ? 'Income' : 'Expense',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
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
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
                hintText: '0',
              ),
            ),
            const SizedBox(height: 14),
            const Text('Category',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((c) {
                final selected = _category == c;
                return ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  onSelected: (v) =>
                      setState(() => _category = v ? c : ''),
                  selectedColor: color.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: selected ? color : null,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: selected
                          ? color
                          : Theme.of(context).dividerColor,
                    ),
                  ),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8EE)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                    ),
                    const Spacer(),
                    const Icon(Icons.expand_more),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: color),
              child: Text(isIncome ? 'Add income' : 'Add expense'),
            ),
          ],
        ),
      ),
    );
  }
}
