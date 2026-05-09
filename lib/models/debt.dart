import 'dart:convert';

enum DebtDirection { owedToMe, iOwe }

class DebtPayment {
  final String id;
  double amount;
  DateTime date;
  String note;

  DebtPayment({
    required this.id,
    required this.amount,
    DateTime? date,
    this.note = '',
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory DebtPayment.fromJson(Map<String, dynamic> j) => DebtPayment(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        note: j['note'] as String? ?? '',
      );
}

class Debt {
  final String id;
  String party;
  DebtDirection direction;
  double originalAmount;
  DateTime? dueDate;
  String notes;
  DateTime createdAt;
  List<DebtPayment> payments;

  Debt({
    required this.id,
    required this.party,
    required this.direction,
    required this.originalAmount,
    this.dueDate,
    this.notes = '',
    DateTime? createdAt,
    List<DebtPayment>? payments,
  })  : createdAt = createdAt ?? DateTime.now(),
        payments = payments ?? [];

  double get totalPaid =>
      payments.fold(0.0, (sum, p) => sum + p.amount);

  double get remaining => (originalAmount - totalPaid).clamp(0, double.infinity);

  bool get isPaid => remaining <= 0.0001;

  /// red / yellow / green status based on due date and payment state
  DebtStatus get status {
    if (isPaid) return DebtStatus.paid;
    if (dueDate == null) return DebtStatus.upcoming;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    if (due.isBefore(today)) return DebtStatus.overdue;
    final diff = due.difference(today).inDays;
    if (diff <= 3) return DebtStatus.dueSoon;
    return DebtStatus.upcoming;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'party': party,
        'direction': direction.name,
        'originalAmount': originalAmount,
        'dueDate': dueDate?.toIso8601String(),
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'payments': payments.map((p) => p.toJson()).toList(),
      };

  factory Debt.fromJson(Map<String, dynamic> j) => Debt(
        id: j['id'] as String,
        party: j['party'] as String,
        direction:
            DebtDirection.values.firstWhere((d) => d.name == j['direction']),
        originalAmount: (j['originalAmount'] as num).toDouble(),
        dueDate: j['dueDate'] == null
            ? null
            : DateTime.parse(j['dueDate'] as String),
        notes: j['notes'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        payments: ((j['payments'] as List?) ?? const [])
            .map((p) => DebtPayment.fromJson(p as Map<String, dynamic>))
            .toList(),
      );

  String toRawJson() => jsonEncode(toJson());
  factory Debt.fromRawJson(String s) =>
      Debt.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

enum DebtStatus { paid, upcoming, dueSoon, overdue }
