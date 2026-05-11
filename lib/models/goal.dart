import 'dart:convert';

class Goal {
  final String id;
  String name;
  String emoji;

  /// Optional second emoji shown as a small accent on top of the primary one.
  /// Empty string means "single emoji only".
  String emoji2;
  double? targetAmount;
  String notes;
  DateTime createdAt;
  DateTime? completedAt;
  int sortOrder;

  /// Milestone tracker so we don't keep firing the same congrats notification.
  /// Each entry is a percentage threshold the user has already been notified
  /// about (e.g. {25, 50, 75, 100}).
  Set<int> notifiedMilestones;

  Goal({
    required this.id,
    required this.name,
    this.emoji = '🎯',
    this.emoji2 = '',
    this.targetAmount,
    this.notes = '',
    DateTime? createdAt,
    this.completedAt,
    this.sortOrder = 0,
    Set<int>? notifiedMilestones,
  })  : createdAt = createdAt ?? DateTime.now(),
        notifiedMilestones = notifiedMilestones ?? <int>{};

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'emoji2': emoji2,
        'targetAmount': targetAmount,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'sortOrder': sortOrder,
        'notifiedMilestones': notifiedMilestones.toList(),
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String? ?? '🎯',
        emoji2: j['emoji2'] as String? ?? '',
        targetAmount: (j['targetAmount'] as num?)?.toDouble(),
        notes: j['notes'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        completedAt: j['completedAt'] == null
            ? null
            : DateTime.parse(j['completedAt'] as String),
        sortOrder: j['sortOrder'] as int? ?? 0,
        notifiedMilestones: ((j['notifiedMilestones'] as List?) ?? const [])
            .map((e) => e as int)
            .toSet(),
      );

  String toRawJson() => jsonEncode(toJson());
  factory Goal.fromRawJson(String s) =>
      Goal.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
