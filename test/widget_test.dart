import 'package:coworkplace/app/app.dart';
import 'package:coworkplace/app/session/app_session.dart';
import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/core/bootstrap/bootstrap_provider.dart';
import 'package:coworkplace/core/bootstrap/bootstrap_state.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App shell renders bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appBootstrapProvider.overrideWith(
            (ref) async => const BootstrapState(firebaseReady: false),
          ),
          appSessionProvider.overrideWith(
            (ref) => Stream.value(
              AppSession.authenticated(
                userId: 'test-user',
                profile: UserProfile(
                  id: 'test-user',
                  displayName: 'Tester',
                  username: 'test_user',
                  timezone: 'UTC',
                  dayStartHour: 4,
                  groupIds: const [],
                  feedViewMode: FeedViewMode.list,
                ),
              ),
            ),
          ),
        ],
        child: const CoworkplaceApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
