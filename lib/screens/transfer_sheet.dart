import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wallet.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/money_input.dart';
import '../widgets/money_text.dart';

Future<void> showTransferSheet(
  BuildContext context, {
  String? defaultFromId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _TransferSheet(defaultFromId: defaultFromId),
  );
}

class _TransferSheet extends StatefulWidget {
  const _TransferSheet({this.defaultFromId});
  final String? defaultFromId;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _fromId;
  String? _toId;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final wallets = context.read<AppState>().wallets;
    if (wallets.isNotEmpty) {
      _fromId = widget.defaultFromId ?? wallets.first.id;
      final remaining = wallets.where((w) => w.id != _fromId).toList();
      _toId = remaining.isNotEmpty ? remaining.first.id : null;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount =
        double.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0;
    if (amount <= 0 || _fromId == null || _toId == null) return;
    if (_fromId == _toId) return;

    final state = context.read<AppState>();
    final balance = state.walletBalance(_fromId!);
    if (amount > balance) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Exceeds source balance'),
          content: const Text(
              'The transfer is larger than the source wallet\'s balance. Continue anyway?'),
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

    await state.transferBetweenWallets(
      fromWalletId: _fromId!,
      toWalletId: _toId!,
      amount: amount,
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
    final state = context.watch<AppState>();
    final wallets = state.wallets;

    if (wallets.length < 2) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_horiz_rounded,
                size: 36, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text(
              'Transfers need at least two wallets.',
              style:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }

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
              'Transfer between wallets',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            _WalletPicker(
              label: 'From',
              wallets: wallets,
              selectedId: _fromId,
              onChanged: (id) {
                setState(() {
                  _fromId = id;
                  if (_toId == _fromId) {
                    _toId = wallets
                        .firstWhere((w) => w.id != _fromId)
                        .id;
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.south_rounded,
                    color: AppColors.primary, size: 20),
              ),
            ),
            const SizedBox(height: 8),
            _WalletPicker(
              label: 'To',
              wallets: wallets.where((w) => w.id != _fromId).toList(),
              selectedId: _toId,
              onChanged: (id) => setState(() => _toId = id),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [ThousandsInputFormatter()],
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                prefixText: '₱ ',
                prefixStyle: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700),
                hintText: '0',
              ),
            ),
            const SizedBox(height: 12),
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
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Transfer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletPicker extends StatelessWidget {
  const _WalletPicker({
    required this.label,
    required this.wallets,
    required this.selectedId,
    required this.onChanged,
  });

  final String label;
  final List<Wallet> wallets;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButton<String>(
        value: selectedId,
        isExpanded: true,
        underline: const SizedBox(),
        items: wallets.map((w) {
          return DropdownMenuItem<String>(
            value: w.id,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(w.colorValue).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                      child: Text(w.emoji,
                          style: const TextStyle(fontSize: 16))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    w.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                MoneyText(
                  state.walletBalance(w.id),
                  compact: true,
                  respectHide: false,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
