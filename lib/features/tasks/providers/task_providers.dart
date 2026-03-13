import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:coworkplace/features/tasks/data/completion_repository.dart';
import 'package:coworkplace/features/tasks/data/task_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return TaskRepository(firestore);
});

final completionRepositoryProvider = Provider<CompletionRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return CompletionRepository(firestore);
});
