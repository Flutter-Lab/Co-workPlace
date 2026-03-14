import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';

class UserProfileRepository {
  UserProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users {
    return _firestore.collection('users');
  }

  Future<UserProfile?> getById(String userId) async {
    final snapshot = await _users.doc(userId).get();
    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    return UserProfile.fromMap({...data, 'id': userId});
  }

  Future<List<UserProfile>> getByIds(Iterable<String> userIds) async {
    final seen = <String>{};
    final orderedIds = userIds.where(seen.add).toList();
    final results = await Future.wait(orderedIds.map(getById));
    return results.whereType<UserProfile>().toList();
  }

  /// Streams live updates for a set of user profiles.
  /// Uses a single Firestore [whereIn] query (max 30 ids).
  Stream<List<UserProfile>> watchByIds(Iterable<String> userIds) {
    final seen = <String>{};
    final orderedIds = userIds.where(seen.add).toList();
    if (orderedIds.isEmpty) {
      return Stream.value([]);
    }
    return _users
        .where(FieldPath.documentId, whereIn: orderedIds)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserProfile.fromMap({...doc.data(), 'id': doc.id}))
              .toList(),
        );
  }

  Future<UserProfile?> findByUsername(String username) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    final snapshot = await _users.where('username', isEqualTo: normalized).limit(1).get();
    if (snapshot.docs.isEmpty) {
      return null;
    }

    final doc = snapshot.docs.first;
    return UserProfile.fromMap({...doc.data(), 'id': doc.id});
  }

  Future<void> upsert(UserProfile profile) async {
    await _users.doc(profile.id).set(profile.toMap(), SetOptions(merge: true));
  }

  Future<void> setPresence({
    required String userId,
    required bool isOnline,
    DateTime? seenAtUtc,
  }) async {
    final nowUtc = (seenAtUtc ?? DateTime.now().toUtc()).toIso8601String();
    await _users.doc(userId).set({
      'isOnline': isOnline,
      'lastSeenAtUtc': nowUtc,
    }, SetOptions(merge: true));
  }
}
