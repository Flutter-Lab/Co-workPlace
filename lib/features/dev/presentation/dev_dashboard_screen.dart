import 'dart:math' as math;

import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/features/goals/data/goal_repository.dart';
import 'package:coworkplace/features/goals/domain/goal.dart';
import 'package:coworkplace/features/goals/providers/goal_providers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Developer dashboard — only accessible in debug mode (kDebugMode == true).
/// Shows an fl_chart LineChart of cumulative daily progress for each goal so
/// the chart widget can be validated on a real device without shipping it to
/// users yet.
class DevDashboardScreen extends ConsumerWidget {
  const DevDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(kDebugMode, 'DevDashboardScreen must only be used in debug mode.');

    final sessionAsync = ref.watch(appSessionProvider);
    final goalsAsync = ref.watch(currentUserGoalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev Dashboard'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TestChartScreen()),
            ),
            icon: const Icon(Icons.science_outlined, color: Colors.white),
            label: const Text('Test', style: TextStyle(color: Colors.white)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Chip(
              label: const Text(
                'DEBUG',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Colors.red.shade700,
              side: BorderSide.none,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Session error: $e')),
        data: (session) {
          final userId = session.userId;
          if (userId == null) {
            return const Center(child: Text('Not signed in.'));
          }

          return goalsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Goals error: $e')),
            data: (goals) {
              if (goals.isEmpty) {
                return const Center(
                  child: Text(
                    'No active goals to chart.',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: goals.length,
                separatorBuilder: (context0, i) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  return _GoalChartCard(
                    goal: goal,
                    userId: userId,
                    repo: ref.read(goalRepositoryProvider),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _GoalChartCard extends StatelessWidget {
  const _GoalChartCard({
    required this.goal,
    required this.userId,
    required this.repo,
  });

  final Goal goal;
  final String userId;
  final GoalRepository repo;

  String _unitLabel() {
    if (goal.unitType == GoalUnitType.custom && goal.customUnitLabel != null) {
      return goal.customUnitLabel!;
    }
    return goal.unitType.displayLabel.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Container(
            color: Colors.deepPurple.withAlpha(20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${_formatNum(goal.completedValue)} / '
                  '${_formatNum(goal.targetValue)} '
                  '${_unitLabel()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<Map<DateTime, double>>(
              stream: repo.watchDailyProgress(userId, goal.id, days: 60),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final rawProgress = snapshot.data ?? const {};

                if (rawProgress.isEmpty) {
                  return const SizedBox(
                    height: 160,
                    child: Center(
                      child: Text(
                        'No dated progress entries yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                // Build cumulative spots
                final sorted = rawProgress.entries.toList()
                  ..sort((a, b) => a.key.compareTo(b.key));

                final firstDay = sorted.first.key;
                double cumulative = 0;
                final spots = <FlSpot>[];
                for (final entry in sorted) {
                  cumulative += entry.value;
                  final x = entry.key.difference(firstDay).inDays.toDouble();
                  spots.add(FlSpot(x, cumulative));
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cumulative progress (last 60 days)',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ProgressLineChart(
                      spots: spots,
                      firstDay: firstDay,
                      targetY: goal.targetValue,
                      unitLabel: _unitLabel(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ProgressLineChart — public, provider-free, directly widget-testable.
// ---------------------------------------------------------------------------

/// Renders a cumulative [LineChart] for the given pre-computed [spots].
/// No Firestore or Riverpod dependencies — safe to pump in widget tests.
class ProgressLineChart extends StatelessWidget {
  const ProgressLineChart({
    super.key,
    required this.spots,
    required this.firstDay,
    required this.targetY,
    required this.unitLabel,
  });

  final List<FlSpot> spots;
  final DateTime firstDay;
  final double targetY;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final maxX = spots.isEmpty ? 1.0 : spots.last.x;
    final maxY = spots.isEmpty
        ? targetY * 1.05
        : math.max(
            spots.map((s) => s.y).reduce(math.max) * 1.1,
            targetY * 1.05,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxX,
              minY: 0,
              maxY: maxY,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: Colors.grey.withAlpha(40), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.max) return const SizedBox.shrink();
                      return Text(
                        _formatNum(value),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: maxX <= 7
                        ? 1
                        : maxX <= 30
                        ? 7
                        : 14,
                    getTitlesWidget: (value, meta) {
                      final date = firstDay.add(Duration(days: value.toInt()));
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('d/M').format(date),
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: targetY,
                    color: Colors.green.shade400,
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      labelResolver: (_) => 'Target: ${_formatNum(targetY)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  color: Colors.deepPurple,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: spots.length <= 15,
                    getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                      radius: 3,
                      color: Colors.deepPurple,
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.deepPurple.withAlpha(25),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => Colors.deepPurple.shade700,
                  getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                    final date = firstDay.add(Duration(days: s.x.toInt()));
                    return LineTooltipItem(
                      '${DateFormat('dd MMM').format(date)}\n'
                      '${_formatNum(s.y)} $unitLabel',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(width: 20, height: 2.5, color: Colors.deepPurple),
            const SizedBox(width: 6),
            const Text(
              'Cumulative',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            Container(width: 20, height: 2, color: Colors.green),
            const SizedBox(width: 6),
            const Text(
              'Target',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const Spacer(),
            Text(
              '${spots.length} data point${spots.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TestChartScreen — deterministic test data, no provider dependencies.
// ---------------------------------------------------------------------------

/// A self-contained screen that pumps [ProgressLineChart] with hard-coded
/// deterministic data so the chart widget can be validated visually without
/// needing any real Firestore goals.
class TestChartScreen extends StatelessWidget {
  const TestChartScreen({super.key});

  // Fixed anchor date — keeps test data consistent across runs.
  static final DateTime _base = DateTime(2026, 3, 1);

  /// Converts a list of per-day deltas into cumulative [FlSpot] list.
  /// Days with 0 value are skipped (no entry that day).
  static List<FlSpot> _buildSpots(List<double> dailyDeltas) {
    double cumulative = 0;
    final spots = <FlSpot>[];
    for (int i = 0; i < dailyDeltas.length; i++) {
      if (dailyDeltas[i] > 0) {
        cumulative += dailyDeltas[i];
        spots.add(FlSpot(i.toDouble(), cumulative));
      }
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final scenarios = [
      _Scenario(
        title: 'Reading — On Track',
        unitLabel: 'pages',
        targetY: 150,
        // 30 days, avg ~6.5 pages/day → cumulative ≈ 195 (exceeds target near end)
        spots: _buildSpots([
          5,
          8,
          6,
          7,
          9,
          5,
          6,
          8,
          7,
          9,
          6,
          5,
          8,
          7,
          6,
          9,
          8,
          5,
          7,
          9,
          6,
          8,
          7,
          5,
          9,
          6,
          8,
          7,
          9,
          5,
        ]),
      ),
      _Scenario(
        title: 'Exercise — Behind Target',
        unitLabel: 'min',
        targetY: 150,
        // 20 days, many zeros → cumulative ≈ 108 (behind target)
        spots: _buildSpots([
          10,
          0,
          15,
          8,
          0,
          12,
          5,
          0,
          10,
          8,
          0,
          15,
          0,
          10,
          5,
          0,
          8,
          12,
          0,
          10,
        ]),
      ),
      _Scenario(
        title: 'Savings — Goal Exceeded',
        unitLabel: 'USD',
        targetY: 500,
        // 15 days, large chunks → cumulative = 740 (well past target)
        spots: _buildSpots([
          50,
          30,
          80,
          0,
          60,
          100,
          0,
          50,
          70,
          0,
          40,
          90,
          60,
          30,
          80,
        ]),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Chart'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Chip(
              label: const Text(
                'TEST DATA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Colors.orange.shade700,
              side: BorderSide.none,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: scenarios.length,
        separatorBuilder: (context0, i) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final s = scenarios[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: Colors.deepPurple.withAlpha(20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        'Target: ${_formatNum(s.targetY)} ${s.unitLabel}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cumulative progress (test data)',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ProgressLineChart(
                        spots: s.spots,
                        firstDay: _base,
                        targetY: s.targetY,
                        unitLabel: s.unitLabel,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Scenario {
  const _Scenario({
    required this.title,
    required this.unitLabel,
    required this.targetY,
    required this.spots,
  });

  final String title;
  final String unitLabel;
  final double targetY;
  final List<FlSpot> spots;
}

// ---------------------------------------------------------------------------

String _formatNum(double v) =>
    v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
