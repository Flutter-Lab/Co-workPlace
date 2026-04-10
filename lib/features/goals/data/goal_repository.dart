import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coworkplace/features/goals/domain/goal.dart';
import 'package:coworkplace/features/goals/domain/goal_item.dart';

class GoalRepository {
  GoalRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _goals(String userId) {
    return _firestore.collection('users').doc(userId).collection('goals');
  }

  CollectionReference<Map<String, dynamic>> _items(
    String userId,
    String goalId,
  ) {
    return _goals(userId).doc(goalId).collection('items');
  }

  Stream<List<Goal>> watchGoals(String userId) {
    return _goals(
      userId,
    ).orderBy('createdAtUtc', descending: false).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Goal.fromMap({...doc.data(), 'id': doc.id, 'ownerId': userId});
      }).toList();
    });
  }

  Stream<Goal?> watchGoal(String userId, String goalId) {
    return _goals(userId).doc(goalId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      return Goal.fromMap({...data, 'id': snapshot.id, 'ownerId': userId});
    });
  }

  Stream<List<GoalItem>> watchItems(String userId, String goalId) {
    return _items(
      userId,
      goalId,
    ).orderBy('updatedAtUtc', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return GoalItem.fromMap({
          ...doc.data(),
          'id': doc.id,
          'goalId': goalId,
        });
      }).toList();
    });
  }

  Future<Goal> createGoal({
    required String userId,
    required String title,
    required GoalUnitType unitType,
    String? customUnitLabel,
    required double targetValue,
    DateTime? startDateUtc,
    DateTime? deadlineUtc,
    bool isSimpleGoal = false,
    double initialCompletedValue = 0,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Goal title cannot be empty.');
    }
    if (targetValue <= 0) {
      throw ArgumentError.value(
        targetValue,
        'targetValue',
        'Target value must be greater than zero.',
      );
    }

    final nowUtc = DateTime.now().toUtc();
    final goalRef = _goals(userId).doc();

    final goal = Goal(
      id: goalRef.id,
      ownerId: userId,
      title: trimmedTitle,
      unitType: unitType,
      customUnitLabel: _normalizeCustomLabel(unitType, customUnitLabel),
      targetValue: targetValue,
      completedValue: initialCompletedValue.clamp(0.0, targetValue),
      itemCount: 0,
      isSimpleGoal: isSimpleGoal,
      startDateUtc: (startDateUtc ?? nowUtc).toUtc(),
      deadlineUtc: deadlineUtc?.toUtc(),
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
    );

    await goalRef.set(goal.toMap());
    return goal;
  }

  Future<void> updateGoal({
    required Goal goal,
    required String actorUserId,
  }) async {
    if (goal.ownerId != actorUserId) {
      throw StateError('Only the goal owner can update this goal.');
    }
    if (goal.title.trim().isEmpty) {
      throw ArgumentError.value(
        goal.title,
        'goal.title',
        'Goal title cannot be empty.',
      );
    }
    if (goal.targetValue <= 0) {
      throw ArgumentError.value(
        goal.targetValue,
        'goal.targetValue',
        'Target value must be greater than zero.',
      );
    }

    final updated = goal.copyWith(
      title: goal.title.trim(),
      customUnitLabel: _normalizeCustomLabel(
        goal.unitType,
        goal.customUnitLabel,
      ),
      updatedAtUtc: DateTime.now().toUtc(),
    );

    await _goals(
      goal.ownerId,
    ).doc(goal.id).set(updated.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteGoal({
    required String userId,
    required String goalId,
  }) async {
    final itemsSnapshot = await _items(userId, goalId).get();
    final batch = _firestore.batch();

    for (final itemDoc in itemsSnapshot.docs) {
      batch.delete(itemDoc.reference);
    }

    batch.delete(_goals(userId).doc(goalId));
    await batch.commit();
  }

  Future<void> archiveGoal({
    required String userId,
    required String goalId,
  }) async {
    await _goals(userId).doc(goalId).update({
      'isArchived': true,
      'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> unarchiveGoal({
    required String userId,
    required String goalId,
  }) async {
    await _goals(userId).doc(goalId).update({
      'isArchived': false,
      'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> addSimpleProgress({
    required String userId,
    required String goalId,
    required double delta,
    DateTime? atDateUtc, // null = today; supply a past date for backdating
  }) async {
    if (delta <= 0) {
      throw ArgumentError.value(
        delta,
        'delta',
        'Progress must be greater than zero.',
      );
    }

    final nowUtc = DateTime.now().toUtc();
    // Use the supplied date for the heatmap key (normalised to local calendar day),
    // or local today when no date is provided. updatedAtUtc always uses UTC.
    final heatmapDate = atDateUtc != null
        ? DateTime(atDateUtc.year, atDateUtc.month, atDateUtc.day)
        : DateTime.now(); // local – correct calendar day for every timezone
    final goalRef = _goals(userId).doc(goalId);

    await _firestore.runTransaction((tx) async {
      final goalSnap = await tx.get(goalRef);
      if (!goalSnap.exists) {
        throw StateError('Goal not found.');
      }

      final goalData = goalSnap.data() ?? <String, dynamic>{};
      final isSimpleGoal = goalData['isSimpleGoal'] as bool? ?? false;
      if (!isSimpleGoal) {
        throw StateError('This goal uses items. Update item progress instead.');
      }

      final currentCompleted =
          (goalData['completedValue'] as num?)?.toDouble() ?? 0;
      final nextCompleted = max(0.0, currentCompleted + delta);
      final appliedDelta = nextCompleted - currentCompleted;
      final nextDailyProgress = _nextDailyProgressMap(
        goalData: goalData,
        dateLocal: heatmapDate,
        delta: appliedDelta,
      );

      tx.update(goalRef, {
        'completedValue': nextCompleted,
        'updatedAtUtc': nowUtc.toIso8601String(),
        'dailyProgressByDate': nextDailyProgress,
      });
    });
  }

  Stream<Map<DateTime, double>> watchDailyProgress(
    String userId,
    String goalId, {
    int days = 112,
  }) {
    // Use local today so the window aligns with the user's calendar.
    final sinceLocal = DateTime.now().subtract(Duration(days: days - 1));
    final sinceDay = DateTime(
      sinceLocal.year,
      sinceLocal.month,
      sinceLocal.day,
    );

    return _goals(userId).doc(goalId).snapshots().map((snapshot) {
      final goalData = snapshot.data() ?? const <String, dynamic>{};
      final rawMap = goalData['dailyProgressByDate'];
      final data = <DateTime, double>{};

      if (rawMap is Map) {
        rawMap.forEach((key, value) {
          if (key is! String) {
            return;
          }

          final parsed = _parseDateKey(key);
          if (parsed == null || parsed.isBefore(sinceDay)) {
            return;
          }

          data[parsed] = (value as num?)?.toDouble() ?? 0;
        });
      }

      return data;
    });
  }

  Future<GoalItem> createItem({
    required String userId,
    required String goalId,
    required String name,
    required double totalUnits,
    required double completedUnits,
    String? note,
    DateTime?
    completedDate, // local date for initial progress; null = no heatmap entry
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Item name cannot be empty.');
    }
    if (totalUnits <= 0) {
      throw ArgumentError.value(
        totalUnits,
        'totalUnits',
        'Total units must be greater than zero.',
      );
    }

    final nowUtc = DateTime.now().toUtc();
    final itemRef = _items(userId, goalId).doc();
    late GoalItem created;

    await _firestore.runTransaction((tx) async {
      final goalRef = _goals(userId).doc(goalId);
      final goalSnap = await tx.get(goalRef);
      if (!goalSnap.exists) {
        throw StateError('Goal not found.');
      }
      final goalData = goalSnap.data() ?? <String, dynamic>{};
      final isSimpleGoal = goalData['isSimpleGoal'] as bool? ?? false;
      if (isSimpleGoal) {
        throw StateError(
          'Simple goals do not use items. Use Add Progress instead.',
        );
      }
      final currentCompleted =
          (goalData['completedValue'] as num?)?.toDouble() ?? 0;
      final currentItemCount = (goalData['itemCount'] as num?)?.toInt() ?? 0;

      final normalizedCompleted = completedUnits
          .clamp(0, totalUnits)
          .toDouble();
      final status = normalizedCompleted >= totalUnits
          ? GoalItemStatus.completed
          : GoalItemStatus.active;

      created = GoalItem(
        id: itemRef.id,
        goalId: goalId,
        name: trimmedName,
        totalUnits: totalUnits,
        completedUnits: normalizedCompleted,
        status: status,
        note: _normalizeNote(note),
        createdAtUtc: nowUtc,
        updatedAtUtc: nowUtc,
      );

      tx.set(itemRef, created.toMap());
      final goalUpdate = <String, dynamic>{
        'completedValue': max(0.0, currentCompleted + normalizedCompleted),
        'itemCount': max(0, currentItemCount + 1),
        'updatedAtUtc': nowUtc.toIso8601String(),
      };
      if (completedDate != null && normalizedCompleted > 0) {
        goalUpdate['dailyProgressByDate'] = _nextDailyProgressMap(
          goalData: goalData,
          dateLocal: completedDate,
          delta: normalizedCompleted,
        );
      }
      tx.update(goalRef, goalUpdate);
    });

    return created;
  }

  Future<void> updateItem({
    required String userId,
    required String goalId,
    required GoalItem item,
  }) async {
    if (item.name.trim().isEmpty) {
      throw ArgumentError.value(
        item.name,
        'item.name',
        'Item name cannot be empty.',
      );
    }
    if (item.totalUnits <= 0) {
      throw ArgumentError.value(
        item.totalUnits,
        'item.totalUnits',
        'Total units must be greater than zero.',
      );
    }

    final itemRef = _items(userId, goalId).doc(item.id);
    final goalRef = _goals(userId).doc(goalId);
    final nowUtc = DateTime.now().toUtc();

    await _firestore.runTransaction((tx) async {
      final itemSnap = await tx.get(itemRef);
      if (!itemSnap.exists) {
        throw StateError('Goal item not found.');
      }
      final oldData = itemSnap.data() ?? <String, dynamic>{};
      final oldCompleted = (oldData['completedUnits'] as num?)?.toDouble() ?? 0;

      final goalSnap = await tx.get(goalRef);
      if (!goalSnap.exists) {
        throw StateError('Goal not found.');
      }
      final goalData = goalSnap.data() ?? <String, dynamic>{};
      final currentGoalCompleted =
          (goalData['completedValue'] as num?)?.toDouble() ?? 0;

      final normalizedCompleted = item.completedUnits
          .clamp(0, item.totalUnits)
          .toDouble();
      final status = normalizedCompleted >= item.totalUnits
          ? GoalItemStatus.completed
          : GoalItemStatus.active;

      final updatedItem = item.copyWith(
        name: item.name.trim(),
        completedUnits: normalizedCompleted,
        status: status,
        note: _normalizeNote(item.note),
        updatedAtUtc: nowUtc,
        clearNote: _normalizeNote(item.note) == null,
      );

      final nextGoalCompleted = max(
        0.0,
        currentGoalCompleted - oldCompleted + normalizedCompleted,
      );
      final nextDailyProgress = _nextDailyProgressMap(
        goalData: goalData,
        dateLocal: DateTime.now(),
        delta: normalizedCompleted - oldCompleted,
      );

      tx.set(itemRef, updatedItem.toMap(), SetOptions(merge: true));
      tx.update(goalRef, {
        'completedValue': nextGoalCompleted,
        'updatedAtUtc': nowUtc.toIso8601String(),
        'dailyProgressByDate': nextDailyProgress,
      });
    });
  }

  Future<void> updateItemProgress({
    required String userId,
    required String goalId,
    required String itemId,
    required double completedUnits,
  }) async {
    final itemRef = _items(userId, goalId).doc(itemId);
    final goalRef = _goals(userId).doc(goalId);
    final nowUtc = DateTime.now().toUtc();

    await _firestore.runTransaction((tx) async {
      final itemSnap = await tx.get(itemRef);
      if (!itemSnap.exists) {
        throw StateError('Goal item not found.');
      }
      final itemData = itemSnap.data() ?? <String, dynamic>{};
      final totalUnits = (itemData['totalUnits'] as num?)?.toDouble() ?? 0;
      final oldCompleted =
          (itemData['completedUnits'] as num?)?.toDouble() ?? 0;
      final normalizedCompleted = completedUnits
          .clamp(0, totalUnits)
          .toDouble();
      final status = normalizedCompleted >= totalUnits
          ? GoalItemStatus.completed
          : GoalItemStatus.active;

      final goalSnap = await tx.get(goalRef);
      if (!goalSnap.exists) {
        throw StateError('Goal not found.');
      }
      final goalData = goalSnap.data() ?? <String, dynamic>{};
      final currentGoalCompleted =
          (goalData['completedValue'] as num?)?.toDouble() ?? 0;
      final nextGoalCompleted = max(
        0.0,
        currentGoalCompleted - oldCompleted + normalizedCompleted,
      );
      final nextDailyProgress = _nextDailyProgressMap(
        goalData: goalData,
        dateLocal: DateTime.now(),
        delta: normalizedCompleted - oldCompleted,
      );

      tx.update(itemRef, {
        'completedUnits': normalizedCompleted,
        'status': status.name,
        'updatedAtUtc': nowUtc.toIso8601String(),
      });
      tx.update(goalRef, {
        'completedValue': nextGoalCompleted,
        'updatedAtUtc': nowUtc.toIso8601String(),
        'dailyProgressByDate': nextDailyProgress,
      });
    });
  }

  Future<void> deleteItem({
    required String userId,
    required String goalId,
    required String itemId,
  }) async {
    final itemRef = _items(userId, goalId).doc(itemId);
    final goalRef = _goals(userId).doc(goalId);
    final nowUtc = DateTime.now().toUtc();

    await _firestore.runTransaction((tx) async {
      final itemSnap = await tx.get(itemRef);
      if (!itemSnap.exists) {
        return;
      }

      final goalSnap = await tx.get(goalRef);
      if (!goalSnap.exists) {
        tx.delete(itemRef);
        return;
      }

      final itemData = itemSnap.data() ?? <String, dynamic>{};
      final oldCompleted =
          (itemData['completedUnits'] as num?)?.toDouble() ?? 0;

      final goalData = goalSnap.data() ?? <String, dynamic>{};
      final currentGoalCompleted =
          (goalData['completedValue'] as num?)?.toDouble() ?? 0;
      final currentItemCount = (goalData['itemCount'] as num?)?.toInt() ?? 0;
      final nextDailyProgress = _nextDailyProgressMap(
        goalData: goalData,
        dateLocal: DateTime.now(),
        delta: -oldCompleted,
      );

      tx.delete(itemRef);
      tx.update(goalRef, {
        'completedValue': max(0.0, currentGoalCompleted - oldCompleted),
        'itemCount': max(0, currentItemCount - 1),
        'updatedAtUtc': nowUtc.toIso8601String(),
        'dailyProgressByDate': nextDailyProgress,
      });
    });
  }

  Future<void> deleteProgressEntry({
    required String userId,
    required String goalId,
    required DateTime dateLocal,
  }) async {
    final goalRef = _goals(userId).doc(goalId);
    final nowUtc = DateTime.now().toUtc();
    await _firestore.runTransaction((tx) async {
      final goalSnap = await tx.get(goalRef);
      if (!goalSnap.exists) return;
      final goalData = goalSnap.data() ?? <String, dynamic>{};

      final key = _dateKey(dateLocal);
      final rawMap = goalData['dailyProgressByDate'];
      final existing = <String, double>{};
      if (rawMap is Map) {
        rawMap.forEach((k, v) {
          if (k is String) existing[k] = (v as num?)?.toDouble() ?? 0;
        });
      }
      final removed = existing.remove(key) ?? 0;
      final currentCompleted =
          (goalData['completedValue'] as num?)?.toDouble() ?? 0;
      tx.update(goalRef, {
        'completedValue': max(0.0, currentCompleted - removed),
        'updatedAtUtc': nowUtc.toIso8601String(),
        'dailyProgressByDate': existing,
      });
    });
  }

  Future<void> editProgressEntry({
    required String userId,
    required String goalId,
    required DateTime dateLocal,
    required double newValue,
  }) async {
    if (newValue < 0) {
      throw ArgumentError.value(newValue, 'newValue', 'Value must be >= 0.');
    }
    final goalRef = _goals(userId).doc(goalId);
    final nowUtc = DateTime.now().toUtc();
    await _firestore.runTransaction((tx) async {
      final goalSnap = await tx.get(goalRef);
      if (!goalSnap.exists) return;
      final goalData = goalSnap.data() ?? <String, dynamic>{};

      final key = _dateKey(dateLocal);
      final rawMap = goalData['dailyProgressByDate'];
      final existing = <String, double>{};
      if (rawMap is Map) {
        rawMap.forEach((k, v) {
          if (k is String) existing[k] = (v as num?)?.toDouble() ?? 0;
        });
      }
      final oldValue = existing[key] ?? 0;
      final delta = newValue - oldValue;
      if (newValue <= 0) {
        existing.remove(key);
      } else {
        existing[key] = newValue;
      }
      final currentCompleted =
          (goalData['completedValue'] as num?)?.toDouble() ?? 0;
      tx.update(goalRef, {
        'completedValue': max(0.0, currentCompleted + delta),
        'updatedAtUtc': nowUtc.toIso8601String(),
        'dailyProgressByDate': existing,
      });
    });
  }

  Map<String, double> _nextDailyProgressMap({
    required Map<String, dynamic> goalData,
    required DateTime dateLocal, // local calendar date to key progress against
    required double delta,
    int keepDays = 180,
  }) {
    final existing = <String, double>{};
    final rawMap = goalData['dailyProgressByDate'];

    if (rawMap is Map) {
      rawMap.forEach((key, value) {
        if (key is String) {
          existing[key] = (value as num?)?.toDouble() ?? 0;
        }
      });
    }

    if (delta != 0) {
      final key = _dateKey(dateLocal);
      final current = existing[key] ?? 0;
      final next = max<double>(0.0, current + delta);
      if (next == 0) {
        existing.remove(key);
      } else {
        existing[key] = next;
      }
    }

    // Prune entries older than keepDays using local today.
    final minDate = DateTime.now().subtract(Duration(days: keepDays));
    final minDay = DateTime(minDate.year, minDate.month, minDate.day);
    final staleKeys = <String>[];
    existing.forEach((key, value) {
      final parsed = _parseDateKey(key);
      if (parsed == null || parsed.isBefore(minDay)) {
        staleKeys.add(key);
      }
    });
    for (final key in staleKeys) {
      existing.remove(key);
    }

    return existing;
  }

  String _dateKey(DateTime local) {
    // Use the date fields as-is (caller must pass a local DateTime).
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  DateTime? _parseDateKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) {
      return null;
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }

    return DateTime(year, month, day); // local calendar date
  }

  String? _normalizeCustomLabel(
    GoalUnitType unitType,
    String? customUnitLabel,
  ) {
    if (unitType != GoalUnitType.custom) {
      return null;
    }
    final trimmed = customUnitLabel?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String? _normalizeNote(String? note) {
    final trimmed = note?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
