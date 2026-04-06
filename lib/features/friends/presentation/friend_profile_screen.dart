import 'package:coworkplace/core/time/day_start_time_service.dart';
import 'package:coworkplace/features/goals/domain/goal.dart';
import 'package:coworkplace/features/goals/domain/goal_metrics.dart';
import 'package:coworkplace/features/goals/providers/goal_providers.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';
import 'package:coworkplace/features/tasks/domain/task.dart';
import 'package:coworkplace/features/tasks/domain/task_completion.dart';
import 'package:coworkplace/features/tasks/providers/task_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:coworkplace/features/profile/presentation/task_history_screen.dart';
import 'package:coworkplace/core/widgets/task_vote_button.dart';
import 'package:coworkplace/core/widgets/user_avatar.dart';

class FriendProfileScreen extends ConsumerWidget {
  const FriendProfileScreen({
    super.key,
    required this.profile,
    this.friendSince,
  });

  final UserProfile profile;
  final DateTime? friendSince;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskRepository = ref.watch(taskRepositoryProvider);
    final completionRepository = ref.watch(completionRepositoryProvider);
    final localDateKey = _safeLocalDateKey(profile);

    return Scaffold(
      appBar: AppBar(
        title: Text('${profile.displayName} Profile'),
        actions: [
          StreamBuilder<List<Task>>(
            stream: taskRepository.watchUserTasks(profile.id),
            builder: (context, taskSnapshot) {
              if (taskSnapshot.hasError) {
                return const SizedBox.shrink();
              }
              if (!taskSnapshot.hasData) {
                return const SizedBox.shrink();
              }
              final activeTasks = taskSnapshot.data!
                  .where((t) => t.active)
                  .toList();
              if (activeTasks.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'History',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskHistoryScreen(
                        userId: profile.id,
                        timezone: profile.timezone,
                        dayStartHour: profile.dayStartHour,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Task>>(
        stream: taskRepository.watchUserTasks(profile.id),
        builder: (context, taskSnapshot) {
          if (taskSnapshot.hasError) {
            return Center(
              child: Text('Failed to load tasks: ${taskSnapshot.error}'),
            );
          }

          if (!taskSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final activeTasks = taskSnapshot.data!
              .where((task) => task.active)
              .toList();

          return StreamBuilder<List<TaskCompletion>>(
            stream: completionRepository.watchUserCompletionsForDate(
              userId: profile.id,
              localDateKey: localDateKey,
            ),
            builder: (context, completionSnapshot) {
              final completions =
                  completionSnapshot.data ?? const <TaskCompletion>[];
              final completionByTaskId = {
                for (final item in completions) item.taskId: item,
              };

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar(profile: profile, radius: 20),
                    title: Text(profile.displayName),
                    subtitle: Text('@${profile.username}'),
                  ),
                  Text(
                    'Current mode: ${profile.currentMode?.label ?? 'No mode set'}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Timezone: ${profile.timezone} • Owner day: $localDateKey',
                  ),
                  if (friendSince != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Friends since: ${DateFormat('yyyy-MM-dd HH:mm').format(friendSince!.toLocal())}',
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (activeTasks.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.inbox_outlined),
                        title: Text('No active tasks'),
                        subtitle: Text(
                          'This friend has no active tasks right now.',
                        ),
                      ),
                    )
                  else
                    ...activeTasks.map((task) {
                      final completion = completionByTaskId[task.id];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            completion?.status == CompletionStatus.done
                                ? Icons.check_circle
                                : completion?.status == CompletionStatus.skipped
                                ? Icons.skip_next
                                : Icons.radio_button_unchecked,
                          ),
                          title: Text(task.title),
                          subtitle: Text(_taskSubtitle(task, completion)),
                          trailing: TaskVoteButton(
                            ownerId: profile.id,
                            taskId: task.id,
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 12),
                  _FriendGoalsSection(friendId: profile.id),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _safeLocalDateKey(UserProfile profile) {
    try {
      return DayStartTimeService().localDateKeyForUtcInstant(
        instantUtc: DateTime.now().toUtc(),
        timezone: profile.timezone,
        dayStartHour: profile.dayStartHour,
      );
    } catch (_) {
      return DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
    }
  }

  String _taskSubtitle(Task task, TaskCompletion? completion) {
    final statusText = completion == null
        ? 'Pending'
        : completion.status == CompletionStatus.done
        ? 'Done'
        : 'Skipped';
    final typeText = task.type == TaskType.daily ? 'Daily' : 'One-time';
    final goalText = task.goalCount != null && task.goalUnit != null
        ? ' • ${task.goalCount} ${task.goalUnit}'
        : '';
    return '$typeText$goalText • $statusText';
  }
}

// ── Friend Goals (read-only) ─────────────────────────────────────────────────

class _FriendGoalsSection extends ConsumerWidget {
  const _FriendGoalsSection({required this.friendId});

  final String friendId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(friendGoalsProvider(friendId));

    return goalsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (goals) {
        if (goals.isEmpty) return const SizedBox.shrink();

        final colorScheme = Theme.of(context).colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Goals',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ...goals.map(
              (goal) => _FriendGoalCard(goal: goal, colorScheme: colorScheme),
            ),
          ],
        );
      },
    );
  }
}

class _FriendGoalCard extends StatelessWidget {
  const _FriendGoalCard({required this.goal, required this.colorScheme});

  final Goal goal;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final metrics = GoalMetrics.compute(
      targetValue: goal.targetValue,
      completedValue: goal.completedValue,
      createdAtUtc: goal.startDateUtc,
      deadlineUtc: goal.deadlineUtc,
    );

    final pct = metrics.progressPercent;
    final isDone = metrics.remaining <= 0;

    Color barColor;
    String stateLabel;
    Color stateColor;

    if (isDone) {
      barColor = Colors.green;
      stateLabel = 'Done';
      stateColor = Colors.green;
    } else if (metrics.requiredPerDay != null &&
        metrics.averagePerDay < metrics.requiredPerDay!) {
      barColor = const Color(0xFFFFA726); // amber
      stateLabel = 'Needs Pace';
      stateColor = Colors.orange;
    } else {
      barColor = colorScheme.primary;
      stateLabel = 'On Track';
      stateColor = Colors.blue;
    }

    final unitLabel =
        goal.unitType == GoalUnitType.custom && goal.customUnitLabel != null
        ? goal.customUnitLabel!
        : goal.unitType.displayLabel.toLowerCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    stateLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: stateColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 22,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: barColor.withValues(alpha: 0.18)),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (pct / 100).clamp(0.0, 1.0),
                      child: ColoredBox(color: barColor),
                    ),
                    Center(
                      child: Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: pct >= 50
                              ? Colors.white
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${goal.completedValue.toStringAsFixed(goal.completedValue.truncateToDouble() == goal.completedValue ? 0 : 1)}'
              ' / '
              '${goal.targetValue.toStringAsFixed(goal.targetValue.truncateToDouble() == goal.targetValue ? 0 : 1)}'
              ' $unitLabel',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
