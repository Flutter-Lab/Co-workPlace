class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.timezone,
    required this.dayStartHour,
    required this.groupIds,
    this.activeGroupId,
    this.currentMode,
  });

  final String id;
  final String displayName;
  final String timezone;
  final int dayStartHour;
  final List<String> groupIds;
  final String? activeGroupId;
  final UserCurrentMode? currentMode;

  UserProfile copyWith({
    String? displayName,
    String? timezone,
    int? dayStartHour,
    List<String>? groupIds,
    String? activeGroupId,
    UserCurrentMode? currentMode,
    bool clearActiveGroupId = false,
    bool clearCurrentMode = false,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      timezone: timezone ?? this.timezone,
      dayStartHour: dayStartHour ?? this.dayStartHour,
      groupIds: groupIds ?? this.groupIds,
      activeGroupId: clearActiveGroupId
          ? null
          : (activeGroupId ?? this.activeGroupId),
      currentMode: clearCurrentMode ? null : (currentMode ?? this.currentMode),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'timezone': timezone,
      'dayStartHour': dayStartHour,
      'groupIds': groupIds,
      'activeGroupId': activeGroupId,
      'currentMode': currentMode?.toMap(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final rawGroupIds = map['groupIds'];
    final parsedGroupIds = rawGroupIds is List<dynamic>
        ? List<String>.from(rawGroupIds)
        : <String>[];

    final rawDayStartHour = map['dayStartHour'];
    final parsedDayStartHour = rawDayStartHour is int
        ? rawDayStartHour
        : (rawDayStartHour is num ? rawDayStartHour.toInt() : 4);

    return UserProfile(
      id: map['id'] as String,
      displayName: map['displayName'] as String,
      timezone: map['timezone'] as String,
      dayStartHour: parsedDayStartHour,
      groupIds: parsedGroupIds,
      activeGroupId: map['activeGroupId'] as String?,
      currentMode: map['currentMode'] == null
          ? null
          : UserCurrentMode.fromMap(map['currentMode'] as Map<String, dynamic>),
    );
  }
}

class UserCurrentMode {
  const UserCurrentMode({
    required this.label,
    required this.updatedAtUtc,
    this.presetId,
  });

  final String label;
  final DateTime updatedAtUtc;
  final String? presetId;

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'updatedAtUtc': updatedAtUtc.toIso8601String(),
      'presetId': presetId,
    };
  }

  factory UserCurrentMode.fromMap(Map<String, dynamic> map) {
    return UserCurrentMode(
      label: map['label'] as String,
      updatedAtUtc: DateTime.parse(map['updatedAtUtc'] as String).toUtc(),
      presetId: map['presetId'] as String?,
    );
  }
}
