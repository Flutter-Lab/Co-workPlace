import 'package:coworkplace/core/time/day_start_time_service.dart';
import 'package:coworkplace/features/tasks/domain/task.dart';
import 'package:coworkplace/features/tasks/domain/task_completion.dart';
import 'package:coworkplace/features/tasks/providers/task_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class TaskHistoryScreen extends ConsumerStatefulWidget {
  const TaskHistoryScreen({
    super.key,
    required this.userId,
    required this.timezone,
    required this.dayStartHour,
  });

  final String userId;
  final String timezone;
  final int dayStartHour;

  @override
  ConsumerState<TaskHistoryScreen> createState() => _TaskHistoryScreenState();
}

class _TaskHistoryScreenState extends ConsumerState<TaskHistoryScreen> {
  static const _timeService = DayStartTimeService();
  late final List<String> _dateKeys;
  late final Future<List<TaskCompletion>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _dateKeys = _generateDateKeys(31);
    final sorted = List.of(_dateKeys)..sort();
    _historyFuture = ref
        .read(completionRepositoryProvider)
        .getCompletionsForDateRange(
          userId: widget.userId,
          fromDateKey: sorted.first,
          toDateKey: sorted.last,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task History')),
      body: StreamBuilder<List<Task>>(
        stream: ref.watch(taskRepositoryProvider).watchUserTasks(widget.userId),
        builder: (context, taskSnapshot) {
          final taskById = {
            for (final t in taskSnapshot.data ?? const <Task>[]) t.id: t,
          };

          return FutureBuilder<List<TaskCompletion>>(
            future: _historyFuture,
            builder: (context, snap) {
              if (taskSnapshot.connectionState == ConnectionState.waiting ||
                  snap.connectionState == ConnectionState.waiting) {
                return _buildLoadingList();
              }
              if (snap.hasError) {
                return Center(
                  child: Text('Failed to load history: ${snap.error}'),
                );
              }

              final completions = snap.data ?? const <TaskCompletion>[];
              final byDate = <String, List<TaskCompletion>>{};
              for (final c in completions) {
                byDate.putIfAbsent(c.localDateKey, () => []).add(c);
              }

              final activeDates = _dateKeys
                  .where((k) => byDate.containsKey(k))
                  .toList();

              if (activeDates.isEmpty) {
                return const Center(child: Text('No task history yet.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activeDates.length,
                itemBuilder: (context, index) {
                  final key = activeDates[index];
                  return _DayHistoryCard(
                    dateKey: key,
                    completions: byDate[key]!,
                    taskById: taskById,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).disabledColor.withAlpha(51),
                shape: BoxShape.circle,
              ),
            ),
            title: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 150,
                height: 12,
                color: Theme.of(context).disabledColor.withAlpha(51),
              ),
            ),
            subtitle: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 100,
                height: 10,
                margin: const EdgeInsets.only(top: 8),
                color: Theme.of(context).disabledColor.withAlpha(31),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Returns the last [n] unique logical date keys, newest first.
  List<String> _generateDateKeys(int n) {
    final seen = <String>{};
    final result = <String>[];
    final now = DateTime.now().toUtc();
    for (int i = 0; i < n + 5; i++) {
      final instant = now.subtract(Duration(days: i));
      String key;
      try {
        key = _timeService.localDateKeyForUtcInstant(
          instantUtc: instant,
          timezone: widget.timezone,
          dayStartHour: widget.dayStartHour,
        );
      } catch (_) {
        key = DateFormat('yyyy-MM-dd').format(instant);
      }
      if (seen.add(key)) {
        result.add(key);
        if (result.length >= n) break;
      }
    }
    return result;
  }
}

class _DayHistoryCard extends StatelessWidget {
  const _DayHistoryCard({
    required this.dateKey,
    required this.completions,
    required this.taskById,
  });

  final String dateKey;
  final List<TaskCompletion> completions;
  final Map<String, Task> taskById;

  @override
  Widget build(BuildContext context) {
    final doneCount = completions
        .where((c) => c.status == CompletionStatus.done)
        .length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Text(_formatDateLabel(dateKey)),
        subtitle: Text('$doneCount / ${completions.length} completed'),
        children: [
          ...completions.map((c) {
            final task = taskById[c.taskId];
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                c.status == CompletionStatus.done
                    ? Icons.check_circle
                    : Icons.skip_next,
                size: 20,
                color: c.status == CompletionStatus.done
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).hintColor,
              ),
              title: Text(task?.title ?? '(deleted task)'),
              subtitle: Text(
                c.status == CompletionStatus.done ? 'Done' : 'Skipped',
              ),
              trailing: Text(
                DateFormat('hh:mm a').format(c.completedAtUtc.toLocal()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  String _formatDateLabel(String key) {
    try {
      final date = DateTime.parse(key);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = today
          .difference(DateTime(date.year, date.month, date.day))
          .inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      return DateFormat('EEEE, MMM d').format(date);
    } catch (_) {
      return key;
    }
  }
}
