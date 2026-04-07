import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/features/friends/data/friend_repository.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const _kFriendsLastVisitKey = 'friends_tab_last_visit_ms';

final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return FriendRepository(firestore);
});

/// Holds the UTC timestamp of the last time the user visited the Friends tab.
/// Initialise from Hive on startup; updated by [HomeShellScreen] on navigation.
final friendsTabLastVisitProvider = StateProvider<DateTime?>((ref) {
  final box = Hive.box<int>('app_prefs');
  final ms = box.get(_kFriendsLastVisitKey);
  return ms != null
      ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
      : null;
});

/// Persists [timestamp] to Hive and updates [friendsTabLastVisitProvider].
void recordFriendsTabVisit(WidgetRef ref, DateTime timestamp) {
  Hive.box<int>(
    'app_prefs',
  ).put(_kFriendsLastVisitKey, timestamp.millisecondsSinceEpoch);
  ref.read(friendsTabLastVisitProvider.notifier).state = timestamp;
}

/// Emits `true` when at least one friend has been seen since the last
/// Friends-tab visit (or within 30 min if the tab was never visited).
final friendActivityBadgeProvider = StreamProvider<bool>((ref) async* {
  final session = ref.watch(appSessionProvider).valueOrNull;
  if (session == null || session.userId == null) {
    yield false;
    return;
  }

  final userId = session.userId!;
  final friendRepo = ref.watch(friendRepositoryProvider);
  final profileRepo = ref.watch(userProfileRepositoryProvider);
  final lastVisit = ref.watch(friendsTabLastVisitProvider);

  await for (final friends in friendRepo.watchFriends(userId)) {
    if (friends.isEmpty) {
      yield false;
      continue;
    }
    final friendIds = friends.map((f) => f.friendUserId).toList();
    try {
      final profiles = await profileRepo.getByIds(friendIds);
      final cutoff =
          lastVisit ??
          DateTime.now().toUtc().subtract(const Duration(minutes: 30));
      yield profiles.any(
        (p) => p.lastSeenAtUtc != null && p.lastSeenAtUtc!.isAfter(cutoff),
      );
    } catch (_) {
      yield false;
    }
  }
});
