import 'dart:convert';

enum DebtDirection { owedToMe, iOwe }

class DebtPayment {
  final String id;
  double amount;
  DateTime date;
  String note;

  /// Optional wallet this payment was deposited to / drawn from.
  String? walletId;

  /// The mirrored WalletTxn id (so we can keep them in sync on edit/delete).
  String? linkedWalletTxnId;

  DebtPayment({
    required this.id,
    required this.amount,
    DateTime? date,
    this.note = '',
    this.walletId,
    this.linkedWalletTxnId,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        'walletId': walletId,
        'linkedWalletTxnId': linkedWalletTxnId,
      };

  factory DebtPayment.fromJson(Map<String, dynamic> j) => DebtPayment(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        note: j['note'] as String? ?? '',
        walletId: j['walletId'] as String?,
        linkedWalletTxnId: j['linkedWalletTxnId'] as String?,
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

  /// Optional wallet the principal flowed through when the debt was opened.
  /// - iOwe: borrowed money lands in this wallet (income)
  /// - owedToMe: lent money leaves this wallet (expense)
  String? walletId;

  /// Mirror id of the wallet txn created for the principal, so we can keep
  /// them in sync on edit/delete.
  String? linkedWalletTxnId;

  Debt({
    required this.id,
    required this.party,
    required this.direction,
    required this.originalAmount,
    this.dueDate,
    this.notes = '',
    DateTime? createdAt,
    List<DebtPayment>? payments,
    this.walletId,
    this.linkedWalletTxnId,
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
        'walletId': walletId,
        'linkedWalletTxnId': linkedWalletTxnId,
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
        walletId: j['walletId'] as String?,
        linkedWalletTxnId: j['linkedWalletTxnId'] as String?,
      );

  String toRawJson() => jsonEncode(toJson());
  factory Debt.fromRawJson(String s) =>
      Debt.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

enum DebtStatus { paid, upcoming, dueSoon, overdue }
