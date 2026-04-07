import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/core/providers/points_animation_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:coworkplace/features/goals/domain/goal.dart';
import 'package:coworkplace/features/goals/domain/goal_item.dart';
import 'package:coworkplace/features/goals/domain/goal_metrics.dart';
import 'package:coworkplace/features/goals/providers/goal_providers.dart';
import 'package:coworkplace/features/leaderboard/data/score_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class GoalDashboardScreen extends ConsumerStatefulWidget {
  const GoalDashboardScreen({super.key});

  @override
  ConsumerState<GoalDashboardScreen> createState() =>
      _GoalDashboardScreenState();
}

class _GoalDashboardScreenState extends ConsumerState<GoalDashboardScreen> {
  List<String>? _orderedIds;

  @override
  Widget build(BuildContext context) {
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
            onPressed: () => _onCreateGoal(context: context, userId: userId),
            icon: const Icon(Icons.add),
            label: const Text('New Goal'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: goalsAsync.when(
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
                          _onCreateGoal(context: context, userId: userId),
                    );
                  }

                  // Build ordered goals list.
                  final goalMap = {for (final g in goals) g.id: g};
                  final List<Goal> orderedGoals;
                  if (_orderedIds == null) {
                    orderedGoals = goals;
                  } else {
                    final result = _orderedIds!
                        .where(goalMap.containsKey)
                        .map((id) => goalMap[id]!)
                        .toList();
                    for (final g in goals) {
                      if (!_orderedIds!.contains(g.id)) result.add(g);
                    }
                    orderedGoals = result;
                  }

                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            children: [
                              _GoalOverviewCard(goals: goals),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverReorderableList(
                          itemCount: orderedGoals.length,
                          itemBuilder: (context, index) {
                            final goal = orderedGoals[index];
                            final metrics = GoalMetrics.compute(
                              targetValue: goal.targetValue,
                              completedValue: goal.completedValue,
                              createdAtUtc: goal.startDateUtc,
                              deadlineUtc: goal.deadlineUtc,
                            );
                            final isStale =
                                metrics.remaining > 0 &&
                                DateTime.now()
                                        .toUtc()
                                        .difference(goal.updatedAtUtc)
                                        .inHours >=
                                    24;
                            return ReorderableDelayedDragStartListener(
                              key: ValueKey(goal.id),
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _GoalCard(
                                  goal: goal,
                                  metrics: metrics,
                                  isStale: isStale,
                                  onViewDetails: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => GoalDetailScreen(
                                          userId: userId,
                                          goalId: goal.id,
                                        ),
                                      ),
                                    );
                                  },
                                  onAddItem: () => _onCreateItem(
                                    context: context,
                                    userId: userId,
                                    goalId: goal.id,
                                  ),
                                  onAddProgress: () => _onAddSimpleProgress(
                                    context: context,
                                    userId: userId,
                                    goalId: goal.id,
                                  ),
                                  onEdit: () => _onEditGoal(
                                    context: context,
                                    userId: userId,
                                    goal: goal,
                                  ),
                                  onShare: () =>
                                      _shareGoal(goal, metrics, context),
                                ),
                              ),
                            );
                          },
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              final ids = orderedGoals
                                  .map((g) => g.id)
                                  .toList();
                              ids.insert(newIndex, ids.removeAt(oldIndex));
                              _orderedIds = ids;
                            });
                          },
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        sliver: SliverToBoxAdapter(
                          child: _ArchivedGoalsSection(userId: userId),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onCreateGoal({
    required BuildContext context,
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
            startDateUtc: draft.startDateUtc,
            deadlineUtc: draft.deadlineUtc,
            isSimpleGoal: draft.isSimpleGoal,
          );
      // Award 1 pt for creating a goal, once per hour
      try {
        await ScoreService().awardGoalUpdate(userId: userId);
        if (context.mounted) {
          ref.read(pointsAnimationProvider.notifier).show('+1 pt');
        }
      } catch (_) {}
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
      startDateUtc: draft.startDateUtc,
      deadlineUtc: draft.deadlineUtc,
      clearCustomUnitLabel: draft.unitType != GoalUnitType.custom,
      clearDeadlineUtc: draft.deadlineUtc == null,
    );

    try {
      await ref
          .read(goalRepositoryProvider)
          .updateGoal(goal: updated, actorUserId: userId);
      // Award 1 pt for updating a goal, once per hour
      try {
        await ScoreService().awardGoalUpdate(userId: userId);
        if (context.mounted) {
          ref.read(pointsAnimationProvider.notifier).show('+1 pt');
        }
      } catch (_) {}
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

  void _shareGoal(Goal goal, GoalMetrics metrics, BuildContext context) {
    final unit = _goalUnitLabel(goal);
    final progress = metrics.progressPercent.toStringAsFixed(1);
    final deadline = goal.deadlineUtc != null
        ? ' · ${metrics.remainingDays} day${metrics.remainingDays == 1 ? '' : 's'} left'
        : '';
    final text =
        '🎯 I\'m working on: ${goal.title}\n'
        '$progress% done — ${_formatNumber(metrics.completed)} / ${_formatNumber(metrics.target)} $unit$deadline\n\n'
        'Join me on Coworkplace to track your goals and tasks together! 🚀';
    if (kIsWeb) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📋 Goal text copied to clipboard!')),
      );
      return;
    }
    SharePlus.instance.share(ShareParams(text: text));
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
          createdAtUtc: goal.startDateUtc,
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
                tooltip: goal.isArchived ? 'Unarchive goal' : 'Archive goal',
                onPressed: () => goal.isArchived
                    ? _unarchiveGoal(context, ref, goal.id)
                    : _archiveGoal(context, ref, goal.id),
                icon: Icon(
                  goal.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
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
                    _DeadlineWarningBanner(goal: goal, metrics: metrics),
                    if (metrics.remaining <= 0) ...[
                      const SizedBox(height: 8),
                      const _CompletionCelebrationCard(),
                    ],
                    _GoalSummaryCard(goal: goal, metrics: metrics),
                    const SizedBox(height: 12),
                    _SimpleGoalProgressCard(
                      goal: goal,
                      onAddProgress: () =>
                          _addSimpleProgress(context, ref, goal.id),
                    ),
                    const SizedBox(height: 12),
                    _GoalHeatmapCard(dailyProgress: dailyProgress),
                    const SizedBox(height: 12),
                    _GoalProgressLogCard(
                      dailyProgress: dailyProgress,
                      unitLabel: _goalUnitLabel(goal),
                    ),
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
                      _DeadlineWarningBanner(goal: goal, metrics: metrics),
                      if (metrics.remaining <= 0) ...[
                        const SizedBox(height: 8),
                        const _CompletionCelebrationCard(),
                      ],
                      _GoalSummaryCard(goal: goal, metrics: metrics),
                      const SizedBox(height: 12),
                      _GoalHeatmapCard(dailyProgress: dailyProgress),
                      const SizedBox(height: 12),
                      _GoalProgressLogCard(
                        dailyProgress: dailyProgress,
                        unitLabel: _goalUnitLabel(goal),
                      ),
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
      startDateUtc: draft.startDateUtc,
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

  Future<void> _archiveGoal(
    BuildContext context,
    WidgetRef ref,
    String goalId,
  ) async {
    try {
      await ref
          .read(goalRepositoryProvider)
          .archiveGoal(userId: userId, goalId: goalId);
      if (!context.mounted) return;
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Goal archived')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not archive goal: $e')));
    }
  }

  Future<void> _unarchiveGoal(
    BuildContext context,
    WidgetRef ref,
    String goalId,
  ) async {
    try {
      await ref
          .read(goalRepositoryProvider)
          .unarchiveGoal(userId: userId, goalId: goalId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Goal unarchived')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not unarchive goal: $e')));
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
    required this.onShare,
    this.isStale = false,
  });

  final Goal goal;
  final GoalMetrics metrics;
  final VoidCallback onViewDetails;
  final VoidCallback onAddItem;
  final VoidCallback onAddProgress;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final bool isStale;

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
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  IconButton(
                    onPressed: onShare,
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Share goal',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 2, right: 2),
                    child: Icon(
                      Icons.drag_handle,
                      size: 18,
                      color: Colors.grey,
                    ),
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
              _GoalProgressBar(
                percent: metrics.progressPercent,
                color: _goalBarColor(goal.id),
              ),
              const SizedBox(height: 10),
              _GoalMetricsWrap(metrics: metrics, unitLabel: unit),
              if (isStale) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      size: 14,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'No progress logged in 24+ hours',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (goal.isSimpleGoal)
                      OutlinedButton.icon(
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
            _GoalProgressBar(
              percent: metrics.progressPercent,
              color: _goalBarColor(goal.id),
            ),
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
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
            ],
          ),
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
            TextButton.icon(
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
            _GoalProgressBar(percent: item.progressPercent),
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
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Icon(Icons.track_changes, size: 56, color: cs.primary),
          const SizedBox(height: 12),
          Text('No goals yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Set a goal, break it into steps, and track your progress every day.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          // How-it-works guide
          _HowItWorksGuide(),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create Goal'),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksGuide extends StatelessWidget {
  const _HowItWorksGuide();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final steps = [
      (
        icon: Icons.add_circle_outline,
        title: 'Create a goal',
        desc:
            'Pick a target — like "Run 50 km" or "Read 6 books". '
            'Set a deadline for pacing guidance.',
      ),
      (
        icon: Icons.playlist_add_check,
        title: 'Add items (optional)',
        desc:
            'Break the goal into trackable items, e.g. specific books or '
            'workout sessions.',
      ),
      (
        icon: Icons.trending_up,
        title: 'Log progress',
        desc:
            'Mark items complete or tap "Add Progress" to log numbers. '
            'Watch your progress bar grow.',
      ),
      (
        icon: Icons.people_alt_outlined,
        title: 'Visible to friends',
        desc:
            'Your progress appears on the home feed so friends can cheer '
            'you on.',
      ),
    ];

    return Card(
      color: cs.surfaceContainerHighest,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How it works', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            for (var i = 0; i < steps.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(steps[i].icon, size: 16, color: cs.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                steps[i].title,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          steps[i].desc,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (i < steps.length - 1) const SizedBox(height: 14),
            ],
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
    required this.startDateUtc,
    required this.deadlineUtc,
    required this.isSimpleGoal,
  });

  final String title;
  final GoalUnitType unitType;
  final String? customUnitLabel;
  final double targetValue;
  final DateTime startDateUtc;
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

