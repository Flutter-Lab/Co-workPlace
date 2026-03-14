import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coworkplace/features/tasks/domain/task_completion.dart';

class CompletionRepository {
  CompletionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _completions(String userId) {
    return _firestore.collection('users').doc(userId).collection('completions');
  }

  Stream<List<TaskCompletion>> watchUserCompletionsForDate({
    required String userId,
    required String localDateKey,
    String? groupId,
  }) {
    return _completions(userId)
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
    required String taskId,
    required String userId,
    required String localDateKey,
    required CompletionStatus status,
    String? groupId,
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

    await _completions(userId).doc(completionId).set(completion.toMap(), SetOptions(merge: true));
    return completion;
  }

  Future<TaskCompletion?> getCompletionForTaskDate({
    required String taskId,
    required String userId,
    required String localDateKey,
    String? groupId,
  }) async {
    final completionId = _completionDocId(
      taskId: taskId,
      userId: userId,
      localDateKey: localDateKey,
    );

    final snapshot = await _completions(userId).doc(completionId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }

    return TaskCompletion.fromMap({...data, 'id': snapshot.id});
  }

  Future<void> deleteCompletion({
    required String taskId,
    required String userId,
    required String localDateKey,
  }) async {
    final completionId = _completionDocId(
      taskId: taskId,
      userId: userId,
      localDateKey: localDateKey,
    );
    await _completions(userId).doc(completionId).delete();
  }

  Future<void> deleteCompletionsForDate({
    required String userId,
    required String localDateKey,
  }) async {
    final snapshot = await _completions(userId)
        .where('localDateKey', isEqualTo: localDateKey)
        .get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<List<TaskCompletion>> getCompletionsForDateRange({
    required String userId,
    required String fromDateKey,
    required String toDateKey,
  }) async {
    final snapshot = await _completions(userId)
        .where('localDateKey', isGreaterThanOrEqualTo: fromDateKey)
        .where('localDateKey', isLessThanOrEqualTo: toDateKey)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return TaskCompletion.fromMap({...data, 'id': doc.id});
    }).toList();
  }

  String _completionDocId({
    required String taskId,
    required String userId,
    required String localDateKey,
  }) {
    return '${taskId}_${userId}_$localDateKey';
  }
}
