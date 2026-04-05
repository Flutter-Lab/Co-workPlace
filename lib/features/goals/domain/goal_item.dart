enum GoalItemStatus { active, completed }

class GoalItem {
  const GoalItem({
    required this.id,
    required this.goalId,
    required this.name,
    required this.totalUnits,
    required this.completedUnits,
    required this.status,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.note,
  });

  final String id;
  final String goalId;
  final String name;
  final double totalUnits;
  final double completedUnits;
  final GoalItemStatus status;
  final String? note;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  double get progressPercent {
    if (totalUnits <= 0) {
      return 0;
    }
    return ((completedUnits / totalUnits) * 100).clamp(0, 100).toDouble();
  }

  GoalItem copyWith({
    String? name,
    double? totalUnits,
    double? completedUnits,
    GoalItemStatus? status,
    String? note,
    DateTime? updatedAtUtc,
    bool clearNote = false,
  }) {
    return GoalItem(
      id: id,
      goalId: goalId,
      name: name ?? this.name,
      totalUnits: totalUnits ?? this.totalUnits,
      completedUnits: completedUnits ?? this.completedUnits,
      status: status ?? this.status,
      note: clearNote ? null : (note ?? this.note),
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goalId': goalId,
      'name': name,
      'totalUnits': totalUnits,
      'completedUnits': completedUnits,
      'status': status.name,
      'note': note,
      'createdAtUtc': createdAtUtc.toIso8601String(),
      'updatedAtUtc': updatedAtUtc.toIso8601String(),
    };
  }

  factory GoalItem.fromMap(Map<String, dynamic> map) {
    final rawStatus = map['status'] as String?;
    GoalItemStatus parsedStatus = GoalItemStatus.active;
    for (final value in GoalItemStatus.values) {
      if (value.name == rawStatus) {
        parsedStatus = value;
        break;
      }
    }

    return GoalItem(
      id: map['id'] as String,
      goalId: map['goalId'] as String,
      name: map['name'] as String,
      totalUnits: (map['totalUnits'] as num?)?.toDouble() ?? 0,
      completedUnits: (map['completedUnits'] as num?)?.toDouble() ?? 0,
      status: parsedStatus,
      note: map['note'] as String?,
      createdAtUtc: DateTime.parse(map['createdAtUtc'] as String).toUtc(),
      updatedAtUtc: DateTime.parse(map['updatedAtUtc'] as String).toUtc(),
    );
  }
}
