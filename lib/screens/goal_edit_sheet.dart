import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/goal.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/money_input.dart';

const _emojiChoices = [
  '🎯', '🏍', '🚗', '🏠', '✈️', '📱', '💍', '🎓',
  '💼', '🏝', '🎮', '🍼', '💊', '🛟', '💎', '🐶',
];

Future<void> showGoalEditSheet(BuildContext context, {Goal? goal}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _GoalEditSheet(goal: goal),
  );
}

class _GoalEditSheet extends StatefulWidget {
  const _GoalEditSheet({this.goal});
  final Goal? goal;

  @override
  State<_GoalEditSheet> createState() => _GoalEditSheetState();
}

class _GoalEditSheetState extends State<_GoalEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _notes;
  late String _emoji;
  late String _emoji2;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.goal?.name ?? '');
    _target = TextEditingController(
      text: formatAmountForField(widget.goal?.targetAmount),
    );
    _notes = TextEditingController(text: widget.goal?.notes ?? '');
    _emoji = widget.goal?.emoji ?? '🎯';
    _emoji2 = widget.goal?.emoji2 ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final tgt = double.tryParse(_target.text.trim().replaceAll(',', ''));
    if (widget.goal == null) {
      await state.addGoal(
        name: name,
        emoji: _emoji,
        emoji2: _emoji2,
        targetAmount: tgt,
        notes: _notes.text.trim(),
      );
    } else {
      final g = widget.goal!
        ..name = name
        ..emoji = _emoji
        ..emoji2 = _emoji2
        ..targetAmount = tgt
        ..notes = _notes.text.trim();
      await state.updateGoal(g);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.goal != null;
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
              isEdit ? 'Edit goal' : 'New ipon goal',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            // Live preview of the chosen icon combo.
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(_emoji,
                          style: const TextStyle(fontSize: 38)),
                    ),
                    if (_emoji2.isNotEmpty)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.10),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(_emoji2,
                                style:
                                    const TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Primary icon',
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
                          ? AppColors.primary
                          : AppColors.primarySoft,
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
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('Secondary icon',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _emoji2.isEmpty ? 'None' : 'On',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _emoji2 = ''),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _emoji2.isEmpty
                          ? AppColors.primary.withOpacity(0.12)
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: _emoji2.isEmpty
                          ? Border.all(color: AppColors.primary, width: 2)
                          : null,
                    ),
                    child: Icon(
                      Icons.block_rounded,
                      size: 20,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                    ),
                  ),
                ),
                ..._emojiChoices.where((e) => e != _emoji).map((e) {
                  final selected = _emoji2 == e;
                  return GestureDetector(
                    onTap: () => setState(() => _emoji2 = e),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(e,
                            style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Goal name',
                hintText: 'e.g. Emergency Fund',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _target,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              inputFormatters: [ThousandsInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Target amount (optional)',
                prefixText: '₱ ',
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
              child: Text(isEdit ? 'Save changes' : 'Create goal'),
            ),
          ],
        ),
      ),
    );
  }
}
