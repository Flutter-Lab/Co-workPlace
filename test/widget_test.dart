import 'package:coworkplace/app/app.dart';
import 'package:coworkplace/app/session/app_session.dart';
import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/app/theme/theme_mode_provider.dart';
import 'package:coworkplace/core/bootstrap/bootstrap_provider.dart';
import 'package:coworkplace/core/bootstrap/bootstrap_state.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  Widget buildApp() {
    return ProviderScope(
      overrides: [
        appBootstrapProvider.overrideWith(
          (ref) async => const BootstrapState(firebaseReady: true),
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
        themeModeProvider.overrideWith(() => _StubThemeModeNotifier()),
      ],
      child: const CoworkplaceApp(),
    );
  }

  testWidgets('App shell renders bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('Goals tab shows a single app bar', (WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.track_changes_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Goal Tracker'), findsOneWidget);
  });
}

class _StubThemeModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.system;
}
