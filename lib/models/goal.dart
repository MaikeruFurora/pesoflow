import 'dart:convert';

class Goal {
  final String id;
  String name;
  String emoji;
  double? targetAmount;
  String notes;
  DateTime createdAt;
  DateTime? completedAt;
  int sortOrder;

  Goal({
    required this.id,
    required this.name,
    this.emoji = '🎯',
    this.targetAmount,
    this.notes = '',
    DateTime? createdAt,
    this.completedAt,
    this.sortOrder = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'targetAmount': targetAmount,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'sortOrder': sortOrder,
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String? ?? '🎯',
        targetAmount: (j['targetAmount'] as num?)?.toDouble(),
        notes: j['notes'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        completedAt: j['completedAt'] == null
            ? null
            : DateTime.parse(j['completedAt'] as String),
        sortOrder: j['sortOrder'] as int? ?? 0,
      );

  String toRawJson() => jsonEncode(toJson());
  factory Goal.fromRawJson(String s) =>
      Goal.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
