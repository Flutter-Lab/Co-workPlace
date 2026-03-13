enum CompletionStatus { done, skipped }

class TaskCompletion {
  const TaskCompletion({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.localDateKey,
    required this.completedAtUtc,
    required this.status,
    this.notes,
  });

  final String id;
  final String taskId;
  final String userId;
  final String localDateKey;
  final DateTime completedAtUtc;
  final CompletionStatus status;
  final String? notes;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'userId': userId,
      'localDateKey': localDateKey,
      'completedAtUtc': completedAtUtc.toIso8601String(),
      'status': status.name,
      'notes': notes,
    };
  }

  factory TaskCompletion.fromMap(Map<String, dynamic> map) {
    return TaskCompletion(
      id: map['id'] as String,
      taskId: map['taskId'] as String,
      userId: map['userId'] as String,
      localDateKey: map['localDateKey'] as String,
      completedAtUtc: DateTime.parse(map['completedAtUtc'] as String).toUtc(),
      status: _completionStatusFromString(map['status'] as String),
      notes: map['notes'] as String?,
    );
  }
}

CompletionStatus _completionStatusFromString(String value) {
  switch (value) {
    case 'done':
      return CompletionStatus.done;
    case 'skipped':
      return CompletionStatus.skipped;
    default:
      throw ArgumentError.value(value, 'value', 'Unknown completion status');
  }
}
