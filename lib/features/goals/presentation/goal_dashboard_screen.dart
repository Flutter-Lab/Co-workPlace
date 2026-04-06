import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/features/goals/domain/goal.dart';
import 'package:coworkplace/features/goals/domain/goal_item.dart';
import 'package:coworkplace/features/goals/domain/goal_metrics.dart';
import 'package:coworkplace/features/goals/providers/goal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class GoalDashboardScreen extends ConsumerWidget {
  const GoalDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(appSessionProvider);

    return sessionAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Goal Tracker')),
        body: Center(child: Text('Session error: $error')),
      ),
      data: (session) {
        final userId = session.userId;
        if (userId == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Goal Tracker')),
            body: const Center(child: Text('Sign in to use Goal Tracker.')),
          );
        }

        final goalsAsync = ref.watch(currentUserGoalsProvider);

        return Scaffold(
          appBar: AppBar(title: const Text('Goal Tracker')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                _onCreateGoal(context: context, ref: ref, userId: userId),
            icon: const Icon(Icons.add),
            label: const Text('New Goal'),
          ),
          body: goalsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load goals: $error'),
              ),
            ),
            data: (goals) {
              if (goals.isEmpty) {
                return _GoalEmptyState(
                  onCreate: () =>
                      _onCreateGoal(context: context, ref: ref, userId: userId),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: goals.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  final metrics = GoalMetrics.compute(
                    targetValue: goal.targetValue,
                    completedValue: goal.completedValue,
                    createdAtUtc: goal.createdAtUtc,
                    deadlineUtc: goal.deadlineUtc,
                  );

                  return _GoalCard(
                    goal: goal,
                    metrics: metrics,
                    onViewDetails: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              GoalDetailScreen(userId: userId, goalId: goal.id),
                        ),
                      );
                    },
                    onAddItem: () => _onCreateItem(
                      context: context,
                      ref: ref,
                      userId: userId,
                      goalId: goal.id,
                    ),
                    onAddProgress: () => _onAddSimpleProgress(
                      context: context,
                      ref: ref,
                      userId: userId,
                      goalId: goal.id,
                    ),
                    onEdit: () => _onEditGoal(
                      context: context,
                      ref: ref,
                      userId: userId,
                      goal: goal,
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _onCreateGoal({
    required BuildContext context,
    required WidgetRef ref,
    required String userId,
  }) async {
    final draft = await _showGoalFormSheet(context: context);
    if (draft == null) {
      return;
    }

    try {
      await ref
          .read(goalRepositoryProvider)
          .createGoal(
            userId: userId,
            title: draft.title,
            unitType: draft.unitType,
            customUnitLabel: draft.customUnitLabel,
            targetValue: draft.targetValue,
            deadlineUtc: draft.deadlineUtc,
            isSimpleGoal: draft.isSimpleGoal,
          );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not create goal: $e')));
    }
  }

  Future<void> _onEditGoal({
    required BuildContext context,
    required WidgetRef ref,
    required String userId,
    required Goal goal,
  }) async {
    final draft = await _showGoalFormSheet(context: context, existing: goal);
    if (draft == null) {
      return;
    }

    final updated = goal.copyWith(
      title: draft.title,
      unitType: draft.unitType,
      customUnitLabel: draft.customUnitLabel,
      targetValue: draft.targetValue,
      isSimpleGoal: draft.isSimpleGoal,
      deadlineUtc: draft.deadlineUtc,
      clearCustomUnitLabel: draft.unitType != GoalUnitType.custom,
      clearDeadlineUtc: draft.deadlineUtc == null,
    );

    try {
      await ref
          .read(goalRepositoryProvider)
          .updateGoal(goal: updated, actorUserId: userId);
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update goal: $e')));
    }
  }

  Future<void> _onCreateItem({
    required BuildContext context,
    required WidgetRef ref,
    required String userId,
    required String goalId,
  }) async {
    final draft = await _showGoalItemFormSheet(context: context);
    if (draft == null) {
      return;
    }

    try {
      await ref
          .read(goalRepositoryProvider)
          .createItem(
            userId: userId,
            goalId: goalId,
            name: draft.name,
            totalUnits: draft.totalUnits,
            completedUnits: draft.completedUnits,
            note: draft.note,
          );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add item: $e')));
    }
  }

  Future<void> _onAddSimpleProgress({
    required BuildContext context,
    required WidgetRef ref,
    required String userId,
    required String goalId,
  }) async {
    final delta = await _showAddProgressDialog(context: context);
    if (delta == null) {
      return;
    }

    try {
      await ref
          .read(goalRepositoryProvider)
          .addSimpleProgress(userId: userId, goalId: goalId, delta: delta);
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add progress: $e')));
    }
  }
}

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({
    required this.userId,
    required this.goalId,
    super.key,
  });

  final String userId;
  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(goalRepositoryProvider);

    return StreamBuilder<Goal?>(
      stream: repo.watchGoal(userId, goalId),
      builder: (context, goalSnapshot) {
        if (goalSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final goal = goalSnapshot.data;
        if (goal == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Goal Details')),
            body: const Center(child: Text('This goal no longer exists.')),
          );
        }

        final metrics = GoalMetrics.compute(
          targetValue: goal.targetValue,
          completedValue: goal.completedValue,
          createdAtUtc: goal.createdAtUtc,
          deadlineUtc: goal.deadlineUtc,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(goal.title),
            actions: [
              IconButton(
                tooltip: 'Edit goal',
                onPressed: () => _editGoal(context, ref, goal),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete goal',
                onPressed: () => _deleteGoal(context, ref, goal.id),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          floatingActionButton: goal.isSimpleGoal
              ? FloatingActionButton.extended(
                  onPressed: () => _addSimpleProgress(context, ref, goal.id),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Progress'),
                )
              : FloatingActionButton.extended(
                  onPressed: () => _addItem(context, ref, goal.id),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
          body: StreamBuilder<Map<DateTime, double>>(
            stream: repo.watchDailyProgress(userId, goal.id),
            builder: (context, progressSnapshot) {
              final dailyProgress =
                  progressSnapshot.data ?? const <DateTime, double>{};

              if (goal.isSimpleGoal) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    _GoalSummaryCard(goal: goal, metrics: metrics),
                    const SizedBox(height: 12),
                    _SimpleGoalProgressCard(
                      goal: goal,
                      onAddProgress: () =>
                          _addSimpleProgress(context, ref, goal.id),
                    ),
                    const SizedBox(height: 12),
                    _GoalHeatmapCard(dailyProgress: dailyProgress),
                  ],
                );
              }

              return StreamBuilder<List<GoalItem>>(
                stream: repo.watchItems(userId, goal.id),
                builder: (context, itemSnapshot) {
                  if (itemSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final items = itemSnapshot.data ?? const <GoalItem>[];
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      _GoalSummaryCard(goal: goal, metrics: metrics),
                      const SizedBox(height: 12),
                      _GoalHeatmapCard(dailyProgress: dailyProgress),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Tracked Items',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Text(
                            '${items.length}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (items.isEmpty)
                        _GoalItemsEmptyState(
                          onCreate: () => _addItem(context, ref, goal.id),
                        )
                      else
                        ...items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _GoalItemCard(
                              item: item,
                              unitLabel: _goalUnitLabel(goal),
                              onQuickUpdate: () => _updateProgress(
                                context: context,
                                ref: ref,
                                goalId: goal.id,
                                item: item,
                              ),
                              onEdit: () => _editItem(
                                context: context,
                                ref: ref,
                                goalId: goal.id,
                                item: item,
                              ),
                              onDelete: () => _deleteItem(
                                context: context,
                                ref: ref,
                                goalId: goal.id,
                                itemId: item.id,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _editGoal(BuildContext context, WidgetRef ref, Goal goal) async {
    final draft = await _showGoalFormSheet(context: context, existing: goal);
    if (draft == null) {
      return;
    }

    final updated = goal.copyWith(
      title: draft.title,
      unitType: draft.unitType,
      customUnitLabel: draft.customUnitLabel,
      targetValue: draft.targetValue,
      isSimpleGoal: draft.isSimpleGoal,
      deadlineUtc: draft.deadlineUtc,
      clearCustomUnitLabel: draft.unitType != GoalUnitType.custom,
      clearDeadlineUtc: draft.deadlineUtc == null,
    );

    try {
      await ref
          .read(goalRepositoryProvider)
          .updateGoal(goal: updated, actorUserId: userId);
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update goal: $e')));
    }
  }

  Future<void> _deleteGoal(
    BuildContext context,
    WidgetRef ref,
    String goalId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete goal?'),
          content: const Text(
            'This deletes the goal and all of its tracked items.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref
          .read(goalRepositoryProvider)
          .deleteGoal(userId: userId, goalId: goalId);
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete goal: $e')));
    }
  }

  Future<void> _addItem(
    BuildContext context,
    WidgetRef ref,
    String goalId,
  ) async {
    final draft = await _showGoalItemFormSheet(context: context);
    if (draft == null) {
      return;
    }

    try {
      await ref
          .read(goalRepositoryProvider)
          .createItem(
            userId: userId,
            goalId: goalId,
            name: draft.name,
            totalUnits: draft.totalUnits,
            completedUnits: draft.completedUnits,
            note: draft.note,
          );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add item: $e')));
    }
  }

  Future<void> _addSimpleProgress(
    BuildContext context,
    WidgetRef ref,
    String goalId,
  ) async {
    final delta = await _showAddProgressDialog(context: context);
    if (delta == null) {
      return;
    }

    try {
      await ref
          .read(goalRepositoryProvider)
          .addSimpleProgress(userId: userId, goalId: goalId, delta: delta);
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add progress: $e')));
    }
  }

  Future<void> _editItem({
    required BuildContext context,
    required WidgetRef ref,
    required String goalId,
    required GoalItem item,
  }) async {
    final draft = await _showGoalItemFormSheet(
      context: context,
      existing: item,
    );
    if (draft == null) {
      return;
    }

    try {
      await ref
          .read(goalRepositoryProvider)
          .updateItem(
            userId: userId,
            goalId: goalId,
            item: item.copyWith(
              name: draft.name,
              totalUnits: draft.totalUnits,
              completedUnits: draft.completedUnits,
              note: draft.note,
              clearNote: draft.note == null,
            ),
          );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update item: $e')));
    }
  }

  Future<void> _deleteItem({
    required BuildContext context,
    required WidgetRef ref,
    required String goalId,
    required String itemId,
  }) async {
    try {
      await ref
          .read(goalRepositoryProvider)
          .deleteItem(userId: userId, goalId: goalId, itemId: itemId);
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete item: $e')));
    }
  }

  Future<void> _updateProgress({
    required BuildContext context,
    required WidgetRef ref,
    required String goalId,
    required GoalItem item,
  }) async {
    final updatedCompleted = await _showProgressUpdateDialog(
      context: context,
      item: item,
    );
    if (updatedCompleted == null) {
      return;
    }

    try {
      await ref
          .read(goalRepositoryProvider)
          .updateItemProgress(
            userId: userId,
            goalId: goalId,
            itemId: item.id,
            completedUnits: updatedCompleted,
          );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update progress: $e')));
    }
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.metrics,
    required this.onViewDetails,
    required this.onAddItem,
    required this.onAddProgress,
    required this.onEdit,
  });

  final Goal goal;
  final GoalMetrics metrics;
  final VoidCallback onViewDetails;
  final VoidCallback onAddItem;
  final VoidCallback onAddProgress;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final unit = _goalUnitLabel(goal);
    final state = _goalStateInfo(metrics);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onViewDetails,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _GoalStatePill(info: state),
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit goal',
                  ),
                ],
              ),
              Text(
                '${_formatNumber(metrics.completed)} / ${_formatNumber(metrics.target)} $unit',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                state.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: metrics.progressPercent / 100),
              const SizedBox(height: 10),
              _GoalMetricsWrap(metrics: metrics, unitLabel: unit),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (goal.isSimpleGoal)
                    FilledButton.icon(
                      onPressed: onAddProgress,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Progress'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: onAddItem,
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Add Item'),
                    ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalSummaryCard extends StatelessWidget {
  const _GoalSummaryCard({required this.goal, required this.metrics});

  final Goal goal;
  final GoalMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final unit = _goalUnitLabel(goal);
    final state = _goalStateInfo(metrics);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _GoalStatePill(info: state),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Target: ${_formatNumber(metrics.target)} $unit',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Completed: ${_formatNumber(metrics.completed)} $unit',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Remaining: ${_formatNumber(metrics.remaining)} $unit',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              state.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: metrics.progressPercent / 100),
            const SizedBox(height: 10),
            _GoalMetricsWrap(metrics: metrics, unitLabel: unit),
          ],
        ),
      ),
    );
  }
}

class _GoalMetricsWrap extends StatelessWidget {
  const _GoalMetricsWrap({required this.metrics, required this.unitLabel});

  final GoalMetrics metrics;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final expectedRemainingDays = metrics.estimatedDaysToTarget == null
        ? '-'
        : '${metrics.estimatedDaysToTarget!.ceil()}';
    final paceValue = metrics.requiredPerDay ?? metrics.averagePerDay;

    final tiles = [
      _GoalStateTile(
        icon: Icons.trending_up,
        iconColor: const Color(0xFF22C55E),
        value: _formatNumber(metrics.completed),
        label: 'Done',
        infoTitle: 'Done',
        infoText: 'How much of the goal is already completed.',
      ),
      _GoalStateTile(
        icon: Icons.access_time_outlined,
        iconColor: const Color(0xFFF59E0B),
        value: _formatNumber(metrics.remaining),
        label: 'Left',
        infoTitle: 'Left',
        infoText: 'How much is still left to finish.',
      ),
      _GoalStateTile(
        icon: Icons.calendar_today_outlined,
        iconColor: const Color(0xFF3B82F6),
        value: metrics.remainingDays == null ? '-' : '${metrics.remainingDays}',
        label: 'Days',
        infoTitle: 'Days',
        infoText: 'Days remaining until the deadline.',
      ),
      _GoalStateTile(
        icon: Icons.auto_graph_outlined,
        iconColor: const Color(0xFF10B981),
        value: '${_formatNumber(paceValue)} $unitLabel/day',
        label: 'Pace',
        infoTitle: 'Daily Pace',
        infoText: 'Average or required progress per day in the goal unit.',
      ),
      _GoalStateTile(
        icon: Icons.pie_chart_outline,
        iconColor: const Color(0xFF8B5CF6),
        value: '${metrics.progressPercent.toStringAsFixed(1)}%',
        label: 'Progress',
        infoTitle: 'Progress',
        infoText: 'Overall completion percentage of the goal.',
      ),
      _GoalStateTile(
        icon: Icons.hourglass_bottom_outlined,
        iconColor: const Color(0xFFEC4899),
        value: expectedRemainingDays,
        label: 'Est. days',
        infoTitle: 'Estimated Days Left',
        infoText: 'Estimated remaining days at the current pace.',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) => tiles[index],
    );
  }
}

class _GoalStateTile extends StatelessWidget {
  const _GoalStateTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.infoTitle,
    required this.infoText,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String infoTitle;
  final String infoText;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            _showStateInfoSheet(context, title: infoTitle, message: infoText),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end:
                      double.tryParse(
                        value
                            .replaceAll('%', '')
                            .replaceAll(RegExp(r'[^0-9.\-]'), ''),
                      ) ??
                      0,
                ),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOut,
                builder: (context, animatedValue, child) {
                  final display = value.contains('%')
                      ? '${animatedValue.toStringAsFixed(1)}%'
                      : (value == '-'
                            ? '-'
                            : _animatedDisplayTemplate(
                                original: value,
                                animatedValue: animatedValue,
                              ));
                  return Text(
                    display,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _animatedDisplayTemplate({
  required String original,
  required double animatedValue,
}) {
  final numeric = _formatNumber(animatedValue);
  if (original.contains('/day')) {
    final suffix = original.substring(original.indexOf(' ')).trim();
    return '$numeric $suffix';
  }
  return original == '-' ? '-' : numeric;
}

Future<void> _showStateInfoSheet(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    },
  );
}

class _GoalStateInfo {
  const _GoalStateInfo({
    required this.label,
    required this.description,
    required this.background,
    required this.foreground,
  });

  final String label;
  final String description;
  final Color background;
  final Color foreground;
}

_GoalStateInfo _goalStateInfo(GoalMetrics metrics) {
  if (metrics.remaining <= 0) {
    return const _GoalStateInfo(
      label: 'Completed',
      description: 'Great pace. This goal is already completed.',
      background: Color(0xFFDCFCE7),
      foreground: Color(0xFF166534),
    );
  }

  final requiredPerDay = metrics.requiredPerDay;
  if (requiredPerDay != null && metrics.averagePerDay < requiredPerDay) {
    return const _GoalStateInfo(
      label: 'Needs Pace',
      description: 'Current pace is below required daily pace.',
      background: Color(0xFFFEF3C7),
      foreground: Color(0xFF92400E),
    );
  }

  return const _GoalStateInfo(
    label: 'On Track',
    description: 'Current pace looks healthy for this goal.',
    background: Color(0xFFDBEAFE),
    foreground: Color(0xFF1E3A8A),
  );
}

class _GoalStatePill extends StatelessWidget {
  const _GoalStatePill({required this.info});

  final _GoalStateInfo info;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: info.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          info.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: info.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StreakInfo {
  const _StreakInfo({required this.current, required this.longest});

  final int current;
  final int longest;
}

_StreakInfo _calculateStreak(
  Map<DateTime, double> dailyProgress,
  DateTime nowUtc,
) {
  final normalized = <DateTime, double>{};
  dailyProgress.forEach((day, value) {
    final key = DateTime.utc(day.year, day.month, day.day);
    normalized[key] = value;
  });

  int current = 0;
  var cursor = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
  while ((normalized[cursor] ?? 0) > 0) {
    current++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  final activeDays =
      normalized.entries
          .where((entry) => entry.value > 0)
          .map((entry) => entry.key)
          .toList()
        ..sort();

  int longest = 0;
  int run = 0;
  DateTime? prev;
  for (final day in activeDays) {
    if (prev != null && day.difference(prev).inDays == 1) {
      run++;
    } else {
      run = 1;
    }
    if (run > longest) {
      longest = run;
    }
    prev = day;
  }

  return _StreakInfo(current: current, longest: longest);
}

class _SimpleGoalProgressCard extends StatelessWidget {
  const _SimpleGoalProgressCard({
    required this.goal,
    required this.onAddProgress,
  });

  final Goal goal;
  final VoidCallback onAddProgress;

  @override
  Widget build(BuildContext context) {
    final unit = _goalUnitLabel(goal);
    final remaining = (goal.targetValue - goal.completedValue)
        .clamp(0.0, double.infinity)
        .toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'You can update this goal directly without adding items.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Remaining: ${_formatNumber(remaining)} $unit',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onAddProgress,
              icon: const Icon(Icons.add),
              label: const Text('Add Progress'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalHeatmapCard extends StatelessWidget {
  const _GoalHeatmapCard({required this.dailyProgress});

  final Map<DateTime, double> dailyProgress;

  @override
  Widget build(BuildContext context) {
    final endDate = DateTime.now().toUtc();
    const weeks = 16;
    const daysPerWeek = 7;
    final startDate = DateTime.utc(
      endDate.year,
      endDate.month,
      endDate.day,
    ).subtract(const Duration(days: (weeks * daysPerWeek) - 1));

    final values = <double>[];
    final days = <DateTime>[];
    for (int i = 0; i < weeks * daysPerWeek; i++) {
      final day = startDate.add(Duration(days: i));
      final key = DateTime.utc(day.year, day.month, day.day);
      days.add(key);
      values.add(dailyProgress[key] ?? 0);
    }

    final weekStarts = List.generate(
      weeks,
      (index) => startDate.add(Duration(days: index * daysPerWeek)),
    );
    final streak = _calculateStreak(dailyProgress, endDate);

    final maxValue = values.fold<double>(0, (prev, v) => v > prev ? v : prev);

    Color colorFor(double value) {
      if (value <= 0 || maxValue <= 0) {
        return const Color(0xFFE5E7EB);
      }
      final ratio = (value / maxValue).clamp(0.0, 1.0);
      return Color.lerp(
        const Color(0xFFBFDBFE),
        const Color(0xFF1D4ED8),
        ratio,
      )!;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress Heatmap',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Your activity over the last 16 weeks',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricChip(
                    label: 'Current streak',
                    value:
                        '${streak.current} day${streak.current == 1 ? '' : 's'}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricChip(
                    label: 'Best streak',
                    value:
                        '${streak.longest} day${streak.longest == 1 ? '' : 's'}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 14,
              child: Row(
                children: List.generate(weeks, (weekIndex) {
                  final weekDate = weekStarts[weekIndex];
                  final showLabel =
                      weekIndex == 0 ||
                      weekDate.month != weekStarts[weekIndex - 1].month;
                  final label = showLabel
                      ? DateFormat('MMM').format(weekDate.toLocal())
                      : '';

                  return Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 2.0;
                final totalSpacing = (weeks - 1) * spacing;
                final cellSize = ((constraints.maxWidth - totalSpacing) / weeks)
                    .clamp(6.0, 14.0)
                    .toDouble();
                final height =
                    (daysPerWeek * cellSize) + ((daysPerWeek - 1) * spacing);

                return SizedBox(
                  height: height,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(weeks, (weekIndex) {
                      return Padding(
                        padding: EdgeInsets.only(
                          right: weekIndex == weeks - 1 ? 0 : spacing,
                        ),
                        child: Column(
                          children: List.generate(daysPerWeek, (dayIndex) {
                            final idx = weekIndex * daysPerWeek + dayIndex;
                            final value = values[idx];
                            final day = days[idx];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: dayIndex == daysPerWeek - 1
                                    ? 0
                                    : spacing,
                              ),
                              child: Tooltip(
                                message:
                                    '${DateFormat('dd MMM yyyy').format(day.toLocal())}: ${_formatNumber(value)}',
                                child: Container(
                                  width: cellSize,
                                  height: cellSize,
                                  decoration: BoxDecoration(
                                    color: colorFor(value),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Low', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(width: 6),
                ...List.generate(5, (index) {
                  final ratio = index / 4;
                  final value = maxValue * ratio;
                  return Container(
                    width: 16,
                    height: 10,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: colorFor(value),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
                const SizedBox(width: 2),
                Text('High', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodySmall,
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalItemCard extends StatelessWidget {
  const _GoalItemCard({
    required this.item,
    required this.unitLabel,
    required this.onQuickUpdate,
    required this.onEdit,
    required this.onDelete,
  });

  final GoalItem item;
  final String unitLabel;
  final VoidCallback onQuickUpdate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: onQuickUpdate,
                  icon: const Icon(Icons.trending_up),
                  tooltip: 'Quick update',
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit item',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete item',
                ),
              ],
            ),
            Text(
              '${_formatNumber(item.completedUnits)} / ${_formatNumber(item.totalUnits)} $unitLabel',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: item.progressPercent / 100),
            const SizedBox(height: 6),
            Text('Progress: ${item.progressPercent.toStringAsFixed(1)}%'),
            if (item.note?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(item.note!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalEmptyState extends StatelessWidget {
  const _GoalEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.track_changes, size: 52),
            const SizedBox(height: 12),
            Text('No goals yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Create your first goal to track progress, pace, and remaining work.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Goal'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalItemsEmptyState extends StatelessWidget {
  const _GoalItemsEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No items yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text('Add tracked items to update progress over time.'),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Add Item'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalFormDraft {
  const _GoalFormDraft({
    required this.title,
    required this.unitType,
    required this.customUnitLabel,
    required this.targetValue,
    required this.deadlineUtc,
    required this.isSimpleGoal,
  });

  final String title;
  final GoalUnitType unitType;
  final String? customUnitLabel;
  final double targetValue;
  final DateTime? deadlineUtc;
  final bool isSimpleGoal;
}

class _GoalItemFormDraft {
  const _GoalItemFormDraft({
    required this.name,
    required this.totalUnits,
    required this.completedUnits,
    required this.note,
  });

  final String name;
  final double totalUnits;
  final double completedUnits;
  final String? note;
}

Future<_GoalFormDraft?> _showGoalFormSheet({
  required BuildContext context,
  Goal? existing,
}) {
  return showModalBottomSheet<_GoalFormDraft>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return _GoalFormSheet(existing: existing);
    },
  );
}

Future<_GoalItemFormDraft?> _showGoalItemFormSheet({
  required BuildContext context,
  GoalItem? existing,
}) {
  return showModalBottomSheet<_GoalItemFormDraft>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return _GoalItemFormSheet(existing: existing);
    },
  );
}

Future<double?> _showProgressUpdateDialog({
  required BuildContext context,
  required GoalItem item,
}) {
  final controller = TextEditingController(
    text: item.completedUnits.toStringAsFixed(
      item.completedUnits % 1 == 0 ? 0 : 1,
    ),
  );

  return showDialog<double>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Update ${item.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Completed units',
            hintText: '0',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed == null || parsed < 0) {
                return;
              }
              Navigator.of(context).pop(parsed);
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

Future<double?> _showAddProgressDialog({required BuildContext context}) {
  final controller = TextEditingController();

  return showDialog<double>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Add Progress'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Progress amount',
            hintText: 'e.g. 500',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed == null || parsed <= 0) {
                return;
              }
              Navigator.of(context).pop(parsed);
            },
            child: const Text('Add'),
          ),
        ],
      );
    },
  );
}

class _GoalFormSheet extends StatefulWidget {
  const _GoalFormSheet({this.existing});

  final Goal? existing;

  @override
  State<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<_GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _targetController;
  late final TextEditingController _customUnitController;

  late GoalUnitType _unitType;
  late bool _isSimpleGoal;
  DateTime? _deadlineUtc;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _targetController = TextEditingController(
      text: existing == null ? '' : _formatNumber(existing.targetValue),
    );
    _customUnitController = TextEditingController(
      text: existing?.customUnitLabel ?? '',
    );
    _unitType = existing?.unitType ?? GoalUnitType.minutes;
    _isSimpleGoal = existing?.isSimpleGoal ?? false;
    _deadlineUtc = existing?.deadlineUtc;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _customUnitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, insets + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'Create Goal' : 'Edit Goal',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Goal title'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<GoalUnitType>(
                initialValue: _unitType,
                decoration: const InputDecoration(labelText: 'Unit type'),
                items: GoalUnitType.values.map((unit) {
                  return DropdownMenuItem<GoalUnitType>(
                    value: unit,
                    child: Text(unit.displayLabel),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _unitType = value;
                  });
                },
              ),
              const SizedBox(height: 6),
              Text(
                'Examples: Run Goal (5000 steps), Walk 120 kilometers, Burn 20000 calories.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_unitType == GoalUnitType.custom) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _customUnitController,
                  decoration: const InputDecoration(
                    labelText: 'Custom unit label',
                    hintText: 'e.g. chapters',
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextFormField(
                controller: _targetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Target value'),
                validator: (value) {
                  final parsed = double.tryParse((value ?? '').trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a number greater than zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Simple goal (no items)'),
                subtitle: const Text(
                  'Enable this for goals like running steps where you only add progress directly.',
                ),
                value: _isSimpleGoal,
                onChanged:
                    widget.existing != null &&
                        !_isSimpleGoal &&
                        widget.existing!.itemCount > 0
                    ? null
                    : (value) {
                        setState(() {
                          _isSimpleGoal = value;
                        });
                      },
              ),
              if (widget.existing != null &&
                  !_isSimpleGoal &&
                  widget.existing!.itemCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'This goal already has items. Remove items before switching to simple mode.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Deadline'),
                subtitle: Text(
                  _deadlineUtc == null
                      ? 'No deadline'
                      : DateFormat(
                          'dd MMM yyyy',
                        ).format(_deadlineUtc!.toLocal()),
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Pick date',
                      onPressed: _pickDeadline,
                      icon: const Icon(Icons.date_range_outlined),
                    ),
                    if (_deadlineUtc != null)
                      IconButton(
                        tooltip: 'Clear deadline',
                        onPressed: () {
                          setState(() {
                            _deadlineUtc = null;
                          });
                        },
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(
                    widget.existing == null ? 'Create Goal' : 'Save Goal',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initialDate = _deadlineUtc?.toLocal() ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _deadlineUtc = DateTime.utc(
        picked.year,
        picked.month,
        picked.day,
        23,
        59,
        59,
      );
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final targetValue = double.parse(_targetController.text.trim());
    final customUnit = _unitType == GoalUnitType.custom
        ? _customUnitController.text.trim()
        : null;

    Navigator.of(context).pop(
      _GoalFormDraft(
        title: _titleController.text.trim(),
        unitType: _unitType,
        customUnitLabel: customUnit == null || customUnit.isEmpty
            ? null
            : customUnit,
        targetValue: targetValue,
        deadlineUtc: _deadlineUtc,
        isSimpleGoal: _isSimpleGoal,
      ),
    );
  }
}

class _GoalItemFormSheet extends StatefulWidget {
  const _GoalItemFormSheet({this.existing});

  final GoalItem? existing;

  @override
  State<_GoalItemFormSheet> createState() => _GoalItemFormSheetState();
}

class _GoalItemFormSheetState extends State<_GoalItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _totalController;
  late final TextEditingController _completedController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _totalController = TextEditingController(
      text: existing == null ? '' : _formatNumber(existing.totalUnits),
    );
    _completedController = TextEditingController(
      text: existing == null ? '' : _formatNumber(existing.completedUnits),
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _totalController.dispose();
    _completedController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, insets + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'Add Item' : 'Edit Item',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Item name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _totalController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Total units'),
                validator: (value) {
                  final parsed = double.tryParse((value ?? '').trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Enter total units greater than zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _completedController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Completed units'),
                validator: (value) {
                  final parsed = double.tryParse((value ?? '').trim());
                  if (parsed == null || parsed < 0) {
                    return 'Enter a valid completed value';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Remark / note (optional)',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(
                    widget.existing == null ? 'Add Item' : 'Save Item',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final totalUnits = double.parse(_totalController.text.trim());
    final completedUnits = double.parse(_completedController.text.trim());

    Navigator.of(context).pop(
      _GoalItemFormDraft(
        name: _nameController.text.trim(),
        totalUnits: totalUnits,
        completedUnits: completedUnits,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }
}

String _goalUnitLabel(Goal goal) {
  if (goal.unitType == GoalUnitType.custom && goal.customUnitLabel != null) {
    return goal.customUnitLabel!;
  }
  return goal.unitType.displayLabel.toLowerCase();
}

String _formatNumber(double value) {
  if (value % 1 == 0) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}
