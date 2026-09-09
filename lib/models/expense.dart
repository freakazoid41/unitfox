import 'dart:typed_data';

class Expense {
  final int id;
  final String category;
  final String description;
  final int amount; // minor units (cents)
  final String currency; // 'EUR' | 'USD' | 'TRY' ...
  final int? accountId;
  final Uint8List? attachment;
  final String attachmentName;
  final int? staffId; // set when this is a salary payment for a crew member
  final String salaryMonth; // 'YYYY-MM' when a salary payment
  final DateTime date;

  const Expense({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    this.currency = 'EUR',
    this.accountId,
    this.attachment,
    this.attachmentName = '',
    this.staffId,
    this.salaryMonth = '',
    required this.date,
  });

  factory Expense.fromRow(Map<String, Object?> row) => Expense(
        id: row['id'] as int,
        category: row['category'] as String,
        description: (row['description'] as String?) ?? '',
        amount: ((row['amount'] as num?) ?? 0).toInt(),
        currency: (row['currency'] as String?) ?? 'EUR',
        accountId: row['account_id'] as int?,
        attachment: row['attachment'] as Uint8List?,
        attachmentName: (row['attachment_name'] as String?) ?? '',
        staffId: row['staff_id'] as int?,
        salaryMonth: (row['salary_month'] as String?) ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
      );
}