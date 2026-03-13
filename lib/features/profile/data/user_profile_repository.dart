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

  Stream<List<UserProfile>> watchByGroupId(String groupId) {
    return _users.where('groupIds', arrayContains: groupId).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            return UserProfile.fromMap({...data, 'id': doc.id});
          })
          .toList();
    });
  }

  Future<void> upsert(UserProfile profile) async {
    await _users.doc(profile.id).set(profile.toMap(), SetOptions(merge: true));
  }
}
