import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coworkplace/features/tasks/domain/task_completion.dart';

class CompletionRepository {
  CompletionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _completions(String groupId) {
    return _firestore.collection('groups').doc(groupId).collection('completions');
  }

  Stream<List<TaskCompletion>> watchUserCompletionsForDate({
    required String groupId,
    required String userId,
    required String localDateKey,
  }) {
    return _completions(groupId)
        .where('userId', isEqualTo: userId)
        .where('localDateKey', isEqualTo: localDateKey)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return TaskCompletion.fromMap({...data, 'id': doc.id});
          }).toList();
        });
  }

  Future<TaskCompletion> upsertCompletion({
    required String groupId,
    required String taskId,
    required String userId,
    required String localDateKey,
    required CompletionStatus status,
    String? notes,
  }) async {
    final completionId = _completionDocId(
      taskId: taskId,
      userId: userId,
      localDateKey: localDateKey,
    );

    final completion = TaskCompletion(
      id: completionId,
      taskId: taskId,
      userId: userId,
      localDateKey: localDateKey,
      completedAtUtc: DateTime.now().toUtc(),
      status: status,
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
    );

    await _completions(groupId).doc(completionId).set(completion.toMap(), SetOptions(merge: true));
    return completion;
  }

  Future<TaskCompletion?> getCompletionForTaskDate({
    required String groupId,
    required String taskId,
    required String userId,
    required String localDateKey,
  }) async {
    final completionId = _completionDocId(
      taskId: taskId,
      userId: userId,
      localDateKey: localDateKey,
    );

    final snapshot = await _completions(groupId).doc(completionId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }

    return TaskCompletion.fromMap({...data, 'id': snapshot.id});
  }

  String _completionDocId({
    required String taskId,
    required String userId,
    required String localDateKey,
  }) {
    return '${taskId}_${userId}_$localDateKey';
  }
}
