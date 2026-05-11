import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/money_text.dart';
import '../widgets/soft_card.dart';
import 'goal_detail_screen.dart';
import 'goal_edit_sheet.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final goals = state.goals;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ipon Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showGoalEditSheet(context),
          ),
        ],
      ),
      body: goals.isEmpty
          ? _Empty(onCreate: () => showGoalEditSheet(context))
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: goals.length,
              onReorder: (a, b) =>
                  context.read<AppState>().reorderGoals(a, b),
              proxyDecorator: (child, _, __) => Material(
                color: Colors.transparent,
                child: child,
              ),
              itemBuilder: (context, i) {
                final g = goals[i];
                final balance = state.balanceFor(g.id);
                final progress =
                    g.targetAmount == null || g.targetAmount == 0
                        ? null
                        : (balance / g.targetAmount!).clamp(0.0, 1.0);

                return Padding(
                  key: ValueKey(g.id),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SoftCard(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            GoalDetailScreen(goalId: g.id),
                      ));
                    },
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: Stack(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(g.emoji,
                                      style: const TextStyle(fontSize: 26)),
                                ),
                              ),
                              if (g.emoji2.isNotEmpty)
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(0.10),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(g.emoji2,
                                          style: const TextStyle(
                                              fontSize: 13)),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      g.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                      overflow:
                                          TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (g.completedAt != null)
                                    Container(
                                      padding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 8,
                                          vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.success
                                            .withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        '✓ Done',
                                        style: TextStyle(
                                          color: AppColors.success,
                                          fontSize: 11,
                                          fontWeight:
                                              FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  MoneyText(
                                    balance,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (g.targetAmount != null) ...[
                                    Text(
                                      ' / ',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.5),
                                      ),
                                    ),
                                    MoneyText(
                                      g.targetAmount!,
                                      compact: true,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (progress != null) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 6,
                                    backgroundColor: AppColors
                                        .primarySoft
                                        .withOpacity(0.6),
                                    valueColor:
                                        const AlwaysStoppedAnimation(
                                            AppColors.primary),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}% saved',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.55),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.drag_handle,
                                color: Color(0xFFB6BFC9)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.flag_rounded,
                  color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              'No goals yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Set up your first ipon goal — Motor, Emergency Fund, Japan Trip — anything.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create your first goal'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(220, 52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
