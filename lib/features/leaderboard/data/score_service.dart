import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ScoreService {
  ScoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

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
  Future<void> awardActivityHour({
    required String userId,
    DateTime? atUtc,
  }) async {
    final now = (atUtc ?? DateTime.now()).toUtc();
    final hourKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}';
    final hourRef = _firestore.doc('users/$userId/activityHours/$hourKey');

    final weekId = weekPeriodId(now);
    final monthId = monthPeriodId(now);
    final allId = alltimePeriodId();

    try {
      await _firestore.runTransaction((tx) async {
        final hourSnap = await tx.get(hourRef);
        if (hourSnap.exists) {
          return; // already awarded for this hour
        }
        tx.set(hourRef, {'createdAt': FieldValue.serverTimestamp()});

        final weekRef = _firestore.doc('users/$userId/scores/$weekId');
        final monthRef = _firestore.doc('users/$userId/scores/$monthId');
        final allRef = _firestore.doc('users/$userId/scores/$allId');

        tx.set(weekRef, {
          'periodId': weekId,
          'points': FieldValue.increment(1),
          'updatedAtUtc': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        tx.set(monthRef, {
          'periodId': monthId,
          'points': FieldValue.increment(1),
          'updatedAtUtc': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        tx.set(allRef, {
          'periodId': allId,
          'points': FieldValue.increment(1),
          'updatedAtUtc': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (e, st) {
      debugPrint('awardActivityHour failed: $e\n$st');
      rethrow;
    }
  }

  // Award 2 points when user opens the app, once per 2-hour window (idempotent).
  Future<void> awardAppOpen({required String userId, DateTime? atUtc}) async {
    final now = (atUtc ?? DateTime.now()).toUtc();
    final slot = now.hour ~/ 2; // 0-11 → one slot per 2 hours
    final slotKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-open$slot';
    final slotRef = _firestore.doc('users/$userId/appOpenSlots/$slotKey');

    final weekId = weekPeriodId(now);
    final monthId = monthPeriodId(now);
    final allId = alltimePeriodId();

    try {
      await _firestore.runTransaction((tx) async {
        final slotSnap = await tx.get(slotRef);
        if (slotSnap.exists) return; // already awarded for this 2-hour window

        tx.set(slotRef, {'createdAt': FieldValue.serverTimestamp()});

        final weekRef = _firestore.doc('users/$userId/scores/$weekId');
        final monthRef = _firestore.doc('users/$userId/scores/$monthId');
        final allRef = _firestore.doc('users/$userId/scores/$allId');

        for (final ref in [weekRef, monthRef, allRef]) {
          tx.set(ref, {
            'periodId': ref == weekRef
                ? weekId
                : ref == monthRef
                ? monthId
                : allId,
            'points': FieldValue.increment(2),
            'updatedAtUtc': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });
    } catch (e, st) {
      debugPrint('awardAppOpen failed: $e\n$st');
      rethrow;
    }
  }

  // Fetch all-time points for a single user. Returns 0 if no record exists.
  Future<int> getPointsForUser(String userId) async {
    try {
      final snap = await _firestore
          .doc('users/$userId/scores/${alltimePeriodId()}')
          .get();
      if (!snap.exists) return 0;
      return (snap.data()?['points'] ?? 0) as int;
    } catch (_) {
      return 0;
    }
  }

  // Like a task (owner gets a point). Ensures unique like per likerId via deterministic doc id.
  // Enforces a maximum of 10 votes per calendar day per user.
  Future<void> awardVote({
    required String ownerId,
    required String taskId,
    required String likerId,
    required String likerLocalDateKey,
  }) async {
    final voteRef = _firestore.doc(
      'tasks/$ownerId/tasks/$taskId/votes/$likerId',
    );
    final dailyVotesRef = _firestore.doc(
      'users/$likerId/daily_votes/$likerLocalDateKey',
    );

    final now = DateTime.now().toUtc();
    final weekId = weekPeriodId(now);
    final monthId = monthPeriodId(now);
    final allId = alltimePeriodId();

    // try the transaction, retry once on transient failure
    int attempts = 0;
    while (true) {
      try {
        await _firestore.runTransaction((tx) async {
          // 1. Check if already voted
          final voteSnap = await tx.get(voteRef);
          if (voteSnap.exists) {
            return; // already voted
          }

          // 2. Check daily quota limit
          final dailyVotesSnap = await tx.get(dailyVotesRef);
          int votesUsed = 0;
          if (dailyVotesSnap.exists) {
            votesUsed = (dailyVotesSnap.data()?['count'] ?? 0) as int;
          }

          if (votesUsed >= 10) {
            throw Exception('Daily vote limit reached');
          }

          // Record the vote
          tx.set(voteRef, {'createdAt': FieldValue.serverTimestamp()});

          // Increment daily quota constraint
          tx.set(dailyVotesRef, {
            'count': FieldValue.increment(1),
            'updatedAtUtc': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Award points to the task owner
          final weekRef = _firestore.doc('users/$ownerId/scores/$weekId');
          final monthRef = _firestore.doc('users/$ownerId/scores/$monthId');
          final allRef = _firestore.doc('users/$ownerId/scores/$allId');

          tx.set(weekRef, {
            'periodId': weekId,
            'points': FieldValue.increment(1),
            'updatedAtUtc': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          tx.set(monthRef, {
            'periodId': monthId,
            'points': FieldValue.increment(1),
            'updatedAtUtc': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          tx.set(allRef, {
            'periodId': allId,
            'points': FieldValue.increment(1),
            'updatedAtUtc': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        });

        // success
        break;
      } catch (e, st) {
        attempts++;
        debugPrint('awardVote transaction failed (attempt $attempts): $e\n$st');
        if (attempts > 1) {
          // give up and rethrow a descriptive error
          throw Exception('awardVote failed: $e');
        }
        // small backoff
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  // Stream daily votes used for UI counters
  Stream<int> watchDailyVotesUsed(String userId, String localDateKey) {
    return _firestore
        .doc('users/$userId/daily_votes/$localDateKey')
        .snapshots()
        .map((snap) => (snap.data()?['count'] ?? 0) as int);
  }

  // Stream list of userIds who voted on a task
  Stream<List<String>> watchTaskVotes(String ownerId, String taskId) {
    return _firestore
        .collection('tasks/$ownerId/tasks/$taskId/votes')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }

  // Revoke a previously recorded vote: remove vote doc, decrement owner points and liker daily count
  Future<void> revokeVote({
    required String ownerId,
    required String taskId,
    required String likerId,
    required String likerLocalDateKey,
  }) async {
    final voteRef = _firestore.doc(
      'tasks/$ownerId/tasks/$taskId/votes/$likerId',
    );
    final dailyVotesRef = _firestore.doc(
      'users/$likerId/daily_votes/$likerLocalDateKey',
    );

    final now = DateTime.now().toUtc();
    final weekId = weekPeriodId(now);
    final monthId = monthPeriodId(now);
    final allId = alltimePeriodId();

    await _firestore.runTransaction((tx) async {
      final voteSnap = await tx.get(voteRef);
      if (!voteSnap.exists) {
        return; // nothing to revoke
      }

      // delete the vote doc
      tx.delete(voteRef);

      // decrement dailyVotes count safely
      final dailySnap = await tx.get(dailyVotesRef);
      final current =
          (dailySnap.exists ? (dailySnap.data()?['count'] ?? 0) : 0) as int;
      if (current > 0) {
        tx.set(dailyVotesRef, {
          'count': FieldValue.increment(-1),
          'updatedAtUtc': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else if (dailySnap.exists) {
        // ensure non-negative
        tx.set(dailyVotesRef, {
          'count': 0,
          'updatedAtUtc': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // decrement owner's scores
      final weekRef = _firestore.doc('users/$ownerId/scores/$weekId');
      final monthRef = _firestore.doc('users/$ownerId/scores/$monthId');
      final allRef = _firestore.doc('users/$ownerId/scores/$allId');

      tx.set(weekRef, {
        'periodId': weekId,
        'points': FieldValue.increment(-1),
        'updatedAtUtc': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.set(monthRef, {
        'periodId': monthId,
        'points': FieldValue.increment(-1),
        'updatedAtUtc': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.set(allRef, {
        'periodId': allId,
        'points': FieldValue.increment(-1),
        'updatedAtUtc': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // Award for creating a task
  Future<void> awardTaskCreate({
    required String ownerId,
    int points = 2,
  }) async {
    final now = DateTime.now().toUtc();
    final weekId = weekPeriodId(now);
    final monthId = monthPeriodId(now);
    final allId = alltimePeriodId();

    await _firestore.runTransaction((tx) async {
      final weekRef = _firestore.doc('users/$ownerId/scores/$weekId');
      final monthRef = _firestore.doc('users/$ownerId/scores/$monthId');
      final allRef = _firestore.doc('users/$ownerId/scores/$allId');

      tx.set(weekRef, {
        'periodId': weekId,
        'points': FieldValue.increment(points),
        'updatedAtUtc': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.set(monthRef, {
        'periodId': monthId,
        'points': FieldValue.increment(points),
        'updatedAtUtc': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.set(allRef, {
        'periodId': allId,
        'points': FieldValue.increment(points),
        'updatedAtUtc': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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

      tx.set(weekRef, {
        'periodId': weekId,
        'points': FieldValue.increment(points),
        'updatedAtUtc': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.set(monthRef, {
        'periodId': monthId,
        'points': FieldValue.increment(points),
        'updatedAtUtc': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.set(allRef, {
        'periodId': allId,
        'points': FieldValue.increment(points),
        'updatedAtUtc': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // Award 1 point when user creates or updates a goal, once per hour (idempotent).
  Future<void> awardGoalUpdate({
    required String userId,
    DateTime? atUtc,
  }) async {
    final now = (atUtc ?? DateTime.now()).toUtc();
    final hourKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}';
    final markerRef = _firestore.doc('users/$userId/goalUpdateSlots/$hourKey');

    final weekId = weekPeriodId(now);
    final monthId = monthPeriodId(now);
    final allId = alltimePeriodId();

    try {
      await _firestore.runTransaction((tx) async {
        final markerSnap = await tx.get(markerRef);
        if (markerSnap.exists) return; // already awarded this hour

        tx.set(markerRef, {'createdAt': FieldValue.serverTimestamp()});

        final weekRef = _firestore.doc('users/$userId/scores/$weekId');
        final monthRef = _firestore.doc('users/$userId/scores/$monthId');
        final allRef = _firestore.doc('users/$userId/scores/$allId');

        for (final entry in [
          (weekRef, weekId),
          (monthRef, monthId),
          (allRef, allId),
        ]) {
          tx.set(entry.$1, {
            'periodId': entry.$2,
            'points': FieldValue.increment(1),
            'updatedAtUtc': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });
    } catch (e, st) {
      debugPrint('awardGoalUpdate failed: $e\n$st');
      rethrow;
    }
  }

  // Stream all score period docs for a user, sorted with alltime first then by date desc.
  Stream<List<Map<String, dynamic>>> watchAllScores(String userId) {
    return _firestore.collection('users/$userId/scores').snapshots().map((
      snap,
    ) {
      final docs = snap.docs.map((d) {
        final data = d.data();
        return {
          'periodId': d.id,
          'points': (data['points'] ?? 0) as int,
          'updatedAtUtc': data['updatedAtUtc'],
        };
      }).toList();
      docs.sort((a, b) {
        final aId = a['periodId'] as String;
        final bId = b['periodId'] as String;
        if (aId == 'alltime') return -1;
        if (bId == 'alltime') return 1;
        return bId.compareTo(aId); // lexicographic desc → newest first
      });
      return docs;
    });
  }

  // Query top N leaderboard entries for a period (collectionGroup on scores)
  Stream<List<Map<String, dynamic>>> streamTopScores({
    required String periodId,
    int limit = 50,
  }) {
    return _firestore
        .collectionGroup('scores')
        .where('periodId', isEqualTo: periodId)
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
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
  Future<List<Map<String, dynamic>>> getScoresForUsers({
    required String periodId,
    required Iterable<String> userIds,
  }) async {
    final results = <Map<String, dynamic>>[];
    final futures = userIds.map((userId) async {
      final docRef = _firestore.doc('users/$userId/scores/$periodId');
      final snap = await docRef.get();
      if (!snap.exists) {
        return null;
      }
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
