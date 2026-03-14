import 'package:coworkplace/features/friends/data/friend_repository.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return FriendRepository(firestore);
});
