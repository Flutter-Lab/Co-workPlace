enum GoalUnitType {
  min,
  pages,
  books,
  count,
  money,
  lessons,
  steps,
  kilometers,
  miles,
  workouts,
  calories,
  hours,
  custom,
}

class Goal {
  const Goal({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.unitType,
    required this.targetValue,
    required this.completedValue,
    required this.itemCount,
    this.isSimpleGoal = false,
    this.isArchived = false,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.startDateUtc,
    this.customUnitLabel,
    this.deadlineUtc,
  });

  final String id;
  final String ownerId;
  final String title;
  final GoalUnitType unitType;
  final String? customUnitLabel;
  final double targetValue;
  final double completedValue;
  final int itemCount;
  final bool isSimpleGoal;
  final bool isArchived;
  final DateTime startDateUtc;
  final DateTime? deadlineUtc;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  Goal copyWith({
    String? title,
    GoalUnitType? unitType,
    String? customUnitLabel,
    double? targetValue,
    double? completedValue,
    int? itemCount,
    bool? isSimpleGoal,
    bool? isArchived,
    DateTime? startDateUtc,
    DateTime? deadlineUtc,
    DateTime? updatedAtUtc,
    bool clearCustomUnitLabel = false,
    bool clearDeadlineUtc = false,
  }) {
    return Goal(
      id: id,
      ownerId: ownerId,
      title: title ?? this.title,
      unitType: unitType ?? this.unitType,
      customUnitLabel: clearCustomUnitLabel
          ? null
          : (customUnitLabel ?? this.customUnitLabel),
      targetValue: targetValue ?? this.targetValue,
      completedValue: completedValue ?? this.completedValue,
      itemCount: itemCount ?? this.itemCount,
      isSimpleGoal: isSimpleGoal ?? this.isSimpleGoal,
      isArchived: isArchived ?? this.isArchived,
      startDateUtc: startDateUtc ?? this.startDateUtc,
      deadlineUtc: clearDeadlineUtc ? null : (deadlineUtc ?? this.deadlineUtc),
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'title': title,
      'unitType': unitType.name,
      'customUnitLabel': customUnitLabel,
      'targetValue': targetValue,
      'completedValue': completedValue,
      'itemCount': itemCount,
      'isSimpleGoal': isSimpleGoal,
      'isArchived': isArchived,
      'startDateUtc': startDateUtc.toIso8601String(),
      'deadlineUtc': deadlineUtc?.toIso8601String(),
      'createdAtUtc': createdAtUtc.toIso8601String(),
      'updatedAtUtc': updatedAtUtc.toIso8601String(),
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    final rawUnitType = map['unitType'] as String?;
    // Legacy: 'minutes' was renamed to 'min'.
    final normalizedUnitType = rawUnitType == 'minutes' ? 'min' : rawUnitType;
    GoalUnitType parsedUnitType = GoalUnitType.count;
    for (final value in GoalUnitType.values) {
      if (value.name == normalizedUnitType) {
        parsedUnitType = value;
        break;
      }
    }

    return Goal(
      id: map['id'] as String,
      ownerId: map['ownerId'] as String,
      title: map['title'] as String,
      unitType: parsedUnitType,
      customUnitLabel: map['customUnitLabel'] as String?,
      targetValue: (map['targetValue'] as num?)?.toDouble() ?? 0,
      completedValue: (map['completedValue'] as num?)?.toDouble() ?? 0,
      itemCount: (map['itemCount'] as num?)?.toInt() ?? 0,
      isSimpleGoal: map['isSimpleGoal'] as bool? ?? false,
      isArchived: map['isArchived'] as bool? ?? false,
      startDateUtc: map['startDateUtc'] != null
          ? DateTime.parse(map['startDateUtc'] as String).toUtc()
          : DateTime.parse(map['createdAtUtc'] as String).toUtc(),
      deadlineUtc: map['deadlineUtc'] == null
          ? null
          : DateTime.parse(map['deadlineUtc'] as String).toUtc(),
      createdAtUtc: DateTime.parse(map['createdAtUtc'] as String).toUtc(),
      updatedAtUtc: DateTime.parse(map['updatedAtUtc'] as String).toUtc(),
    );
  }
}

extension GoalUnitTypeLabel on GoalUnitType {
  String get displayLabel {
    switch (this) {
      case GoalUnitType.min:
        return 'Min';
      case GoalUnitType.pages:
        return 'Pages';
      case GoalUnitType.books:
        return 'Books';
      case GoalUnitType.count:
        return 'Count';
      case GoalUnitType.money:
        return 'Money';
      case GoalUnitType.lessons:
        return 'Lessons';
      case GoalUnitType.steps:
        return 'Steps';
      case GoalUnitType.kilometers:
        return 'Kilometers';
      case GoalUnitType.miles:
        return 'Miles';
      case GoalUnitType.workouts:
        return 'Workouts';
      case GoalUnitType.calories:
        return 'Calories';
      case GoalUnitType.hours:
        return 'Hours';
      case GoalUnitType.custom:
        return 'Custom';
    }
  }
}
