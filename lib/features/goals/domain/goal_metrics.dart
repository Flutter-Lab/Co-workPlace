import 'dart:math';

class GoalMetrics {
  const GoalMetrics({
    required this.target,
    required this.completed,
    required this.remaining,
    required this.progressPercent,
    required this.averagePerDay,
    required this.remainingDays,
    required this.requiredPerDay,
    required this.estimatedDaysToTarget,
    required this.estimatedCompletionUtc,
  });

  final double target;
  final double completed;
  final double remaining;
  final double progressPercent;
  final double averagePerDay;
  final int? remainingDays;
  final double? requiredPerDay;
  final double? estimatedDaysToTarget;
  final DateTime? estimatedCompletionUtc;

  static GoalMetrics compute({
    required double targetValue,
    required double completedValue,
    required DateTime createdAtUtc,
    DateTime? deadlineUtc,
    DateTime? nowUtc,
  }) {
    final now = (nowUtc ?? DateTime.now()).toUtc();
    final start = createdAtUtc.toUtc();

    final safeTarget = max<double>(0.0, targetValue);
    final safeCompleted = max<double>(0.0, completedValue);
    final remaining = max<double>(0.0, safeTarget - safeCompleted);

    final elapsedSeconds = max<int>(
      1,
      now.difference(start.isAfter(now) ? now : start).inSeconds,
    );
    final elapsedDays = max(1.0, elapsedSeconds / Duration.secondsPerDay);
    final averagePerDay = safeCompleted / elapsedDays;

    final progressPercent = safeTarget <= 0
        ? 0.0
        : ((safeCompleted / safeTarget) * 100).clamp(0.0, 100.0).toDouble();

    int? remainingDays;
    double? requiredPerDay;
    if (deadlineUtc != null) {
      final deadline = deadlineUtc.toUtc();
      final dayDiff = deadline.difference(now).inHours / 24;
      remainingDays = max(0, dayDiff.ceil());
      requiredPerDay = remainingDays > 0 ? (remaining / remainingDays) : null;
    }

    double? estimatedDaysToTarget;
    DateTime? estimatedCompletionUtc;
    if (remaining <= 0) {
      estimatedDaysToTarget = 0;
      estimatedCompletionUtc = now;
    } else if (averagePerDay > 0) {
      estimatedDaysToTarget = remaining / averagePerDay;
      estimatedCompletionUtc = now.add(
        Duration(
          seconds: (estimatedDaysToTarget * Duration.secondsPerDay).round(),
        ),
      );
    }

    return GoalMetrics(
      target: safeTarget,
      completed: safeCompleted,
      remaining: remaining,
      progressPercent: progressPercent,
      averagePerDay: averagePerDay,
      remainingDays: remainingDays,
      requiredPerDay: requiredPerDay,
      estimatedDaysToTarget: estimatedDaysToTarget,
      estimatedCompletionUtc: estimatedCompletionUtc,
    );
  }
}
