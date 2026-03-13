import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/core/time/day_start_time_service.dart';
import 'package:coworkplace/features/tasks/domain/task.dart';
import 'package:coworkplace/features/tasks/domain/task_completion.dart';
import 'package:coworkplace/features/tasks/providers/task_providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _timeService = DayStartTimeService();
  static const _goalUnitOptions = [
    'ml',
    'steps',
    'km',
    'min',
    'hour',
    'reps',
    'pages',
    'other',
  ];

  _TaskFilter _filter = _TaskFilter.all;

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(appSessionProvider);

    return sessionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Session error: $error')),
      data: (session) {
        final profile = session.profile;
        final userId = session.userId;
        if (profile == null || userId == null || profile.activeGroupId == null) {
          return const Center(child: Text('Set up profile and group first.'));
        }

        if (Firebase.apps.isEmpty) {
          return const Center(child: Text('Task data becomes available after Firebase is initialized.'));
        }

        final activeGroupId = profile.activeGroupId!;
        final localDateKey = _safeLocalDateKey(
          timezone: profile.timezone,
          dayStartHour: profile.dayStartHour,
        );

        final taskRepository = ref.watch(taskRepositoryProvider);
        final completionRepository = ref.watch(completionRepositoryProvider);

        return StreamBuilder<List<Task>>(
          stream: taskRepository.watchGroupTasks(activeGroupId),
          builder: (context, taskSnapshot) {
            if (taskSnapshot.hasError) {
              return Center(child: Text('Failed to load tasks: ${taskSnapshot.error}'));
            }

            if (!taskSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allTasks = taskSnapshot.data!;
            final myTasks = allTasks
                .where((task) => task.ownerId == userId && task.active)
                .toList();
            final visibleTasks = _applyFilter(myTasks, _filter);

            return StreamBuilder<List<TaskCompletion>>(
              stream: completionRepository.watchUserCompletionsForDate(
                groupId: activeGroupId,
                userId: userId,
                localDateKey: localDateKey,
              ),
              builder: (context, completionSnapshot) {
                if (completionSnapshot.hasError) {
                  return Center(
                    child: Text('Failed to load completion status: ${completionSnapshot.error}'),
                  );
                }

                final completions = completionSnapshot.data ?? const <TaskCompletion>[];
                final completionByTaskId = {
                  for (final completion in completions) completion.taskId: completion,
                };

                return Scaffold(
                  floatingActionButton: FloatingActionButton.extended(
                    onPressed: () => _createTask(
                      groupId: activeGroupId,
                      ownerId: userId,
                      timezone: profile.timezone,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Task'),
                  ),
                  body: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final filter in _TaskFilter.values)
                            ChoiceChip(
                              label: Text(filter.label),
                              selected: _filter == filter,
                              onSelected: (_) {
                                setState(() {
                                  _filter = filter;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (visibleTasks.isEmpty)
                        const Card(
                          child: ListTile(
                            leading: Icon(Icons.inbox_outlined),
                            title: Text('No tasks yet'),
                            subtitle: Text('Tap Add Task to create your first task.'),
                          ),
                        )
                      else
                        ...visibleTasks.map((task) {
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
                              subtitle: Text(
                                _taskSubtitle(task: task, completion: completion),
                              ),
                              trailing: PopupMenuButton<_TaskAction>(
                                onSelected: (action) {
                                  _handleTaskAction(
                                    action: action,
                                    task: task,
                                    groupId: activeGroupId,
                                    userId: userId,
                                    localDateKey: localDateKey,
                                    timezone: profile.timezone,
                                  );
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: _TaskAction.done,
                                    child: Text('Mark done'),
                                  ),
                                  PopupMenuItem(
                                    value: _TaskAction.skipped,
                                    child: Text('Mark skipped'),
                                  ),
                                  PopupMenuItem(
                                    value: _TaskAction.edit,
                                    child: Text('Edit task'),
                                  ),
                                  PopupMenuItem(
                                    value: _TaskAction.archive,
                                    child: Text('Archive task'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 80),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _createTask({
    required String groupId,
    required String ownerId,
    required String timezone,
  }) async {
    final draft = await _showTaskEditor(timezone: timezone);
    if (draft == null) {
      return;
    }

    try {
      final repository = ref.read(taskRepositoryProvider);
      await repository.createTask(
        groupId: groupId,
        ownerId: ownerId,
        title: draft.title,
        description: draft.description,
        type: draft.type,
        localTimeMinutes: draft.localTimeMinutes,
        scheduledTimeUtc: draft.scheduledTimeUtc,
        goalCount: draft.goalCount,
        goalUnit: draft.goalUnit,
      );
      _showSnack('Task added.');
    } catch (error) {
      _showSnack('Failed to add task: $error');
    }
  }

  Future<void> _handleTaskAction({
    required _TaskAction action,
    required Task task,
    required String groupId,
    required String userId,
    required String localDateKey,
    required String timezone,
  }) async {
    switch (action) {
      case _TaskAction.done:
        await _setCompletion(
          groupId: groupId,
          taskId: task.id,
          userId: userId,
          localDateKey: localDateKey,
          status: CompletionStatus.done,
        );
        return;
      case _TaskAction.skipped:
        await _setCompletion(
          groupId: groupId,
          taskId: task.id,
          userId: userId,
          localDateKey: localDateKey,
          status: CompletionStatus.skipped,
        );
        return;
      case _TaskAction.edit:
        final draft = await _showTaskEditor(task: task, timezone: timezone);
        if (draft == null) {
          return;
        }

        final updatedTask = task.copyWith(
          title: draft.title,
          description: draft.description,
          type: draft.type,
          localTimeMinutes: draft.localTimeMinutes,
          scheduledTimeUtc: draft.scheduledTimeUtc,
          goalCount: draft.goalCount,
          goalUnit: draft.goalUnit,
          clearDescription: draft.description == null,
          clearLocalTimeMinutes: draft.localTimeMinutes == null,
          clearScheduledTimeUtc: draft.scheduledTimeUtc == null,
          clearGoalCount: draft.goalCount == null,
          clearGoalUnit: draft.goalUnit == null,
          clearDaysOfWeek: true,
          daysOfWeek: null,
        );

        try {
          final repository = ref.read(taskRepositoryProvider);
          await repository.updateTask(task: updatedTask, actorUserId: userId);
          _showSnack('Task updated.');
        } catch (error) {
          _showSnack('Failed to update task: $error');
        }
        return;
      case _TaskAction.archive:
        try {
          final repository = ref.read(taskRepositoryProvider);
          await repository.setTaskActive(
            groupId: groupId,
            taskId: task.id,
            active: false,
            actorUserId: userId,
          );
          _showSnack('Task archived.');
        } catch (error) {
          _showSnack('Failed to archive task: $error');
        }
        return;
    }
  }

  Future<void> _setCompletion({
    required String groupId,
    required String taskId,
    required String userId,
    required String localDateKey,
    required CompletionStatus status,
  }) async {
    try {
      final repository = ref.read(completionRepositoryProvider);
      await repository.upsertCompletion(
        groupId: groupId,
        taskId: taskId,
        userId: userId,
        localDateKey: localDateKey,
        status: status,
      );
      _showSnack(status == CompletionStatus.done ? 'Marked done.' : 'Marked skipped.');
    } catch (error) {
      _showSnack('Failed to update completion: $error');
    }
  }

  Future<_TaskDraft?> _showTaskEditor({Task? task, required String timezone}) {
    final titleController = TextEditingController(text: task?.title ?? '');
    final descriptionController = TextEditingController(text: task?.description ?? '');
    final goalCountController = TextEditingController(
      text: task?.goalCount == null ? '' : task!.goalCount!.toString(),
    );
    final otherGoalUnitController = TextEditingController();

    var selectedType = task?.type ?? TaskType.daily;
    TimeOfDay? selectedLocalTime = _timeOfDayFromMinutes(task?.localTimeMinutes);

    DateTime? selectedOneTimeDate;
    TimeOfDay? selectedOneTimeTime;
    String? selectedGoalUnit;

    final initialGoalUnit = task?.goalUnit;
    if (initialGoalUnit != null && initialGoalUnit.isNotEmpty) {
      if (_goalUnitOptions.contains(initialGoalUnit)) {
        selectedGoalUnit = initialGoalUnit;
      } else {
        selectedGoalUnit = 'other';
        otherGoalUnitController.text = initialGoalUnit;
      }
    }

    if (task?.scheduledTimeUtc != null) {
      final location = tz.getLocation(timezone);
      final local = tz.TZDateTime.from(task!.scheduledTimeUtc!, location);
      selectedOneTimeDate = DateTime(local.year, local.month, local.day);
      selectedOneTimeTime = TimeOfDay(hour: local.hour, minute: local.minute);
    }

    return showModalBottomSheet<_TaskDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task == null ? 'Add Task' : 'Edit Task',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TaskType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Task Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: TaskType.daily,
                          child: Text('Daily'),
                        ),
                        DropdownMenuItem(
                          value: TaskType.oneTime,
                          child: Text('One-time'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setModalState(() {
                          selectedType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: goalCountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Goal Count (Optional)',
                        hintText: 'e.g. 500, 10000, 45',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGoalUnit,
                      decoration: const InputDecoration(
                        labelText: 'Goal Unit (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ml', child: Text('ml')),
                        DropdownMenuItem(value: 'steps', child: Text('steps')),
                        DropdownMenuItem(value: 'km', child: Text('km')),
                        DropdownMenuItem(value: 'min', child: Text('min')),
                        DropdownMenuItem(value: 'hour', child: Text('hour')),
                        DropdownMenuItem(value: 'reps', child: Text('reps')),
                        DropdownMenuItem(value: 'pages', child: Text('pages')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),                    
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          selectedGoalUnit = value;
                          if (selectedGoalUnit != 'other') {
                            otherGoalUnitController.clear();
                          }
                        });
                      },
                    ),
                    if (selectedGoalUnit == 'other') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: otherGoalUnitController,
                        decoration: const InputDecoration(
                          labelText: 'Custom Unit',
                          hintText: 'e.g. liters, minutes, sets',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (selectedType == TaskType.daily)
                      _TimePickerRow(
                        label: selectedLocalTime == null
                            ? 'Daily time: Not set'
                            : 'Daily time: ${selectedLocalTime!.format(context)}',
                        onPick: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: selectedLocalTime ?? const TimeOfDay(hour: 9, minute: 0),
                          );
                          if (picked == null) {
                            return;
                          }

                          setModalState(() {
                            selectedLocalTime = picked;
                          });
                        },
                        onClear: selectedLocalTime == null
                            ? null
                            : () {
                                setModalState(() {
                                  selectedLocalTime = null;
                                });
                              },
                      )
                    else
                      Column(
                        children: [
                          _TimePickerRow(
                            label: selectedOneTimeDate == null
                                ? 'One-time date: Not set'
                                : 'One-time date: ${DateFormat('yyyy-MM-dd').format(selectedOneTimeDate!)}',
                            onPick: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(now.year - 2),
                                lastDate: DateTime(now.year + 5),
                                initialDate: selectedOneTimeDate ?? now,
                              );
                              if (picked == null) {
                                return;
                              }

                              setModalState(() {
                                selectedOneTimeDate = picked;
                              });
                            },
                            onClear: selectedOneTimeDate == null
                                ? null
                                : () {
                                    setModalState(() {
                                      selectedOneTimeDate = null;
                                    });
                                  },
                          ),
                          const SizedBox(height: 8),
                          _TimePickerRow(
                            label: selectedOneTimeTime == null
                                ? 'One-time time: Not set'
                                : 'One-time time: ${selectedOneTimeTime!.format(context)}',
                            onPick: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedOneTimeTime ?? const TimeOfDay(hour: 9, minute: 0),
                              );
                              if (picked == null) {
                                return;
                              }

                              setModalState(() {
                                selectedOneTimeTime = picked;
                              });
                            },
                            onClear: selectedOneTimeTime == null
                                ? null
                                : () {
                                    setModalState(() {
                                      selectedOneTimeTime = null;
                                    });
                                  },
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              final title = titleController.text.trim();
                              if (title.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Title is required.')),
                                );
                                return;
                              }

                              final rawGoalCount = goalCountController.text.trim();
                              double? parsedGoalCount;
                              if (rawGoalCount.isNotEmpty) {
                                parsedGoalCount = double.tryParse(rawGoalCount);
                                if (parsedGoalCount == null || parsedGoalCount <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Goal count must be a positive number.')),
                                  );
                                  return;
                                }
                              }

                              String? resolvedGoalUnit;
                              if (selectedGoalUnit == 'other') {
                                resolvedGoalUnit = otherGoalUnitController.text.trim();
                              } else {
                                resolvedGoalUnit = selectedGoalUnit;
                              }

                              if (resolvedGoalUnit != null && resolvedGoalUnit.isEmpty) {
                                resolvedGoalUnit = null;
                              }

                              if (parsedGoalCount != null && resolvedGoalUnit == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please select a goal unit.')),
                                );
                                return;
                              }

                              if (parsedGoalCount == null && resolvedGoalUnit != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter goal count for selected unit.')),
                                );
                                return;
                              }

                              DateTime? scheduledTimeUtc;
                              if (selectedType == TaskType.oneTime &&
                                  selectedOneTimeDate != null &&
                                  selectedOneTimeTime != null) {
                                scheduledTimeUtc = _timeService.convertOwnerLocalTimeToUtc(
                                  year: selectedOneTimeDate!.year,
                                  month: selectedOneTimeDate!.month,
                                  day: selectedOneTimeDate!.day,
                                  hour: selectedOneTimeTime!.hour,
                                  minute: selectedOneTimeTime!.minute,
                                  timezone: timezone,
                                );
                              }

                              Navigator.of(context).pop(
                                _TaskDraft(
                                  title: title,
                                  description: descriptionController.text.trim().isEmpty
                                      ? null
                                      : descriptionController.text.trim(),
                                  type: selectedType,
                                  localTimeMinutes: selectedType == TaskType.daily
                                      ? _minutesFromTimeOfDay(selectedLocalTime)
                                      : null,
                                  scheduledTimeUtc: selectedType == TaskType.oneTime
                                      ? scheduledTimeUtc
                                      : null,
                                  goalCount: parsedGoalCount,
                                  goalUnit: resolvedGoalUnit,
                                ),
                              );
                            },
                            child: Text(task == null ? 'Create Task' : 'Save Task'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Task> _applyFilter(List<Task> tasks, _TaskFilter filter) {
    switch (filter) {
      case _TaskFilter.all:
        return tasks;
      case _TaskFilter.daily:
        return tasks.where((task) => task.type == TaskType.daily).toList();
      case _TaskFilter.oneTime:
        return tasks.where((task) => task.type == TaskType.oneTime).toList();
    }
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

  String _taskSubtitle({required Task task, required TaskCompletion? completion}) {
    final statusText = completion == null
        ? 'Pending'
        : completion.status == CompletionStatus.done
        ? 'Done'
        : 'Skipped';

    final typeText = task.type == TaskType.daily ? 'Daily' : 'One-time';

    String scheduleText = 'No time set';
    if (task.type == TaskType.daily && task.localTimeMinutes != null) {
      scheduleText = _formatMinutes(task.localTimeMinutes!);
    }

    if (task.type == TaskType.oneTime && task.scheduledTimeUtc != null) {
      scheduleText = DateFormat('yyyy-MM-dd HH:mm').format(task.scheduledTimeUtc!.toLocal());
    }

    final goalText =
        task.goalCount != null && task.goalUnit != null
            ? ' • Goal: ${_formatGoalCount(task.goalCount!)} ${task.goalUnit}'
            : '';

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

  TimeOfDay? _timeOfDayFromMinutes(int? minutes) {
    if (minutes == null) {
      return null;
    }
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  int? _minutesFromTimeOfDay(TimeOfDay? time) {
    if (time == null) {
      return null;
    }
    return time.hour * 60 + time.minute;
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TimePickerRow extends StatelessWidget {
  const _TimePickerRow({
    required this.label,
    required this.onPick,
    this.onClear,
  });

  final String label;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        TextButton(onPressed: onPick, child: const Text('Select')),
        if (onClear != null)
          TextButton(onPressed: onClear, child: const Text('Clear')),
      ],
    );
  }
}

enum _TaskFilter { all, daily, oneTime }

extension _TaskFilterLabel on _TaskFilter {
  String get label {
    switch (this) {
      case _TaskFilter.all:
        return 'All';
      case _TaskFilter.daily:
        return 'Daily';
      case _TaskFilter.oneTime:
        return 'One-time';
    }
  }
}

enum _TaskAction { done, skipped, edit, archive }

class _TaskDraft {
  const _TaskDraft({
    required this.title,
    required this.description,
    required this.type,
    required this.localTimeMinutes,
    required this.scheduledTimeUtc,
    required this.goalCount,
    required this.goalUnit,
  });

  final String title;
  final String? description;
  final TaskType type;
  final int? localTimeMinutes;
  final DateTime? scheduledTimeUtc;
  final double? goalCount;
  final String? goalUnit;
}
