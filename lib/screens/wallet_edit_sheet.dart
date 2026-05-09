import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wallet.dart';
import '../state/app_state.dart';
import '../widgets/money_input.dart';

const _emojiChoices = [
  '💳', '🏦', '💵', '💰', '📱', '💎',
  '🪙', '🛟', '📊', '💸', '🐷', '🏧',
];

const _colorChoices = [
  0xFF2BB3A4, 0xFF4F8DF7, 0xFFF7B84F, 0xFFEF6F6C,
  0xFF8B5CF6, 0xFF52C28F, 0xFFFF7AB3, 0xFF3B4252,
];

Future<void> showWalletEditSheet(
  BuildContext context, {
  Wallet? wallet,
  bool asVault = false,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _WalletEditSheet(wallet: wallet, asVault: asVault),
  );
}

class _WalletEditSheet extends StatefulWidget {
  const _WalletEditSheet({this.wallet, this.asVault = false});
  final Wallet? wallet;
  final bool asVault;
  @override
  State<_WalletEditSheet> createState() => _WalletEditSheetState();
}

class _WalletEditSheetState extends State<_WalletEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _opening;
  late final TextEditingController _notes;
  late String _emoji;
  late int _color;
  late WalletCategory _category;

  @override
  void initState() {
    super.initState();
    final w = widget.wallet;
    _name = TextEditingController(text: w?.name ?? '');
    _opening = TextEditingController(
      text: formatAmountForField(w?.openingBalance),
    );
    _notes = TextEditingController(text: w?.notes ?? '');
    _emoji = w?.emoji ?? '💳';
    _color = w?.colorValue ?? _colorChoices.first;
    _category = w?.category ?? WalletCategory.bank;
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final opening =
        double.tryParse(_opening.text.trim().replaceAll(',', '')) ?? 0;
    if (widget.wallet == null) {
      await state.addWallet(
        name: name,
        category: _category,
        emoji: _emoji,
        colorValue: _color,
        openingBalance: opening,
        notes: _notes.text.trim(),
        isVault: widget.asVault,
      );
    } else {
      final w = widget.wallet!
        ..name = name
        ..emoji = _emoji
        ..colorValue = _color
        ..category = _category
        ..openingBalance = opening
        ..notes = _notes.text.trim();
      await state.updateWallet(w);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.wallet != null;
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
              isEdit ? 'Edit wallet' : 'New wallet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            const Text('Icon',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojiChoices.map((e) {
                final selected = _emoji == e;
                return GestureDetector(
                  onTap: () => setState(() => _emoji = e),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? Color(_color).withOpacity(0.9)
                          : Color(_color).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(e,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Color',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colorChoices.map((c) {
                final selected = _color == c;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Color(c) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: Color(c).withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Wallet name',
                hintText: 'e.g. BDO Checking',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<WalletCategory>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: WalletCategory.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.label),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _opening,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [ThousandsInputFormatter()],
              decoration: InputDecoration(
                labelText: isEdit
                    ? 'Opening balance'
                    : 'Current balance (opening)',
                prefixText: '₱ ',
                helperText: isEdit
                    ? 'Adjust only if you mistyped at setup. Use transactions otherwise.'
                    : 'How much is in this wallet right now?',
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(_color),
              ),
              child: Text(isEdit ? 'Save changes' : 'Create wallet'),
            ),
          ],
        ),
      ),
    );
  }
}
