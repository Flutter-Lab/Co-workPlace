import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coworkplace/core/widgets/vote_ticker.dart';
import 'package:coworkplace/core/providers/vote_ticker_provider.dart';

void main() {
  testWidgets('VoteTicker shows announcement when announced', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: Scaffold(body: VoteTicker())),
      ),
    );

    // Obtain the provider container from the widget's context and announce
    final BuildContext ctx = tester.element(find.byType(VoteTicker));
    final container = ProviderScope.containerOf(ctx);
    container
        .read(voteTickerProvider.notifier)
        .announce('Alice voted for Bob\'s task', color: Colors.pink);

    // Rebuild and allow animation start
    await tester.pump();

    expect(find.textContaining('Alice voted for Bob'), findsOneWidget);
  });
}
