enum TaskType { daily, oneTime }

class Task {
  const Task({
    required this.id,
    required this.groupId,
    required this.ownerId,
    required this.title,
    required this.type,
    required this.active,
    required this.createdAtUtc,
    required this.modifiedAtUtc,
    this.description,
    this.localTimeMinutes,
    this.scheduledTimeUtc,
    this.daysOfWeek,
    this.goalCount,
    this.goalUnit,
  });

  final String id;
  final String groupId;
  final String ownerId;
  final String title;
  final String? description;
  final TaskType type;
  final int? localTimeMinutes;
  final DateTime? scheduledTimeUtc;
  final List<int>? daysOfWeek;
  final double? goalCount;
  final String? goalUnit;
  final bool active;
  final DateTime createdAtUtc;
  final DateTime modifiedAtUtc;

  Task copyWith({
    String? title,
    String? description,
    TaskType? type,
    int? localTimeMinutes,
    DateTime? scheduledTimeUtc,
    List<int>? daysOfWeek,
    double? goalCount,
    String? goalUnit,
    bool? active,
    DateTime? modifiedAtUtc,
    bool clearDescription = false,
    bool clearLocalTimeMinutes = false,
    bool clearScheduledTimeUtc = false,
    bool clearDaysOfWeek = false,
    bool clearGoalCount = false,
    bool clearGoalUnit = false,
  }) {
    return Task(
      id: id,
      groupId: groupId,
      ownerId: ownerId,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      type: type ?? this.type,
      localTimeMinutes: clearLocalTimeMinutes
          ? null
          : (localTimeMinutes ?? this.localTimeMinutes),
      scheduledTimeUtc: clearScheduledTimeUtc
          ? null
          : (scheduledTimeUtc ?? this.scheduledTimeUtc),
      daysOfWeek: clearDaysOfWeek ? null : (daysOfWeek ?? this.daysOfWeek),
        goalCount: clearGoalCount ? null : (goalCount ?? this.goalCount),
        goalUnit: clearGoalUnit ? null : (goalUnit ?? this.goalUnit),
      active: active ?? this.active,
      createdAtUtc: createdAtUtc,
      modifiedAtUtc: modifiedAtUtc ?? this.modifiedAtUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'type': type.name,
      'localTimeMinutes': localTimeMinutes,
      'scheduledTimeUtc': scheduledTimeUtc?.toIso8601String(),
      'daysOfWeek': daysOfWeek,
      'goalCount': goalCount,
      'goalUnit': goalUnit,
      'active': active,
      'createdAtUtc': createdAtUtc.toIso8601String(),
      'modifiedAtUtc': modifiedAtUtc.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      ownerId: map['ownerId'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      type: _taskTypeFromString(map['type'] as String),
      localTimeMinutes: map['localTimeMinutes'] as int?,
      scheduledTimeUtc: map['scheduledTimeUtc'] == null
          ? null
          : DateTime.parse(map['scheduledTimeUtc'] as String).toUtc(),
      daysOfWeek: map['daysOfWeek'] == null
          ? null
          : List<int>.from(map['daysOfWeek'] as List<dynamic>),
        goalCount: (map['goalCount'] as num?)?.toDouble(),
        goalUnit: map['goalUnit'] as String?,
      active: map['active'] as bool,
      createdAtUtc: DateTime.parse(map['createdAtUtc'] as String).toUtc(),
      modifiedAtUtc: DateTime.parse(map['modifiedAtUtc'] as String).toUtc(),
    );
  }
}

TaskType _taskTypeFromString(String value) {
  switch (value) {
    case 'daily':
      return TaskType.daily;
    case 'oneTime':
      return TaskType.oneTime;
    default:
      throw ArgumentError.value(value, 'value', 'Unknown task type');
  }
}
