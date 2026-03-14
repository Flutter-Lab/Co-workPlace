class FriendRequest {
  const FriendRequest({
    required this.otherUserId,
    required this.createdAtUtc,
  });

  final String otherUserId;
  final DateTime createdAtUtc;

  Map<String, dynamic> toMap() {
    return {
      'otherUserId': otherUserId,
      'createdAtUtc': createdAtUtc.toIso8601String(),
    };
  }

  factory FriendRequest.fromMap(Map<String, dynamic> map) {
    return FriendRequest(
      otherUserId: map['otherUserId'] as String,
      createdAtUtc: DateTime.parse(map['createdAtUtc'] as String).toUtc(),
    );
  }
}
