import 'package:coworkplace/features/dev/presentation/dev_dashboard_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // -------------------------------------------------------------------------
  // ProgressLineChart — pure widget, no providers needed.
  // -------------------------------------------------------------------------

  group('ProgressLineChart', () {
    Widget buildChart({
      required List<FlSpot> spots,
      double targetY = 100,
      String unitLabel = 'pages',
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: ProgressLineChart(
              spots: spots,
              firstDay: DateTime(2026, 3, 1),
              targetY: targetY,
              unitLabel: unitLabel,
            ),
          ),
        ),
      );
    }

    testWidgets('renders LineChart with a single data point', (tester) async {
      await tester.pumpWidget(
        buildChart(spots: [const FlSpot(0, 42)], targetY: 100),
      );
      await tester.pump();

      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('renders LineChart with multiple data points', (tester) async {
      final spots = [
        const FlSpot(0, 10),
        const FlSpot(3, 25),
        const FlSpot(7, 50),
        const FlSpot(14, 80),
        const FlSpot(21, 120),
      ];

      await tester.pumpWidget(
        buildChart(spots: spots, targetY: 150, unitLabel: 'min'),
      );
      await tester.pump();

      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('shows legend labels Cumulative and Target', (tester) async {
      await tester.pumpWidget(
        buildChart(spots: [const FlSpot(0, 30), const FlSpot(5, 70)]),
      );
      await tester.pump();

      expect(find.text('Cumulative'), findsOneWidget);
      expect(find.text('Target'), findsOneWidget);
    });

    testWidgets('shows correct data point count in legend', (tester) async {
      final spots = [
        const FlSpot(0, 10),
        const FlSpot(1, 20),
        const FlSpot(2, 35),
      ];

      await tester.pumpWidget(buildChart(spots: spots));
      await tester.pump();

      expect(find.text('3 data points'), findsOneWidget);
    });

    testWidgets('shows singular "data point" for exactly one spot', (
      tester,
    ) async {
      await tester.pumpWidget(buildChart(spots: [const FlSpot(0, 55)]));
      await tester.pump();

      expect(find.text('1 data point'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // TestChartScreen — no providers, uses fixed test data.
  // -------------------------------------------------------------------------

  group('TestChartScreen', () {
    testWidgets('shows AppBar title "Test Chart"', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TestChartScreen()));
      await tester.pump();

      expect(find.text('Test Chart'), findsOneWidget);
    });

    testWidgets('shows TEST DATA chip in AppBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TestChartScreen()));
      await tester.pump();

      expect(find.text('TEST DATA'), findsOneWidget);
    });

    testWidgets('shows first scenario title: Reading — On Track', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: TestChartScreen()));
      await tester.pump();

      expect(find.text('Reading \u2014 On Track'), findsOneWidget);
    });

    testWidgets('shows at least one LineChart for test data', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TestChartScreen()));
      await tester.pump();

      expect(find.byType(LineChart), findsAtLeastNWidgets(1));
    });

    testWidgets('shows "Cumulative progress (test data)" subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: TestChartScreen()));
      await tester.pump();

      expect(
        find.text('Cumulative progress (test data)'),
        findsAtLeastNWidgets(1),
      );
    });
  });
}
