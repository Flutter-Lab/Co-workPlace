class CurrentModePreset {
  const CurrentModePreset({
    required this.id,
    required this.label,
    required this.sortOrder,
    this.icon,
  });

  final String id;
  final String label;
  final int sortOrder;
  final String? icon;

  Map<String, dynamic> toMap() {
    return {'id': id, 'label': label, 'sortOrder': sortOrder, 'icon': icon};
  }

  factory CurrentModePreset.fromMap(Map<String, dynamic> map) {
    return CurrentModePreset(
      id: map['id'] as String,
      label: map['label'] as String,
      sortOrder: map['sortOrder'] as int,
      icon: map['icon'] as String?,
    );
  }
}
