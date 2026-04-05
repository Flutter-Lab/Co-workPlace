enum GoalUnitType {
  minutes,
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
    required this.createdAtUtc,
    required this.updatedAtUtc,
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
      'deadlineUtc': deadlineUtc?.toIso8601String(),
      'createdAtUtc': createdAtUtc.toIso8601String(),
      'updatedAtUtc': updatedAtUtc.toIso8601String(),
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    final rawUnitType = map['unitType'] as String?;
    GoalUnitType parsedUnitType = GoalUnitType.count;
    for (final value in GoalUnitType.values) {
      if (value.name == rawUnitType) {
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
      case GoalUnitType.minutes:
        return 'Minutes';
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
