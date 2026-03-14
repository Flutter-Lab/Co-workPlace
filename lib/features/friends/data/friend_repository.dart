import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coworkplace/features/friends/domain/friend_connection.dart';
import 'package:coworkplace/features/friends/domain/friend_request.dart';

class FriendRepository {
  FriendRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  CollectionReference<Map<String, dynamic>> _friends(String userId) {
    return _userDoc(userId).collection('friends');
  }

  CollectionReference<Map<String, dynamic>> _incomingRequests(String userId) {
    return _userDoc(userId).collection('incomingRequests');
  }

  CollectionReference<Map<String, dynamic>> _outgoingRequests(String userId) {
    return _userDoc(userId).collection('outgoingRequests');
  }

  Stream<List<FriendConnection>> watchFriends(String userId) {
    return _friends(userId)
        .orderBy('createdAtUtc', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return FriendConnection.fromMap({...doc.data(), 'friendUserId': doc.id});
          }).toList();
        });
  }

  Stream<List<FriendRequest>> watchIncomingRequests(String userId) {
    return _incomingRequests(userId)
        .orderBy('createdAtUtc', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return FriendRequest.fromMap({...doc.data(), 'otherUserId': doc.id});
          }).toList();
        });
  }

  Stream<List<FriendRequest>> watchOutgoingRequests(String userId) {
    return _outgoingRequests(userId)
        .orderBy('createdAtUtc', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return FriendRequest.fromMap({...doc.data(), 'otherUserId': doc.id});
          }).toList();
        });
  }

  Future<void> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
  }) async {
    if (fromUserId == toUserId) {
      throw ArgumentError('You cannot send a friend request to yourself.');
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final fromDoc = _userDoc(fromUserId);
    final toDoc = _userDoc(toUserId);
    final fromFriendDoc = _friends(fromUserId).doc(toUserId);
    final outgoingDoc = _outgoingRequests(fromUserId).doc(toUserId);
    final incomingDoc = _incomingRequests(toUserId).doc(fromUserId);

    await _firestore.runTransaction((transaction) async {
      final toSnapshot = await transaction.get(toDoc);
      if (!toSnapshot.exists) {
        throw StateError('User not found.');
      }

      final fromSnapshot = await transaction.get(fromDoc);
      if (!fromSnapshot.exists) {
        throw StateError('Your profile is not ready yet.');
      }

      final existingFriend = await transaction.get(fromFriendDoc);
      if (existingFriend.exists) {
        throw StateError('You are already friends.');
      }

      final existingOutgoing = await transaction.get(outgoingDoc);
      if (existingOutgoing.exists) {
        throw StateError('Friend request already sent.');
      }

      transaction.set(outgoingDoc, {
        'otherUserId': toUserId,
        'createdAtUtc': nowIso,
      });
      transaction.set(incomingDoc, {
        'otherUserId': fromUserId,
        'createdAtUtc': nowIso,
      });
    });
  }

  Future<void> acceptFriendRequest({
    required String userId,
    required String fromUserId,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final incomingDoc = _incomingRequests(userId).doc(fromUserId);
    final outgoingDoc = _outgoingRequests(fromUserId).doc(userId);
    final myFriendDoc = _friends(userId).doc(fromUserId);
    final theirFriendDoc = _friends(fromUserId).doc(userId);

    await _firestore.runTransaction((transaction) async {
      final incomingSnapshot = await transaction.get(incomingDoc);
      if (!incomingSnapshot.exists) {
        throw StateError('Friend request not found.');
      }

      transaction.set(myFriendDoc, {
        'friendUserId': fromUserId,
        'createdAtUtc': nowIso,
      });
      transaction.set(theirFriendDoc, {
        'friendUserId': userId,
        'createdAtUtc': nowIso,
      });
      transaction.delete(incomingDoc);
      transaction.delete(outgoingDoc);
    });
  }

  Future<void> rejectFriendRequest({
    required String userId,
    required String fromUserId,
  }) async {
    await _incomingRequests(userId).doc(fromUserId).delete();
    await _outgoingRequests(fromUserId).doc(userId).delete();
  }

  Future<void> cancelOutgoingRequest({
    required String userId,
    required String toUserId,
  }) async {
    await _outgoingRequests(userId).doc(toUserId).delete();
    await _incomingRequests(toUserId).doc(userId).delete();
  }

  Future<void> removeFriend({
    required String userId,
    required String friendUserId,
  }) async {
    await _firestore.runTransaction((transaction) async {
      transaction.delete(_friends(userId).doc(friendUserId));
      transaction.delete(_friends(friendUserId).doc(userId));
    });
  }
}
