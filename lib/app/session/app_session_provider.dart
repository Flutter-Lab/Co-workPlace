import 'package:coworkplace/app/session/app_session.dart';
import 'package:coworkplace/features/auth/providers/auth_providers.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appSessionProvider = StreamProvider<AppSession>((ref) async* {
  final authRepository = ref.watch(authRepositoryProvider);
  final profileRepository = ref.watch(userProfileRepositoryProvider);

  await authRepository.signInAnonymouslyIfNeeded();

  await for (final authUser in authRepository.authStateChanges()) {
    if (authUser == null) {
      yield const AppSession.unauthenticated();
      continue;
    }

    final profile = await profileRepository.getById(authUser.uid);
    yield AppSession.authenticated(userId: authUser.uid, profile: profile);
  }
});
