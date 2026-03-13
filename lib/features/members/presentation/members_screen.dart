import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/core/time/day_start_time_service.dart';
import 'package:coworkplace/features/groups/domain/group.dart';
import 'package:coworkplace/features/groups/providers/group_providers.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:coworkplace/features/tasks/domain/task.dart';
import 'package:coworkplace/features/tasks/domain/task_completion.dart';
import 'package:coworkplace/features/tasks/providers/task_providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  static const _timeService = DayStartTimeService();

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(appSessionProvider);

    return sessionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Session error: $error')),
      data: (session) {
        final profile = session.profile;
        final activeGroupId = profile?.activeGroupId;
        if (session.userId == null || profile == null || activeGroupId == null) {
          return const Center(child: Text('Set up profile and group first.'));
        }

        if (Firebase.apps.isEmpty) {
          return const _MembersNoDataRuntimeScreen();
        }

        final groupRepository = ref.watch(groupRepositoryProvider);
        final profileRepository = ref.watch(userProfileRepositoryProvider);

        return StreamBuilder<Group?>(
          stream: groupRepository.watchById(activeGroupId),
          builder: (context, groupSnapshot) {
            if (groupSnapshot.hasError) {
              return Center(child: Text('Failed to load group: ${groupSnapshot.error}'));
            }

            final group = groupSnapshot.data;
            if (group == null) {
              return const Center(child: Text('Group not found.'));
            }

            return StreamBuilder<List<UserProfile>>(
              stream: profileRepository.watchByGroupId(activeGroupId),
              builder: (context, membersSnapshot) {
                if (membersSnapshot.hasError) {
                  return Center(
                    child: Text('Failed to load members: ${membersSnapshot.error}'),
                  );
                }

                if (!membersSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final members = membersSnapshot.data!
                    .where((member) => group.memberIds.contains(member.id))
                    .toList()
                  ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.group),
                        title: Text(group.name),
                        subtitle: Text('Invite code: ${group.code}'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (members.isEmpty)
                      const Card(
                        child: ListTile(
                          leading: Icon(Icons.person_outline),
                          title: Text('No members found'),
                          subtitle: Text('Ask friends to join with your invite code.'),
                        ),
                      )
                    else
                      ...members.map((member) {
                        final isYou = member.id == session.userId;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(member.displayName.isEmpty ? '?' : member.displayName[0].toUpperCase()),
                            ),
                            title: Text(isYou ? '${member.displayName} (You)' : member.displayName),
                            subtitle: Text(
                              '${member.timezone} • ${member.currentMode?.label ?? 'No mode set'}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              _openMemberTaskView(
                                member: member,
                                activeGroupId: activeGroupId,
                              );
                            },
                          ),
                        );
                      }),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _openMemberTaskView({required UserProfile member, required String activeGroupId}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final taskRepository = ref.read(taskRepositoryProvider);
        final completionRepository = ref.read(completionRepositoryProvider);

        final localDateKey = _safeLocalDateKey(
          timezone: member.timezone,
          dayStartHour: member.dayStartHour,
        );

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return StreamBuilder<List<Task>>(
              stream: taskRepository.watchGroupTasks(activeGroupId),
              builder: (context, taskSnapshot) {
                if (taskSnapshot.hasError) {
                  return Center(child: Text('Failed to load tasks: ${taskSnapshot.error}'));
                }

                if (!taskSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final memberTasks = taskSnapshot.data!
                    .where((task) => task.ownerId == member.id && task.active)
                    .toList();

                return StreamBuilder<List<TaskCompletion>>(
                  stream: completionRepository.watchUserCompletionsForDate(
                    groupId: activeGroupId,
                    userId: member.id,
                    localDateKey: localDateKey,
                  ),
                  builder: (context, completionSnapshot) {
                    if (completionSnapshot.hasError) {
                      return Center(
                        child: Text('Failed to load completion status: ${completionSnapshot.error}'),
                      );
                    }

                    final completionByTaskId = {
                      for (final completion in completionSnapshot.data ?? const <TaskCompletion>[])
                        completion.taskId: completion,
                    };

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.visibility_outlined),
                          title: Text('${member.displayName} - Read-only tasks'),
                          subtitle: Text(
                            'Owner day: $localDateKey (${member.timezone}, day starts at ${member.dayStartHour}:00)',
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (memberTasks.isEmpty)
                          const Card(
                            child: ListTile(
                              leading: Icon(Icons.inbox_outlined),
                              title: Text('No active tasks'),
                              subtitle: Text('This member has no active tasks right now.'),
                            ),
                          )
                        else
                          ...memberTasks.map((task) {
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
                                subtitle: Text(_taskSubtitleForMember(task: task, member: member, completion: completion)),
                              ),
                            );
                          }),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String _safeLocalDateKey({required String timezone, required int dayStartHour}) {
    try {
      return _timeService.localDateKeyForUtcInstant(
        instantUtc: DateTime.now().toUtc(),
        timezone: timezone,
        dayStartHour: dayStartHour,
      );
    } catch (_) {
      return DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
    }
  }

  String _taskSubtitleForMember({
    required Task task,
    required UserProfile member,
    required TaskCompletion? completion,
  }) {
    final typeText = task.type == TaskType.daily ? 'Daily' : 'One-time';

    String scheduleText = 'No time set';
    if (task.type == TaskType.daily && task.localTimeMinutes != null) {
      scheduleText = _formatMinutes(task.localTimeMinutes!);
    }

    if (task.type == TaskType.oneTime && task.scheduledTimeUtc != null) {
      try {
        final location = tz.getLocation(member.timezone);
        final local = tz.TZDateTime.from(task.scheduledTimeUtc!, location);
        scheduleText = DateFormat('yyyy-MM-dd HH:mm').format(local);
      } catch (_) {
        scheduleText = DateFormat('yyyy-MM-dd HH:mm').format(task.scheduledTimeUtc!.toLocal());
      }
    }

    final goalText =
        task.goalCount != null && task.goalUnit != null
            ? ' • Goal: ${_formatGoalCount(task.goalCount!)} ${task.goalUnit}'
            : '';

    final statusText = completion == null
        ? 'Pending'
        : completion.status == CompletionStatus.done
        ? 'Done'
        : 'Skipped';

    return '$typeText • $scheduleText$goalText • $statusText';
  }

  String _formatGoalCount(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  String _formatMinutes(int totalMinutes) {
    final hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;
    final dt = DateTime(2000, 1, 1, hour, minute);
    return DateFormat('hh:mm a').format(dt);
  }
}

class _MembersNoDataRuntimeScreen extends StatelessWidget {
  const _MembersNoDataRuntimeScreen();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: ListTile(
            leading: Icon(Icons.group),
            title: Text('Members'),
            subtitle: Text('Member data becomes available after Firebase is initialized.'),
          ),
        ),
      ],
    );
  }
}
