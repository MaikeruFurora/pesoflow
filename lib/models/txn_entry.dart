import 'dart:convert';

enum TxnType { deposit, withdrawal }

class TxnEntry {
  final String id;
  final String goalId;
  double amount;
  TxnType type;
  String note;
  DateTime date;

  TxnEntry({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.type,
    this.note = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  double get signedAmount => type == TxnType.deposit ? amount : -amount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'goalId': goalId,
        'amount': amount,
        'type': type.name,
        'note': note,
        'date': date.toIso8601String(),
      };

  factory TxnEntry.fromJson(Map<String, dynamic> j) => TxnEntry(
        id: j['id'] as String,
        goalId: j['goalId'] as String,
        amount: (j['amount'] as num).toDouble(),
        type: TxnType.values.firstWhere((t) => t.name == j['type']),
        note: j['note'] as String? ?? '',
        date: DateTime.parse(j['date'] as String),
      );

  String toRawJson() => jsonEncode(toJson());
  factory TxnEntry.fromRawJson(String s) =>
      TxnEntry.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
