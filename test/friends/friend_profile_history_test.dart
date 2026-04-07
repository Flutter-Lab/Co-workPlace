import 'package:coworkplace/features/friends/presentation/friend_profile_screen.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';
import 'package:coworkplace/features/tasks/data/completion_repository.dart';
import 'package:coworkplace/features/tasks/domain/task_completion.dart';
import 'package:coworkplace/features/tasks/providers/task_providers.dart';
import 'package:coworkplace/features/tasks/data/task_repository.dart';
import 'package:coworkplace/features/tasks/domain/task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/app/session/app_session.dart';

class _FakeTaskRepository implements TaskRepository {
  @override
  Stream<List<Task>> watchUserTasks(String userId) => Stream.value([
    Task(
      id: 't1',
      ownerId: userId,
      title: 'Test Task',
      type: TaskType.daily,
      active: true,
      createdAtUtc: DateTime.now().toUtc(),
      modifiedAtUtc: DateTime.now().toUtc(),
    ),
  ]);

  @override
  Stream<List<Task>> watchGroupTasks(String groupId) => watchUserTasks(groupId);

  @override
  Future<Task> createTask({
    required String ownerId,
    required String title,
    required TaskType type,
    String? groupId,
    String? description,
    int? localTimeMinutes,
    DateTime? scheduledTimeUtc,
    List<int>? daysOfWeek,
    double? goalCount,
    String? goalUnit,
  }) => throw UnimplementedError();

  @override
  Future<void> updateTask({required Task task, required String actorUserId}) =>
      throw UnimplementedError();

  @override
  Future<void> setTaskActive({
    required String ownerId,
    required String taskId,
    required bool active,
    required String actorUserId,
    String? groupId,
  }) => throw UnimplementedError();
}

class _FakeCompletionRepository implements CompletionRepository {
  @override
  Stream<List<TaskCompletion>> watchUserCompletionsForDate({
    required String userId,
    required String localDateKey,
    String? groupId,
  }) => Stream.value(<TaskCompletion>[]);

  @override
  Future deleteCompletion({
    required String taskId,
    required String userId,
    required String localDateKey,
  }) => throw UnimplementedError();

  @override
  Future<TaskCompletion?> getCompletionForTaskDate({
    required String taskId,
    required String userId,
    required String localDateKey,
    String? groupId,
  }) => Future.value(null);

  @override
  Future<List<TaskCompletion>> getCompletionsForDateRange({
    required String userId,
    required String fromDateKey,
    required String toDateKey,
  }) => Future.value(<TaskCompletion>[]);

  @override
  Future<TaskCompletion> upsertCompletion({
    required String taskId,
    required String userId,
    required String localDateKey,
    required CompletionStatus status,
    String? groupId,
    String? notes,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteCompletionsForDate({
    required String userId,
    required String localDateKey,
  }) => throw UnimplementedError();

  @override
  Future<int> computeStreak({required String userId, int lookback = 60}) =>
      Future.value(0);
}

void main() {
  testWidgets('tapping History opens TaskHistoryScreen', skip: true, (
    WidgetTester tester,
  ) async {
    final profile = UserProfile(
      id: 'user1',
      displayName: 'Friend',
      username: 'friend',
      timezone: 'UTC',
      dayStartHour: 4,
      groupIds: const [],
      feedViewMode: FeedViewMode.list,
    );

    final fakeTaskRepo = _FakeTaskRepository();
    final fakeCompletionRepo = _FakeCompletionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(fakeTaskRepo),
          completionRepositoryProvider.overrideWithValue(fakeCompletionRepo),
          appSessionProvider.overrideWith(
            (ref) => Stream.value(const AppSession.unauthenticated()),
          ),
        ],
        child: MaterialApp(home: FriendProfileScreen(profile: profile)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.history), findsOneWidget);

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();

    expect(find.text('Task History'), findsOneWidget);
  });
}