// ── Sample Goal Templates ─────────────────────────────────────────────────────

class _SampleGoalTemplate {
  const _SampleGoalTemplate({
    required this.title,
    required this.unitType,
    required this.target,
    this.isSimpleGoal = true,
    this.icon = Icons.flag_rounded,
  });

  final String title;
  final GoalUnitType unitType;
  final double target;
  final bool isSimpleGoal;
  final IconData icon;
}

const _kSampleGoalTemplates = <_SampleGoalTemplate>[
  _SampleGoalTemplate(
    title: 'Running',
    unitType: GoalUnitType.kilometers,
    target: 50,
    icon: Icons.directions_run,
  ),
  _SampleGoalTemplate(
    title: 'Workout',
    unitType: GoalUnitType.workouts,
    target: 30,
    icon: Icons.fitness_center,
  ),
  _SampleGoalTemplate(
    title: 'Reading Books',
    unitType: GoalUnitType.books,
    target: 6,
    isSimpleGoal: false,
    icon: Icons.menu_book,
  ),
  _SampleGoalTemplate(
    title: 'Walking Steps',
    unitType: GoalUnitType.steps,
    target: 300000,
    icon: Icons.directions_walk,
  ),
  _SampleGoalTemplate(
    title: 'Meditation',
    unitType: GoalUnitType.min,
    target: 1800,
    icon: Icons.self_improvement,
  ),
  _SampleGoalTemplate(
    title: 'Cycling',
    unitType: GoalUnitType.kilometers,
    target: 100,
    icon: Icons.pedal_bike,
  ),
  _SampleGoalTemplate(
    title: 'Calories Burned',
    unitType: GoalUnitType.calories,
    target: 30000,
    icon: Icons.local_fire_department,
  ),
];

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
  late DateTime _startDateUtc;
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
    _unitType = existing?.unitType ?? GoalUnitType.min;
    _isSimpleGoal = existing?.isSimpleGoal ?? false;
    _startDateUtc = existing?.startDateUtc ?? DateTime.now().toUtc();
    _deadlineUtc = existing?.deadlineUtc;
    _targetController.addListener(_onTargetChanged);
  }

  void _onTargetChanged() => setState(() {});

  void _applyTemplate(_SampleGoalTemplate t) {
    setState(() {
      _titleController.text = t.title;
      _unitType = t.unitType;
      _isSimpleGoal = t.isSimpleGoal;
      _targetController.text = t.target % 1 == 0
          ? t.target.toInt().toString()
          : t.target.toString();
    });
  }

  @override
  void dispose() {
    _targetController.removeListener(_onTargetChanged);
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
              if (widget.existing == null) ...[
                const SizedBox(height: 10),
                Text(
                  'Quick templates',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _kSampleGoalTemplates.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final t = _kSampleGoalTemplates[i];
                      return ActionChip(
                        avatar: Icon(t.icon, size: 16),
                        label: Text(t.title),
                        onPressed: () => _applyTemplate(t),
                        visualDensity: VisualDensity.compact,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ] else
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
                title: const Text('Start date'),
                subtitle: Text(
                  DateFormat('dd MMM yyyy').format(_startDateUtc.toLocal()),
                ),
                trailing: IconButton(
                  tooltip: 'Pick start date',
                  onPressed: _pickStartDate,
                  icon: const Icon(Icons.date_range_outlined),
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
              _buildPacePreview(),
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

  Widget _buildPacePreview() {
    final target = double.tryParse(_targetController.text.trim());
    if (target == null || target <= 0 || _deadlineUtc == null) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now().toUtc();
    final daysRemaining = _deadlineUtc!.difference(now).inDays + 1;
    if (daysRemaining <= 0) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: Color(0xFFEF4444),
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Deadline is in the past.',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    final pace = target / daysRemaining;
    final unitLabel = _unitType == GoalUnitType.custom
        ? (_customUnitController.text.trim().isEmpty
              ? 'units'
              : _customUnitController.text.trim())
        : _unitType.displayLabel.toLowerCase();
    final isAggressive = _isPaceAggressive(pace, _unitType);
    final color = isAggressive
        ? const Color(0xFFF59E0B)
        : const Color(0xFF22C55E);
    final icon = isAggressive
        ? Icons.warning_amber_rounded
        : Icons.check_circle_outline;
    final msg = isAggressive
        ? 'Needs ${_formatNumber(pace)} $unitLabel/day — consider extending the deadline.'
        : 'Required pace: ${_formatNumber(pace)} $unitLabel/day';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(msg, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  static bool _isPaceAggressive(double pace, GoalUnitType unit) {
    return switch (unit) {
      GoalUnitType.hours => pace > 6,
      GoalUnitType.min => pace > 360,
      GoalUnitType.kilometers => pace > 20,
      GoalUnitType.miles => pace > 12,
      GoalUnitType.steps => pace > 20000,
      GoalUnitType.calories => pace > 1500,
      GoalUnitType.workouts => pace > 2,
      GoalUnitType.books => pace > 1,
      _ => false,
    };
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final initialDate = _startDateUtc.toLocal();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _startDateUtc = DateTime.utc(picked.year, picked.month, picked.day);
    });
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
        startDateUtc: _startDateUtc,
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

// Per-goal accent colors — consistent across sessions (hash-based, not progress-based).
const _kGoalPalette = [
  Color(0xFF0EA5E9), // sky
  Color(0xFF8B5CF6), // violet
  Color(0xFF10B981), // emerald
  Color(0xFFF43F5E), // rose
  Color(0xFF06B6D4), // cyan
  Color(0xFFF97316), // orange
  Color(0xFF6366F1), // indigo
  Color(0xFFEC4899), // pink
];

Color _goalBarColor(String goalId) =>
    _kGoalPalette[goalId.hashCode.abs() % _kGoalPalette.length];

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

// ── Deadline Warning Banner ───────────────────────────────────────────────────

class _DeadlineWarningBanner extends StatelessWidget {
  const _DeadlineWarningBanner({required this.goal, required this.metrics});

  final Goal goal;
  final GoalMetrics metrics;

  @override
  Widget build(BuildContext context) {
    // Only show when there is a deadline and the goal is not completed.
    if (goal.deadlineUtc == null || metrics.remaining <= 0) {
      return const SizedBox.shrink();
    }

    final days = metrics.remainingDays ?? 0;
    final isPaceBehind =
        metrics.requiredPerDay != null &&
        metrics.averagePerDay < metrics.requiredPerDay!;
    final isCloseToDue = days <= 7;

    if (!isPaceBehind && !isCloseToDue) {
      return const SizedBox.shrink();
    }

    final String message;
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData icon;

    if (days == 0) {
      message = 'Deadline is today! Push hard to finish.';
      bgColor = const Color(0xFFFEE2E2);
      borderColor = const Color(0xFFEF4444);
      textColor = const Color(0xFF991B1B);
      icon = Icons.warning_amber_rounded;
    } else if (days <= 3 || (isPaceBehind && days <= 7)) {
      message = days <= 3
          ? '$days day${days == 1 ? '' : 's'} left — you\'re running out of time!'
          : '$days days left and current pace is below target.';
      bgColor = const Color(0xFFFEE2E2);
      borderColor = const Color(0xFFEF4444);
      textColor = const Color(0xFF991B1B);
      icon = Icons.warning_amber_rounded;
    } else {
      message = '$days days to deadline — pace needs to pick up.';
      bgColor = const Color(0xFFFEF3C7);
      borderColor = const Color(0xFFF59E0B);
      textColor = const Color(0xFF92400E);
      icon = Icons.access_time_outlined;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Goal Progress Bar ─────────────────────────────────────────────────────────

class _GoalProgressBar extends StatelessWidget {
  const _GoalProgressBar({required this.percent, this.color});

  final double percent; // 0.0 – 100.0
  /// Optional accent color; falls back to progress-threshold palette.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0.0, 100.0);
    final fillFraction = clamped / 100;

    final fillColor =
        color ??
        (clamped >= 75
            ? const Color(0xFF22C55E)
            : clamped >= 35
            ? const Color(0xFF3B82F6)
            : const Color(0xFFF59E0B));

    // Label is right-aligned using fill color.
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 26,
        child: Row(
          children: [
            Flexible(
              child: Stack(
                children: [
                  Container(color: fillColor.withAlpha(30)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fillFraction,
                    child: Container(
                      decoration: BoxDecoration(color: fillColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${clamped.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: fillColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Goal Completion Celebration ────────────────────────────────────────────────

class _CompletionCelebrationCard extends StatefulWidget {
  const _CompletionCelebrationCard();

  @override
  State<_CompletionCelebrationCard> createState() =>
      _CompletionCelebrationCardState();
}

class _CompletionCelebrationCardState extends State<_CompletionCelebrationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    // Stop after two cycles.
    Future.delayed(const Duration(milliseconds: 3400), () {
      if (mounted) _ctrl.stop();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF22C55E).withAlpha(80)),
        ),
        child: SizedBox(
          height: 72,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(
                    painter: _SparklesPainter(progress: _ctrl.value),
                  ),
                ),
              ),
              child!,
            ],
          ),
        ),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration, color: Color(0xFF22C55E), size: 26),
            const SizedBox(width: 8),
            Text(
              'Goal Complete!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF166534),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklesPainter extends CustomPainter {
  const _SparklesPainter({required this.progress});

  final double progress;

  static const _bxs = [
    0.08,
    0.18,
    0.32,
    0.50,
    0.62,
    0.74,
    0.85,
    0.92,
    0.44,
    0.14,
    0.58,
    0.28,
  ];
  static const _bys = [
    0.30,
    0.75,
    0.20,
    0.85,
    0.15,
    0.72,
    0.38,
    0.18,
    0.55,
    0.90,
    0.65,
    0.50,
  ];
  static const _cis = [0, 1, 2, 3, 4, 0, 1, 2, 3, 4, 0, 1];
  static const _colors = [
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _bxs.length; i++) {
      final phase = math.sin(progress * math.pi * 2 + _cis[i] * 0.8);
      final opacity = ((phase + 1) / 2).clamp(0.15, 1.0);
      final radius = (3.0 + (_cis[i] % 3) + phase * 1.5).abs();
      canvas.drawCircle(
        Offset(_bxs[i] * size.width, _bys[i] * size.height),
        radius,
        Paint()..color = _colors[_cis[i]].withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_SparklesPainter old) => old.progress != progress;
}

// ── Goal Progress Log Card ───────────────────────────────────────────────────

class _GoalProgressLogCard extends StatelessWidget {
  const _GoalProgressLogCard({
    required this.dailyProgress,
    required this.unitLabel,
  });

  final Map<DateTime, double> dailyProgress;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    if (dailyProgress.isEmpty) return const SizedBox.shrink();

    final sortedEntries = dailyProgress.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress Log',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (final entry in sortedEntries.take(30)) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(entry.key.toLocal()),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Text(
                      '+${_formatNumber(entry.value)} $unitLabel',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (entry != sortedEntries.take(30).last)
                const Divider(height: 1),
            ],
            if (dailyProgress.length > 30)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Showing most recent 30 entries.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Goal Overview Card ────────────────────────────────────────────────────────

class _GoalOverviewCard extends StatelessWidget {
  const _GoalOverviewCard({required this.goals});

  final List<Goal> goals;

  @override
  Widget build(BuildContext context) {
    int doneCount = 0;
    int onTrackCount = 0;
    int needsPaceCount = 0;

    for (final goal in goals) {
      final metrics = GoalMetrics.compute(
        targetValue: goal.targetValue,
        completedValue: goal.completedValue,
        createdAtUtc: goal.startDateUtc,
        deadlineUtc: goal.deadlineUtc,
      );
      final state = _goalStateInfo(metrics);
      if (state.label == 'Completed') {
        doneCount++;
      } else if (state.label == 'Needs Pace') {
        needsPaceCount++;
      } else {
        onTrackCount++;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.track_changes, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Goal Overview',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${goals.length} active',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _OverviewPill(
                  value: onTrackCount,
                  label: 'On Track',
                  color: const Color(0xFF3B82F6),
                ),
                const SizedBox(width: 8),
                _OverviewPill(
                  value: needsPaceCount,
                  label: 'Needs Pace',
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                _OverviewPill(
                  value: doneCount,
                  label: 'Done',
                  color: const Color(0xFF22C55E),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewPill extends StatelessWidget {
  const _OverviewPill({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Archived Goals Section ────────────────────────────────────────────────────

class _ArchivedGoalsSection extends ConsumerWidget {
  const _ArchivedGoalsSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedUserGoalsProvider);

    return archivedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, st) => const SizedBox.shrink(),
      data: (archived) {
        if (archived.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.archive_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Archived (${archived.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            ...archived.map(
              (goal) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.archive, size: 20),
                title: Text(goal.title),
                subtitle: Text(
                  '${_formatNumber(goal.completedValue)} / ${_formatNumber(goal.targetValue)} ${_goalUnitLabel(goal)}',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        GoalDetailScreen(userId: userId, goalId: goal.id),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
