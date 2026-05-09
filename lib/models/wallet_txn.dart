import 'dart:convert';

enum WalletTxnType { income, expense, transferIn, transferOut }

class WalletTxn {
  final String id;
  final String walletId;
  WalletTxnType type;
  double amount;
  String category;
  String note;
  DateTime date;

  /// Pair id for transfers — same uuid on both transferOut + transferIn rows.
  String? linkedTxnId;

  WalletTxn({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    this.category = '',
    this.note = '',
    DateTime? date,
    this.linkedTxnId,
  }) : date = date ?? DateTime.now();

  /// Signed delta this transaction has on the wallet's balance.
  double get signedAmount {
    switch (type) {
      case WalletTxnType.income:
      case WalletTxnType.transferIn:
        return amount;
      case WalletTxnType.expense:
      case WalletTxnType.transferOut:
        return -amount;
    }
  }

  bool get isTransfer =>
      type == WalletTxnType.transferIn || type == WalletTxnType.transferOut;

  Map<String, dynamic> toJson() => {
        'id': id,
        'walletId': walletId,
        'type': type.name,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date.toIso8601String(),
        'linkedTxnId': linkedTxnId,
      };

  factory WalletTxn.fromJson(Map<String, dynamic> j) => WalletTxn(
        id: j['id'] as String,
        walletId: j['walletId'] as String,
        type: WalletTxnType.values.firstWhere((t) => t.name == j['type']),
        amount: (j['amount'] as num).toDouble(),
        category: j['category'] as String? ?? '',
        note: j['note'] as String? ?? '',
        date: DateTime.parse(j['date'] as String),
        linkedTxnId: j['linkedTxnId'] as String?,
      );

  String toRawJson() => jsonEncode(toJson());
  factory WalletTxn.fromRawJson(String s) =>
      WalletTxn.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
