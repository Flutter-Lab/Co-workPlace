import 'package:coworkplace/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TaskCompletionBar shows correct percent and counts', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: TaskCompletionBar(percent: 0.6, done: 3, total: 5),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('60% • 3 / 5'), findsOneWidget);
  });
}
