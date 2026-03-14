enum FeedViewMode { list, grid }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.username,
    required this.timezone,
    required this.dayStartHour,
    required this.groupIds,
    required this.feedViewMode,
    this.activeGroupId,
    this.currentMode,
    this.isOnline = false,
    this.lastSeenAtUtc,
  });

  final String id;
  final String displayName;
  final String username;
  final String timezone;
  final int dayStartHour;
  final List<String> groupIds;
  final FeedViewMode feedViewMode;
  final String? activeGroupId;
  final UserCurrentMode? currentMode;
  final bool isOnline;
  final DateTime? lastSeenAtUtc;

  UserProfile copyWith({
    String? displayName,
    String? username,
    String? timezone,
    int? dayStartHour,
    List<String>? groupIds,
    FeedViewMode? feedViewMode,
    String? activeGroupId,
    UserCurrentMode? currentMode,
    bool? isOnline,
    DateTime? lastSeenAtUtc,
    bool clearActiveGroupId = false,
    bool clearCurrentMode = false,
    bool clearLastSeenAtUtc = false,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      timezone: timezone ?? this.timezone,
      dayStartHour: dayStartHour ?? this.dayStartHour,
      groupIds: groupIds ?? this.groupIds,
      feedViewMode: feedViewMode ?? this.feedViewMode,
      activeGroupId: clearActiveGroupId
          ? null
          : (activeGroupId ?? this.activeGroupId),
      currentMode: clearCurrentMode ? null : (currentMode ?? this.currentMode),
      isOnline: isOnline ?? this.isOnline,
      lastSeenAtUtc: clearLastSeenAtUtc
          ? null
          : (lastSeenAtUtc ?? this.lastSeenAtUtc),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'username': username,
      'timezone': timezone,
      'dayStartHour': dayStartHour,
      'groupIds': groupIds,
      'feedViewMode': feedViewMode.name,
      'activeGroupId': activeGroupId,
      'currentMode': currentMode?.toMap(),
      'isOnline': isOnline,
      'lastSeenAtUtc': lastSeenAtUtc?.toIso8601String(),
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
    final rawFeedViewMode = map['feedViewMode'] as String?;
    final parsedFeedViewMode = FeedViewMode.values.where((mode) {
      return mode.name == rawFeedViewMode;
    }).firstOrNull ?? FeedViewMode.list;
    final rawIsOnline = map['isOnline'];
    final parsedIsOnline = rawIsOnline is bool
        ? rawIsOnline
        : (rawIsOnline is num ? rawIsOnline != 0 : false);
    final rawLastSeenAtUtc = map['lastSeenAtUtc'] as String?;
    final rawUsername = (map['username'] as String?)?.trim();
    final fallbackDisplayName = (map['displayName'] as String?)?.trim() ?? '';

    return UserProfile(
      id: map['id'] as String,
      displayName: fallbackDisplayName,
      username: rawUsername?.isNotEmpty == true
          ? rawUsername!
          : _fallbackUsername(id: map['id'] as String, displayName: fallbackDisplayName),
      timezone: map['timezone'] as String,
      dayStartHour: parsedDayStartHour,
      groupIds: parsedGroupIds,
      feedViewMode: parsedFeedViewMode,
      activeGroupId: map['activeGroupId'] as String?,
      currentMode: map['currentMode'] == null
          ? null
          : UserCurrentMode.fromMap(map['currentMode'] as Map<String, dynamic>),
        isOnline: parsedIsOnline,
        lastSeenAtUtc: rawLastSeenAtUtc == null
          ? null
          : DateTime.parse(rawLastSeenAtUtc).toUtc(),
    );
  }

  static String _fallbackUsername({required String id, required String displayName}) {
    final normalizedDisplay = displayName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (normalizedDisplay.isNotEmpty) {
      return normalizedDisplay;
    }

    final safeId = id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return safeId.isEmpty ? 'user' : 'user_${safeId.substring(0, safeId.length > 8 ? 8 : safeId.length)}';
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
