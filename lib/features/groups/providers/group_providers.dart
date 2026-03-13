import 'package:coworkplace/features/groups/data/group_repository.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return GroupRepository(firestore);
});
