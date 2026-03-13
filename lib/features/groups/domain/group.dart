class Group {
  const Group({
    required this.id,
    required this.name,
    required this.code,
    required this.createdBy,
    required this.memberIds,
  });

  final String id;
  final String name;
  final String code;
  final String createdBy;
  final List<String> memberIds;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'createdBy': createdBy,
      'memberIds': memberIds,
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'] as String,
      name: map['name'] as String,
      code: map['code'] as String,
      createdBy: map['createdBy'] as String,
      memberIds: List<String>.from(map['memberIds'] as List<dynamic>),
    );
  }
}
