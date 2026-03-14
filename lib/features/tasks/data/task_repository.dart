import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coworkplace/features/tasks/domain/task.dart';

class TaskRepository {
  TaskRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _tasks(String userId) {
    return _firestore.collection('users').doc(userId).collection('tasks');
  }

  Stream<List<Task>> watchUserTasks(String userId) {
    return _tasks(userId)
        .orderBy('createdAtUtc', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return Task.fromMap({...data, 'id': doc.id, 'ownerId': userId});
          }).toList();
        });
  }

  // Temporary compatibility alias during migration away from group-owned data.
  Stream<List<Task>> watchGroupTasks(String groupId) {
    return watchUserTasks(groupId);
  }

  Future<Task> createTask({
    required String ownerId,
    required String title,
    required TaskType type,
    String? groupId,
    String? description,
    int? localTimeMinutes,
    DateTime? scheduledTimeUtc,
    List<int>? daysOfWeek,
    double? goalCount,
    String? goalUnit,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Task title cannot be empty.');
    }

    final nowUtc = DateTime.now().toUtc();
    final docRef = _tasks(ownerId).doc();
    final task = Task(
      id: docRef.id,
      groupId: groupId,
      ownerId: ownerId,
      title: trimmedTitle,
      type: type,
      active: true,
      createdAtUtc: nowUtc,
      modifiedAtUtc: nowUtc,
      description: description?.trim().isEmpty ?? true ? null : description!.trim(),
      localTimeMinutes: localTimeMinutes,
      scheduledTimeUtc: scheduledTimeUtc?.toUtc(),
      daysOfWeek: daysOfWeek,
      goalCount: goalCount,
      goalUnit: goalUnit?.trim().isEmpty ?? true ? null : goalUnit!.trim(),
    );

    await docRef.set(task.toMap());
    return task;
  }

  Future<void> updateTask({
    required Task task,
    required String actorUserId,
  }) async {
    if (task.title.trim().isEmpty) {
      throw ArgumentError.value(task.title, 'task.title', 'Task title cannot be empty.');
    }

    if (task.ownerId != actorUserId) {
      throw StateError('Only the task owner can update this task.');
    }

    final taskRef = _tasks(task.ownerId).doc(task.id);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(taskRef);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError('Task not found.');
      }

      final storedOwnerId = data['ownerId'] as String?;
      if (storedOwnerId != actorUserId) {
        throw StateError('Only the task owner can update this task.');
      }

      final nextTask = task.copyWith(modifiedAtUtc: DateTime.now().toUtc());
      transaction.set(taskRef, nextTask.toMap(), SetOptions(merge: true));
    });
  }

  Future<void> setTaskActive({
    required String ownerId,
    required String taskId,
    required bool active,
    required String actorUserId,
    String? groupId,
  }) async {
    final taskRef = _tasks(ownerId).doc(taskId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(taskRef);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError('Task not found.');
      }

      final ownerId = data['ownerId'] as String?;
      if (ownerId != actorUserId) {
        throw StateError('Only the task owner can change task status.');
      }

      transaction.update(taskRef, {
        'active': active,
        'modifiedAtUtc': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }
}
