import 'package:coworkplace/core/time/day_start_time_service.dart';
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
