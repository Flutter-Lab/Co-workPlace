import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/features/goals/data/goal_repository.dart';
import 'package:coworkplace/features/goals/domain/goal.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return GoalRepository(firestore);
});

final currentUserGoalsProvider = StreamProvider<List<Goal>>((ref) {
  final session = ref.watch(appSessionProvider).valueOrNull;
  final userId = session?.userId;
  if (userId == null) {
    return const Stream<List<Goal>>.empty();
  }
  return ref
      .watch(goalRepositoryProvider)
      .watchGoals(userId)
      .map((goals) => goals.where((g) => !g.isArchived).toList());
});

final archivedUserGoalsProvider = StreamProvider<List<Goal>>((ref) {
  final session = ref.watch(appSessionProvider).valueOrNull;
  final userId = session?.userId;
  if (userId == null) {
    return const Stream<List<Goal>>.empty();
  }
  return ref
      .watch(goalRepositoryProvider)
      .watchGoals(userId)
      .map((goals) => goals.where((g) => g.isArchived).toList());
});

/// Stream of a friend's non-archived goals, keyed by their user ID.
final friendGoalsProvider = StreamProvider.family<List<Goal>, String>((
  ref,
  friendUserId,
) {
  return ref
      .watch(goalRepositoryProvider)
      .watchGoals(friendUserId)
      .map((goals) => goals.where((g) => !g.isArchived).toList());
});
