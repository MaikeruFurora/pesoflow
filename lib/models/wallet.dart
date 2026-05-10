import 'dart:convert';

enum WalletCategory {
  bank,
  ewallet,
  crypto,
  cash,
  investment,
  savings,
  other,
}

extension WalletCategoryX on WalletCategory {
  String get label {
    switch (this) {
      case WalletCategory.bank:
        return 'Bank';
      case WalletCategory.ewallet:
        return 'E-wallet';
      case WalletCategory.crypto:
        return 'Crypto';
      case WalletCategory.cash:
        return 'Cash';
      case WalletCategory.investment:
        return 'Investment';
      case WalletCategory.savings:
        return 'Savings';
      case WalletCategory.other:
        return 'Other';
    }
  }
}

class Wallet {
  final String id;
  String name;
  WalletCategory category;
  String emoji;
  int colorValue;

  /// Optional second color for a gradient. 0 means "use a darker shade of
  /// colorValue" (single-color mode).
  int colorValue2;
  double openingBalance;
  String notes;
  DateTime createdAt;
  int sortOrder;
  bool archived;
  bool isVault;
  String accountNumber;

  /// Filename of the QR image stored in app docs (under wallet_qr/), e.g.
  /// "<walletId>.jpg". Empty string when no QR is attached.
  String qrFileName;

  Wallet({
    required this.id,
    required this.name,
    this.category = WalletCategory.bank,
    this.emoji = '💳',
    this.colorValue = 0xFF2BB3A4,
    this.colorValue2 = 0,
    this.openingBalance = 0,
    this.notes = '',
    DateTime? createdAt,
    this.sortOrder = 0,
    this.archived = false,
    this.isVault = false,
    this.accountNumber = '',
    this.qrFileName = '',
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'emoji': emoji,
        'colorValue': colorValue,
        'colorValue2': colorValue2,
        'openingBalance': openingBalance,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'sortOrder': sortOrder,
        'archived': archived,
        'isVault': isVault,
        'accountNumber': accountNumber,
        'qrFileName': qrFileName,
      };

  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
        id: j['id'] as String,
        name: j['name'] as String,
        category: WalletCategory.values.firstWhere(
          (c) => c.name == j['category'],
          orElse: () => WalletCategory.other,
        ),
        emoji: j['emoji'] as String? ?? '💳',
        colorValue: j['colorValue'] as int? ?? 0xFF2BB3A4,
        colorValue2: j['colorValue2'] as int? ?? 0,
        openingBalance: (j['openingBalance'] as num?)?.toDouble() ?? 0,
        notes: j['notes'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        sortOrder: j['sortOrder'] as int? ?? 0,
        archived: j['archived'] as bool? ?? false,
        isVault: j['isVault'] as bool? ?? false,
        accountNumber: j['accountNumber'] as String? ?? '',
        qrFileName: j['qrFileName'] as String? ?? '',
      );

  String toRawJson() => jsonEncode(toJson());
  factory Wallet.fromRawJson(String s) =>
      Wallet.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
