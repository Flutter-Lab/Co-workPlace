import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coworkplace/features/profile/data/user_profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return UserProfileRepository(firestore);
});
