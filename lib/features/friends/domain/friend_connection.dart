class FriendConnection {
  const FriendConnection({
    required this.friendUserId,
    required this.createdAtUtc,
  });

  final String friendUserId;
  final DateTime createdAtUtc;

  Map<String, dynamic> toMap() {
    return {
      'friendUserId': friendUserId,
      'createdAtUtc': createdAtUtc.toIso8601String(),
    };
  }

  factory FriendConnection.fromMap(Map<String, dynamic> map) {
    return FriendConnection(
      friendUserId: map['friendUserId'] as String,
      createdAtUtc: DateTime.parse(map['createdAtUtc'] as String).toUtc(),
    );
  }
}
