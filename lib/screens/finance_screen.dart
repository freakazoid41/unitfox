// ignore_for_file: sort_child_properties_last
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/account_store.dart';
import '../data/expense_store.dart';
import '../data/fx_store.dart';
import '../data/staff_store.dart';
import '../data/unit_store.dart';
import '../models/account.dart';
import '../models/unit.dart';
import '../models/payment.dart';
import '../utils/money.dart';
import '../utils/money_input.dart';
import '../utils/metrics.dart';
import '../theme.dart';
import '../l10n/app_strings.dart';
import '../widgets/active_property_label.dart';
import '../widgets/stat_card.dart';
import '../widgets/attachment_picker.dart';
import '../widgets/form_scaffold.dart';
import 'transactions_screen.dart';
import 'rent_grid_screen.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitStore>();
    final staff = context.watch<StaffStore>();
    final expenses = context.watch<ExpenseStore>();
    final fx = context.watch<FxStore>();
    final s = strings(context);
    final base = units.baseCurrency;

    final awaitingIncome = units.totalOutstanding;
    final foreignCredits = nonBaseCredits(units, base, fx);
    final awaitingCrew = awaitingCrewSalaries(staff, expenses);
    final monthlyTxns = monthlyTransactionCount(units, expenses);
    final (monthlyIncome, guessedIncome) = monthlyIncomeGuessed(units, base, fx);
    final (monthlyExpenses, guessedExpense) =
        monthlyExpensesGuessed(expenses, base, fx);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('finance.title')),
        centerTitle: true,
        bottom: AppBrand.barGradient,
        actions: [
          const ActivePropertyLabel(),
          IconButton(
            tooltip: s.t('finance.transactions'),
            icon: const Icon(Icons.receipt_long),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TransactionsScreen()),
            ),
          ),
        ],
      ),
      body: !units.isLoaded
          ? const Center(child: CircularProgressIndicator())
            : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16 + AppBrand.bottomPad),
              children: [
                // ── Summary (5 cards) ──
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: s.t('stat.awaiting.month'),
                        cents: awaitingIncome,
                        currency: base,
                        icon: Icons.savings,
                        color: Colors.orange,
                        caption: foreignCredits > 0
                            ? s.t('stat.awaiting.foreign', [
                                money(foreignCredits, currency: base),
                              ])
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: s.t('finance.awaitingExpenses'),
                        cents: awaitingCrew,
                        currency: base,
                        icon: Icons.people,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: s.t('stat.received.month'),
                        cents: monthlyIncome,
                        currency: base,
                        icon: Icons.trending_up,
                        color: Colors.green,
                        caption: guessedIncome ? s.t('stat.approx') : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        label: s.t('stat.expenses.month'),
                        cents: monthlyExpenses,
                        currency: base,
                        icon: Icons.trending_down,
                        color: Colors.red,
                        caption: guessedExpense ? s.t('stat.approx') : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StatCard(
                  label: s.t('finance.monthlyTxns'),
                  cents: monthlyTxns,
                  currency: '',
                  icon: Icons.swap_horiz,
                  color: Colors.blue,
                  plain: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RentGridScreen()),
                  ),
                  icon: const Icon(Icons.grid_on),
                  label: Text(s.t('rentGrid.title')),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _recordIncome(context, units),
                        icon: const Icon(Icons.savings),
                        label: Text(s.t('finance.recordIncome')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _addExpense(context),
                        icon: const Icon(Icons.receipt_long),
                        label: Text(s.t('finance.addExpense')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // ── Awaiting Incomes ──
                Text(s.t('finance.unitsPayments'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final n = await units.postAllMonthlyCharges(_currentMonth());
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(n > 0
                            ? s.t('finance.posted', ['$n'])
                            : s.t('finance.postedNone'))));
                  },
                  icon: const Icon(Icons.event_available),
                  label: Text(s.t('finance.postMonthly')),
                ),
                const SizedBox(height: 12),
                if (units.units.isEmpty)
                  Text(s.t('onb.noUnits'))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: units.units.length,
                    itemBuilder: (_, i) {
                      final u = units.units[i];
                      final ledger = units.ledgerFor(u.id);
                      final owes = ledger != null && ledger.outstanding > 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            u.ownedByManagement
                                ? Icons.apartment
                                : Icons.home,
                            color: u.ownedByManagement
                                ? Colors.indigo
                                : Colors.grey,
                          ),
                          title: Text(u.number,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            u.occupiers.isEmpty
                                ? (u.isRented
                                    ? s.t('field.vacant')
                                    : s.t('unit.ownUse'))
                                : u.occupiers.map((o) => o.name).join(', '),
                          ),
                          trailing: Text(
                            owes
                                ? s.t('unit.due',
                                    [money(ledger.outstanding, currency: base)])
                                : s.t('finance.clear'),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: owes ? Colors.orange : Colors.green,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                ),
                const SizedBox(height: 24),
                // ── Awaiting Crew Payments ──
                Text(s.t('crew.title'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (staff.members.isEmpty)
                  Text(s.t('crew.empty'))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: staff.members.length,
                    itemBuilder: (_, i) {
                      final m = staff.members[i];
                      if (m.salary <= 0) return const SizedBox.shrink();
                      final paid = expenses.expenses
                              .where((e) =>
                                  e.staffId == m.id &&
                                  e.salaryMonth == _currentMonth())
                              .fold<int>(0, (s, e) => s + e.amount) >=
                          m.salary;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple.withValues(alpha: 0.12),
                            child: const Icon(Icons.person,
                                color: Colors.purple, size: 20),
                          ),
                          title: Text(m.name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(m.role.isNotEmpty ? m.role : ''),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: paid
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              paid
                                  ? '${s.t('crew.paid')} ${money(m.salary, currency: base)}'
                                  : '${s.t('crew.due')} ${money(m.salary, currency: base)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: paid ? Colors.green : Colors.orange,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }

  String _currentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  void _recordIncome(BuildContext context, UnitStore units) {
    final acct = context.read<AccountStore>();
    showDialog<void>(
      context: context,
      builder: (ctx) => _IncomeDialog(
        unitOptions: units.units,
        accountOptions: acct.accounts,
        onSave: (uid, month, amount, type, currency, accountId, note, bytes,
            bytesName) async {
          await units.recordPayment(uid, month, amount,
              type: type,
              currency: currency,
              accountId: accountId,
              note: note,
              attachment: bytes,
              attachmentName: bytesName);
          await acct.refreshTransactions();
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _addExpense(BuildContext context) {
    final store = context.read<ExpenseStore>();
    final acct = context.read<AccountStore>();
    showDialog<void>(
      context: context,
      builder: (ctx) => _ExpenseDialog(
        accountOptions: acct.accounts,
        onSave: (category, amount, desc, currency, accountId, bytes,
            bytesName) async {
          await store.add(category, amount,
              description: desc,
              currency: currency,
              accountId: accountId,
              attachment: bytes,
              attachmentName: bytesName);
          await acct.refreshTransactions();
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _IncomeDialog extends StatefulWidget {
  final List<Unit> unitOptions;
  final List<Account> accountOptions;
  final Future<void> Function(
      int unitId,
      String month,
      int amount,
      String type,
      String currency,
      int? accountId,
      String note,
      Uint8List? attachment,
      String attachmentName) onSave;

  const _IncomeDialog({
    required this.unitOptions,
    required this.accountOptions,
    required this.onSave,
  });

  @override
  State<_IncomeDialog> createState() => _IncomeDialogState();
}

class _IncomeDialogState extends State<_IncomeDialog> {
  static const _types = PaymentType.values;
  final _amount = TextEditingController();
  final _month = TextEditingController();
  final _note = TextEditingController();
  int? _unitId;
  int? _accountId;
  String _type = PaymentType.aidat;
  String _currency = 'EUR';
  Uint8List? _attachment;
  String _attachmentName = '';
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month.text = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    if (widget.unitOptions.isNotEmpty) _unitId = widget.unitOptions.first.id;
    if (widget.accountOptions.isNotEmpty) {
      final def = widget.accountOptions.firstWhere(
          (a) => a.kind == 'cash',
          orElse: () => widget.accountOptions.first);
      _accountId = def.id;
      _currency = def.currency;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _month.dispose();
    _note.dispose();
    super.dispose();
  }

  static String _translateType(AppStrings s, String type) {
    switch (type) {
      case 'Aidat': return s.t('incomeType.aidat');
      case 'Yakıt': return s.t('incomeType.fuel');
      case 'Diğer': return s.t('incomeType.other');
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    return FormDialog(
      icon: Icons.savings,
      title: s.t('finance.recordIncome'),
      subtitle: s.t('finance.incomeSub', ['']),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _unitId,
                decoration: InputDecoration(labelText: '${s.t('field.unit')} *'),
                items: widget.unitOptions
                    .map((u) => DropdownMenuItem(
                        value: u.id,
                        child: Text(u.number)))
                    .toList(),
                validator: (v) => v == null ? s.t('required') : null,
                onChanged: (v) => setState(() => _unitId = v),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  for (final t in _types)
                    ButtonSegment(value: t, label: Text(_translateType(s, t))),
                ],
                selected: {_type},
                onSelectionChanged: (sel) => setState(() => _type = sel.first),
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _accountId,
                decoration: InputDecoration(labelText: s.t('finance.paidInto')),
                items: widget.accountOptions
                    .map((a) => DropdownMenuItem(
                        value: a.id, child: Text('${a.name} (${a.currency})')))
                    .toList(),
                onChanged: (v) {
                  setState(() => _accountId = v);
                  final a = widget.accountOptions
                      .firstWhere((a) => a.id == v, orElse: () => widget.accountOptions.first);
                  setState(() => _currency = a.currency);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: moneyKeyboardType,
                inputFormatters: const [MoneyInputFormatter()],
                decoration: InputDecoration(
                  labelText: '${s.t('field.amount')} ($_currency) *',
                  prefixText: '$_currency ',
                ),
                validator: (v) {
                  final x = tryParseMoney(v ?? '');
                  if (x == null || x <= 0) return s.t('required');
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _month,
                decoration: InputDecoration(labelText: s.t('field.month')),
                validator: (v) => isValidMonth(v) ? null : s.t('field.month.invalid'),
              ),
              const SizedBox(height: 12),
              TextField(controller: _note, decoration: InputDecoration(labelText: s.t('field.note'))),
              const SizedBox(height: 12),
              AttachmentPicker(
                bytes: _attachment,
                name: _attachmentName,
                onPicked: (name, bytes) => setState(() { _attachment = bytes; _attachmentName = name; }),
                onClear: () => setState(() { _attachment = null; _attachmentName = ''; }),
              ),
            ],
          ),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
        FilledButton(
          onPressed: _isSaving ? null : () async {
            setState(() => _isSaving = true);
            try {
              if (!(_formKey.currentState?.validate() ?? false)) return;
              final x = tryParseMoney(_amount.text);
              final uid = _unitId;
              if (x == null || x <= 0 || uid == null) return;
              await widget.onSave(uid, _month.text.trim(), x, _type, _currency, _accountId, _note.text.trim(), _attachment, _attachmentName);
            } finally { if (mounted) setState(() => _isSaving = false); }
          },
          child: Text(s.t('finance.record')),
        ),
      ],
    );
  }
}

class _ExpenseDialog extends StatefulWidget {
  final List<Account> accountOptions;
  final Future<void> Function(String category, int amount, String desc, String currency, int? accountId, Uint8List? bytes, String bytesName) onSave;
  const _ExpenseDialog({required this.accountOptions, required this.onSave});
  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  String _category = 'General';
  int? _accountId;
  String _currency = 'EUR';
  Uint8List? _attachment;
  String _attachmentName = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.accountOptions.isNotEmpty) {
      final def = widget.accountOptions.firstWhere((a) => a.kind == 'cash', orElse: () => widget.accountOptions.first);
      _accountId = def.id;
      _currency = def.currency;
    }
  }

  @override
  void dispose() { _amount.dispose(); _desc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    return FormDialog(
      icon: Icons.receipt_long,
      title: s.t('finance.addExpense'),
      subtitle: s.t('finance.expenseSub', ['']),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: InputDecoration(labelText: s.t('field.category')),
          items: ['General', 'Maintenance', 'Utilities', 'Insurance', 'Other']
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _category = v ?? 'General'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _accountId,
          decoration: InputDecoration(labelText: s.t('finance.paidFrom')),
          items: widget.accountOptions
              .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.currency})')))
              .toList(),
          onChanged: (v) {
            setState(() => _accountId = v);
            final a = widget.accountOptions.firstWhere((a) => a.id == v, orElse: () => widget.accountOptions.first);
            setState(() => _currency = a.currency);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _amount,
          keyboardType: moneyKeyboardType,
          inputFormatters: const [MoneyInputFormatter()],
          decoration: InputDecoration(labelText: '${s.t('field.amount')} ($_currency) *', prefixText: '$_currency '),
          validator: (v) { final x = tryParseMoney(v ?? ''); if (x == null || x <= 0) return s.t('required'); return null; },
        ),
        const SizedBox(height: 12),
        TextField(controller: _desc, decoration: InputDecoration(labelText: s.t('field.desc'))),
        const SizedBox(height: 12),
        AttachmentPicker(
          bytes: _attachment,
          name: _attachmentName,
          onPicked: (name, bytes) => setState(() { _attachment = bytes; _attachmentName = name; }),
          onClear: () => setState(() { _attachment = null; _attachmentName = ''; }),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
        FilledButton(
          onPressed: _isSaving ? null : () async {
            final x = tryParseMoney(_amount.text);
            if (x == null || x <= 0) return;
            setState(() => _isSaving = true);
            try { await widget.onSave(_category, x, _desc.text.trim(), _currency, _accountId, _attachment, _attachmentName); }
            finally { if (mounted) setState(() => _isSaving = false); }
          },
          child: Text(s.t('save')),
        ),
      ],
    );
  }
}

