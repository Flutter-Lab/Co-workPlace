import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coworkplace/features/groups/domain/group.dart';

class GroupRepository {
  GroupRepository(this._firestore);

  static const _inviteCodeLength = 6;
  static const _inviteCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final FirebaseFirestore _firestore;
  final Random _random = Random.secure();

  CollectionReference<Map<String, dynamic>> get _groups {
    return _firestore.collection('groups');
  }

  CollectionReference<Map<String, dynamic>> get _users {
    return _firestore.collection('users');
  }

  Stream<Group?> watchById(String groupId) {
    return _groups.doc(groupId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }

      return Group.fromMap({...data, 'id': snapshot.id});
    });
  }

  Future<Group> createGroup({required String name, required String userId}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Group name cannot be empty.');
    }

    final groupRef = _groups.doc();
    final inviteCode = await _generateUniqueInviteCode();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final group = Group(
      id: groupRef.id,
      name: trimmedName,
      code: inviteCode,
      createdBy: userId,
      memberIds: [userId],
    );

    await _firestore.runTransaction((transaction) async {
      transaction.set(groupRef, {
        ...group.toMap(),
        'createdAtUtc': nowIso,
        'updatedAtUtc': nowIso,
      });

      transaction.set(_users.doc(userId), {
        'groupIds': FieldValue.arrayUnion([group.id]),
        'activeGroupId': group.id,
      }, SetOptions(merge: true));
    });

    return group;
  }

  Future<Group> joinGroupByCode({
    required String inviteCode,
    required String userId,
  }) async {
    final code = _sanitizeInviteCode(inviteCode);
    if (code.length != _inviteCodeLength) {
      throw ArgumentError.value(
        inviteCode,
        'inviteCode',
        'Invite code must be $_inviteCodeLength characters.',
      );
    }

    final query = await _groups.where('code', isEqualTo: code).limit(1).get();
    if (query.docs.isEmpty) {
      throw StateError('Group code not found.');
    }

    final groupRef = query.docs.first.reference;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final joinedGroup = await _firestore.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupRef);
      final groupData = groupSnapshot.data();
      if (!groupSnapshot.exists || groupData == null) {
        throw StateError('Group no longer exists.');
      }

      final rawMemberIds = groupData['memberIds'];
      final memberIds = rawMemberIds is List<dynamic>
          ? List<String>.from(rawMemberIds)
          : <String>[];

      if (!memberIds.contains(userId)) {
        memberIds.add(userId);
      }

      transaction.update(groupRef, {
        'memberIds': memberIds,
        'updatedAtUtc': nowIso,
      });

      transaction.set(_users.doc(userId), {
        'groupIds': FieldValue.arrayUnion([groupRef.id]),
        'activeGroupId': groupRef.id,
      }, SetOptions(merge: true));

      return Group.fromMap({...groupData, 'id': groupRef.id, 'memberIds': memberIds});
    });

    return joinedGroup;
  }

  String _sanitizeInviteCode(String input) {
    return input.trim().toUpperCase().replaceAll(RegExp(r'\\s+'), '');
  }

  Future<String> _generateUniqueInviteCode() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final candidate = _generateInviteCode();
      final existing = await _groups.where('code', isEqualTo: candidate).limit(1).get();
      if (existing.docs.isEmpty) {
        return candidate;
      }
    }

    throw StateError('Could not generate a unique group code. Please try again.');
  }

  String _generateInviteCode() {
    final buffer = StringBuffer();
    for (var i = 0; i < _inviteCodeLength; i++) {
      final index = _random.nextInt(_inviteCodeAlphabet.length);
      buffer.write(_inviteCodeAlphabet[index]);
    }
    return buffer.toString();
  }
}
