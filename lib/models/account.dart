/// A holding place for money — a bank account or local cash.
class Account {
  final int id;
  final int propertyId;
  final String name;
  final String kind; // 'bank' | 'cash'
  final String bankName;
  final String iban;
  final String currency; // 'EUR' | 'USD' | 'TRY'
  final int openingBalance; // minor units (cents)

  const Account({
    required this.id,
    this.propertyId = 0,
    required this.name,
    required this.kind,
    this.bankName = '',
    this.iban = '',
    required this.currency,
    this.openingBalance = 0,
  });

  static const List<String> currencies = ['EUR', 'USD', 'TRY', 'GBP', 'INR', 'RUB'];

  Account copyWith({
    int? id,
    int? propertyId,
    String? name,
    String? kind,
    String? bankName,
    String? iban,
    String? currency,
    int? openingBalance,
  }) =>
      Account(
        id: id ?? this.id,
        propertyId: propertyId ?? this.propertyId,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        bankName: bankName ?? this.bankName,
        iban: iban ?? this.iban,
        currency: currency ?? this.currency,
        openingBalance: openingBalance ?? this.openingBalance,
      );

  factory Account.fromRow(Map<String, Object?> row) => Account(
        id: row['id'] as int,
        propertyId: ((row['property_id'] as num?) ?? 0).toInt(),
        name: (row['name'] as String?) ?? '',
        kind: (row['kind'] as String?) ?? 'bank',
        bankName: (row['bank_name'] as String?) ?? '',
        iban: (row['iban'] as String?) ?? '',
        currency: (row['currency'] as String?) ?? 'EUR',
        openingBalance: ((row['opening_balance'] as num?) ?? 0).toInt(),
      );

  Map<String, Object?> toRow({int? propertyId}) => {
        'property_id': propertyId ?? this.propertyId,
        'name': name,
        'kind': kind,
        'bank_name': bankName,
        'iban': iban,
        'currency': currency,
        'opening_balance': openingBalance,
      };
}