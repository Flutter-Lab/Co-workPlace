import 'package:coworkplace/features/goals/domain/goal_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('computes summary metrics with deadline and pace', () {
    final now = DateTime.utc(2026, 4, 5, 12);
    final createdAt = DateTime.utc(2026, 4, 1, 12);
    final deadline = DateTime.utc(2026, 4, 11, 23, 59, 59);

    final metrics = GoalMetrics.compute(
      targetValue: 100,
      completedValue: 40,
      createdAtUtc: createdAt,
      deadlineUtc: deadline,
      nowUtc: now,
    );

    expect(metrics.completed, 40);
    expect(metrics.remaining, 60);
    expect(metrics.progressPercent, 40);
    expect(metrics.averagePerDay, closeTo(10, 0.01));
    expect(metrics.remainingDays, 7);
    expect(metrics.requiredPerDay, closeTo(8.57, 0.01));
    expect(metrics.estimatedDaysToTarget, closeTo(6, 0.01));
    expect(metrics.estimatedCompletionUtc, isNotNull);
  });

  test('returns no estimate when there is no pace yet', () {
    final now = DateTime.utc(2026, 4, 5, 12);

    final metrics = GoalMetrics.compute(
      targetValue: 50,
      completedValue: 0,
      createdAtUtc: DateTime.utc(2026, 4, 5, 12),
      nowUtc: now,
    );

    expect(metrics.averagePerDay, 0);
    expect(metrics.estimatedDaysToTarget, isNull);
    expect(metrics.estimatedCompletionUtc, isNull);
    expect(metrics.requiredPerDay, isNull);
    expect(metrics.remainingDays, isNull);
  });
}
