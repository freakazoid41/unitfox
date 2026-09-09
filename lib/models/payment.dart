import 'dart:typed_data';

/// The kind of income a payment represents.
abstract final class PaymentType {
  static const aidat = 'Aidat';
  static const fuel = 'Yakıt';
  static const other = 'Diğer';
  static const values = [aidat, fuel, other];
}

/// A recorded payment received for a unit against a given month.
class Payment {
  final int id;
  final int unitId;
  final String month; // 'YYYY-MM'
  final String type; // 'Aidat' | 'Yakıt' | 'Diğer'
  final int amount; // minor units (cents) of [currency]
  final String currency; // 'EUR' | 'USD' | 'TRY' ...
  final int? accountId;
  final String note;
  final Uint8List? attachment;
  final String attachmentName;
  final DateTime paidAt;

  const Payment({
    required this.id,
    required this.unitId,
    required this.month,
    required this.type,
    required this.amount,
    this.currency = 'EUR',
    this.accountId,
    this.note = '',
    this.attachment,
    this.attachmentName = '',
    required this.paidAt,
  });

  factory Payment.fromRow(Map<String, Object?> row) => Payment(
        id: row['id'] as int,
        unitId: row['unit_id'] as int,
        month: row['month'] as String,
        type: (row['type'] as String?) ?? 'Aidat',
        amount: ((row['amount'] as num?) ?? 0).toInt(),
        currency: (row['currency'] as String?) ?? 'EUR',
        accountId: row['account_id'] as int?,
        note: (row['note'] as String?) ?? '',
        attachment: row['attachment'] as Uint8List?,
        attachmentName: (row['attachment_name'] as String?) ?? '',
        paidAt: DateTime.fromMillisecondsSinceEpoch(row['paid_at'] as int),
      );
}

/// A posted monthly charge against a unit (rent, heating, other).
class UnitCharge {
  final int id;
  final int unitId;
  final String month;
  final int amount; // minor units (cents)
  final String note;

  const UnitCharge({
    required this.id,
    required this.unitId,
    required this.month,
    required this.amount,
    this.note = '',
  });

  factory UnitCharge.fromRow(Map<String, Object?> row) => UnitCharge(
        id: row['id'] as int,
        unitId: row['unit_id'] as int,
        month: row['month'] as String,
        amount: ((row['amount'] as num?) ?? 0).toInt(),
        note: (row['note'] as String?) ?? '',
      );
}