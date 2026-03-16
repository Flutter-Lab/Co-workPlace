import 'package:cloud_firestore/cloud_firestore.dart';

class ScoreService {
  ScoreService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Period id helpers
  String weekPeriodId(DateTime utc) {
    final weekYear = utc.toUtc().year;
    final weekOfYear = _isoWeekNumber(utc.toUtc());
    return 'week_${weekYear}_W${weekOfYear.toString().padLeft(2, '0')}';
  }

  String monthPeriodId(DateTime utc) {
    final y = utc.toUtc().year;
    final m = utc.toUtc().month;
    return 'month_${y}_${m.toString().padLeft(2, '0')}';
  }

  String alltimePeriodId() => 'alltime';

  int _isoWeekNumber(DateTime date) {
    // ISO week algorithm
    final thursday = date.subtract(Duration(days: (date.weekday + 3) % 7));
    final firstJan = DateTime(thursday.year, 1, 1);
    final diff = thursday.difference(firstJan).inDays;
    return (diff ~/ 7) + 1;
  }

  // Create activity hour marker doc (deterministic id) and increment score
  Future<void> awardActivityHour({required String userId, DateTime? atUtc}) async {
    final now = (atUtc ?? DateTime.now()).toUtc();
    final hourKey = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}';
    final hourRef = _firestore.doc('users/$userId/activityHours/$hourKey');

    final weekId = weekPeriodId(now);
    final monthId = monthPeriodId(now);
    final allId = alltimePeriodId();

    await _firestore.runTransaction((tx) async {
      final hourSnap = await tx.get(hourRef);
      if (hourSnap.exists) return; // already awarded for this hour
      tx.set(hourRef, {'createdAt': FieldValue.serverTimestamp()});

      final weekRef = _firestore.doc('users/$userId/scores/$weekId');
      final monthRef = _firestore.doc('users/$userId/scores/$monthId');
      final allRef = _firestore.doc('users/$userId/scores/$allId');

      tx.set(weekRef, {'periodId': weekId, 'points': FieldValue.increment(1), 'updatedAtUtc': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      tx.set(monthRef, {'periodId': monthId, 'points': FieldValue.increment(1), 'updatedAtUtc': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      tx.set(allRef, {'periodId': allId, 'points': FieldValue.increment(1), 'updatedAtUtc': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    });
  }

  // Like a task (owner gets a point). Ensures unique like per likerId via deterministic doc id.
  Future<void> awardLike({required String ownerId, required String taskId, required String likerId}) async {
    final likeRef = _firestore.doc('tasks/$ownerId/tasks/$taskId/likes/$likerId');
    final now = DateTime.now().toUtc();
    final weekId = weekPeriodId(now);
    final monthId = monthPeriodId(now);
    final allId = alltimePeriodId();

    await _firestore.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      if (likeSnap.exists) return; // already liked
      tx.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});

      final weekRef = _firestore.doc('users/$ownerId/scores/$weekId');
      final monthRef = _firestore.doc('users/$ownerId/scores/$monthId');
      final allRef = _firestore.doc('users/$ownerId/scores/$allId');

      tx.set(weekRef, {'periodId': weekId, 'points': FieldValue.increment(1), 'updatedAtUtc': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      tx.set(monthRef, {'periodId': monthId, 'points': FieldValue.increment(1), 'updatedAtUtc': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      tx.set(allRef, {'periodId': allId, 'points': FieldValue.increment(1), 'updatedAtUtc': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    });
  }

  // Award for creating a task
  Future<void> awardTaskCreate({required String ownerId, int points = 2}) async {
    final now = DateTime.now().toUtc();
    final weekId = weekPeriodId(now);
    final monthId = monthPeriodId(now);
    final allId = alltimePeriodId();

    await _firestore.runTransaction((tx) async {
      final weekRef = _firestore.doc('users/$ownerId/scores/$weekId');
      final monthRef = _firestore.doc('users/$ownerId/scores/$monthId');
      final allRef = _firestore.doc('users/$ownerId/scores/$allId');

      tx.set(weekRef, {'periodId': weekId, 'points': FieldValue.increment(points), 'updatedAtUtc': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      tx.set(monthRef, {'periodId': monthId, 'points': FieldValue.increment(points), 'updatedAtUtc': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      tx.set(allRef, {'periodId': allId, 'points': FieldValue.increment(points), 'updatedAtUtc': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    });
  }

  // Award for completing a task (one per day enforced by completion doc elsewhere)
  Future<void> awardCompletion({required String userId, int points = 3}) async {
    final now = DateTime.now().toUtc();
    final weekId = weekPeriodId(now);
    final monthId = monthPeriodId(now);
    final allId = alltimePeriodId();

    await _firestore.runTransaction((tx) async {
      final weekRef = _firestore.doc('users/$userId/scores/$weekId');
      final monthRef = _firestore.doc('users/$userId/scores/$monthId');
      final allRef = _firestore.doc('users/$userId/scores/$allId');

      tx.set(weekRef, {'periodId': weekId, 'points': FieldValue.increment(points), 'updatedAtUtc': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      tx.set(monthRef, {'periodId': monthId, 'points': FieldValue.increment(points), 'updatedAtUtc': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      tx.set(allRef, {'periodId': allId, 'points': FieldValue.increment(points), 'updatedAtUtc': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    });
  }

  // Query top N leaderboard entries for a period (collectionGroup on scores)
  Stream<List<Map<String, dynamic>>> streamTopScores({required String periodId, int limit = 50}) {
    return _firestore.collectionGroup('scores').where('periodId', isEqualTo: periodId).orderBy('points', descending: true).limit(limit).snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        return {
          'userId': d.reference.parent.parent?.id ?? '',
          'points': (data['points'] ?? 0) as int,
          'periodId': data['periodId'],
        };
      }).toList();
    });
  }

  // Fetch scores for a specific set of userIds for a period. Returns list of maps {userId, points}
  Future<List<Map<String, dynamic>>> getScoresForUsers({required String periodId, required Iterable<String> userIds}) async {
    final results = <Map<String, dynamic>>[];
    final futures = userIds.map((userId) async {
      final docRef = _firestore.doc('users/$userId/scores/$periodId');
      final snap = await docRef.get();
      if (!snap.exists) return null;
      final data = snap.data();
      return {
        'userId': userId,
        'points': (data?['points'] ?? 0) as int,
        'periodId': periodId,
      };
    });
    final collected = await Future.wait(futures);
    for (final item in collected) {
      if (item != null) results.add(item);
    }
    // sort by points desc
    results.sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));
    return results;
  }
}
