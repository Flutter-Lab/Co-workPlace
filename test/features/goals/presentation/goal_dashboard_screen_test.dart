import 'package:coworkplace/app/session/app_session.dart';
import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/features/goals/domain/goal.dart';
import 'package:coworkplace/features/goals/presentation/goal_dashboard_screen.dart';
import 'package:coworkplace/features/goals/providers/goal_providers.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows empty state when no goals exist', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith(
            (ref) => Stream.value(
              AppSession.authenticated(
                userId: 'u1',
                profile: UserProfile(
                  id: 'u1',
                  displayName: 'User One',
                  username: 'user_one',
                  timezone: 'UTC',
                  dayStartHour: 4,
                  groupIds: const [],
                  feedViewMode: FeedViewMode.list,
                ),
              ),
            ),
          ),
          currentUserGoalsProvider.overrideWith(
            (ref) => Stream.value(const <Goal>[]),
          ),
        ],
        child: const MaterialApp(home: GoalDashboardScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No goals yet'), findsOneWidget);
    expect(find.text('Create Goal'), findsOneWidget);
  });

  testWidgets('shows run goal metrics for steps unit', (tester) async {
    final goal = Goal(
      id: 'g1',
      ownerId: 'u1',
      title: 'Run Goal',
      unitType: GoalUnitType.steps,
      targetValue: 5000,
      completedValue: 1200,
      itemCount: 2,
      createdAtUtc: DateTime.utc(2026, 4, 1),
      updatedAtUtc: DateTime.utc(2026, 4, 5),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith(
            (ref) => Stream.value(
              AppSession.authenticated(
                userId: 'u1',
                profile: UserProfile(
                  id: 'u1',
                  displayName: 'User One',
                  username: 'user_one',
                  timezone: 'UTC',
                  dayStartHour: 4,
                  groupIds: const [],
                  feedViewMode: FeedViewMode.list,
                ),
              ),
            ),
          ),
          currentUserGoalsProvider.overrideWith(
            (ref) => Stream.value(<Goal>[goal]),
          ),
        ],
        child: const MaterialApp(home: GoalDashboardScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Run Goal'), findsOneWidget);
    expect(find.textContaining('1200 / 5000 steps'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
  });

  testWidgets('shows add progress action for simple goals', (tester) async {
    final goal = Goal(
      id: 'g2',
      ownerId: 'u1',
      title: 'Run Goal',
      unitType: GoalUnitType.steps,
      targetValue: 5000,
      completedValue: 1200,
      itemCount: 0,
      isSimpleGoal: true,
      createdAtUtc: DateTime.utc(2026, 4, 1),
      updatedAtUtc: DateTime.utc(2026, 4, 5),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith(
            (ref) => Stream.value(
              AppSession.authenticated(
                userId: 'u1',
                profile: UserProfile(
                  id: 'u1',
                  displayName: 'User One',
                  username: 'user_one',
                  timezone: 'UTC',
                  dayStartHour: 4,
                  groupIds: const [],
                  feedViewMode: FeedViewMode.list,
                ),
              ),
            ),
          ),
          currentUserGoalsProvider.overrideWith(
            (ref) => Stream.value(<Goal>[goal]),
          ),
        ],
        child: const MaterialApp(home: GoalDashboardScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Run Goal'), findsOneWidget);
    expect(find.text('Add Progress'), findsOneWidget);
    expect(find.text('Add Item'), findsNothing);
  });
}
