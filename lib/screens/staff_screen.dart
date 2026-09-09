// ignore_for_file: sort_child_properties_last
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/account_store.dart';
import '../data/expense_store.dart';
import '../data/staff_store.dart';
import '../data/unit_store.dart';
import '../models/staff_member.dart';
import '../utils/money.dart';
import '../utils/money_input.dart';
import '../l10n/app_strings.dart';
import '../theme.dart';
import '../widgets/active_property_label.dart';
import '../widgets/form_scaffold.dart';class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StaffStore>();
    final expenses = context.watch<ExpenseStore>();
    final s = strings(context);
    final base = context.watch<UnitStore>().baseCurrency;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('crew.title')),
        centerTitle: true,
        bottom: AppBrand.barGradient,
        actions: [const ActivePropertyLabel()],
      ),
      body: !store.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16 + AppBrand.bottomPad),
              children: [
                Text(
                  s.t('crew.intro'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (store.members.isEmpty)
                  Text(s.t('crew.empty'))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: store.members.length,
                    itemBuilder: (_, i) {
                      final m = store.members[i];
                      return _StaffCard(
                        key: ValueKey(m.id),
                        member: m,
                        salaryDue: m.salary > 0 &&
                            !_salaryPaid(expenses, m.id, m.salary),
                        baseCurrency: base,
                        onEdit: () => _edit(context, m),
                        onDelete: () => _confirmDelete(context, m),
                        onPaySalary: m.salary > 0
                            ? () => _paySalary(context, m)
                            : null,
                      );
                    },
                  ),
              ],
            ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: AppBrand.bottomPad),
        child: AppBrand.gradientFab(
          tooltip: s.t('crew.add'),
          onPressed: () => _add(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  bool _salaryPaid(ExpenseStore expenses, int staffId, int salary) {
    final month = _currentMonth();
    final paid = expenses.expenses
        .where((e) => e.staffId == staffId && e.salaryMonth == month)
        .fold<int>(0, (s, e) => s + e.amount);
    return paid >= salary;
  }

  String _currentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  void _add(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) =>
          _StaffDialog(onSave: (name, role, phone, salary) async {
        await context.read<StaffStore>().add(StaffMember(
              id: 0,
              name: name,
              role: role,
              phone: phone,
              salary: salary,
              createdAt: DateTime.now(),
            ));
        if (ctx.mounted) Navigator.pop(ctx);
      }),
    );
  }

  void _edit(BuildContext context, StaffMember member) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _StaffDialog(
        initial: member,
        onSave: (name, role, phone, salary) async {
          await context
              .read<StaffStore>()
              .update(member.id, name, role, phone, salary);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _paySalary(BuildContext context, StaffMember member) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _PaySalaryDialog(
        member: member,
        onSave: (accountId) async {
          final unitBase = context.read<UnitStore>().baseCurrency;
          final acct = context.read<AccountStore>();
          final paid = await context.read<ExpenseStore>().paySalary(
                member.id,
                amount: member.salary,
                salary: member.salary,
                currency: unitBase,
                accountId: accountId,
                salaryMonth: _currentMonth(),
                staffName: member.name,
              );
          if (!ctx.mounted) return;
          await acct.refreshTransactions();
          if (!paid) {
            if (!ctx.mounted) return;
            final s = strings(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(s.t('crew.alreadyPaid'))),
            );
            return;
          }
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, StaffMember member) {
    final s = strings(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('delete.title', [member.name])),
        content: Text(s.t('crew.delete.msg')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.t('cancel'))),
          FilledButton(
            onPressed: () async {
              await context.read<StaffStore>().remove(member.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(s.t('delete')),
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final StaffMember member;
  final bool salaryDue;
  final String baseCurrency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onPaySalary;

  const _StaffCard({
    super.key,
    required this.member,
    required this.salaryDue,
    required this.baseCurrency,
    required this.onEdit,
    required this.onDelete,
    this.onPaySalary,
  });

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: AppBrand.teal.withValues(alpha: 0.12),
          radius: 22,
          child: const Icon(Icons.build, color: AppBrand.teal, size: 22),
        ),
        title: Text(member.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (member.role.isNotEmpty) member.role,
                if (member.phone.isNotEmpty) member.phone,
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (member.salary > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    s.t('crew.salary', [
                      money(member.salary, currency: baseCurrency)
                    ]),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: salaryDue
                          ? Colors.orange.withValues(alpha: 0.15)
                          : Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      salaryDue ? s.t('crew.due') : s.t('crew.paid'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: salaryDue ? Colors.orange : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          tooltip: '',
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
            if (v == 'pay') onPaySalary?.call();
          },
          icon: const Icon(Icons.more_vert, size: 24),
          itemBuilder: (_) => [
            if (onPaySalary != null)
              PopupMenuItem(
                value: 'pay',
                child: Row(children: [
                  const Icon(Icons.payments_outlined, size: 20),
                  const SizedBox(width: 10),
                  Text(s.t('crew.paySalary')),
                ]),
              ),
            PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                const Icon(Icons.edit_outlined, size: 20),
                const SizedBox(width: 10),
                Text(s.t('edit')),
              ]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                const SizedBox(width: 10),
                Text(s.t('delete'), style: TextStyle(color: Colors.red.shade400)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaySalaryDialog extends StatefulWidget {
  final StaffMember member;
  final Future<void> Function(int? accountId) onSave;

  const _PaySalaryDialog({required this.member, required this.onSave});

  @override
  State<_PaySalaryDialog> createState() => _PaySalaryDialogState();
}

class _PaySalaryDialogState extends State<_PaySalaryDialog> {
  int? _accountId;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_accountId != null) return;
    final base = context.read<UnitStore>().baseCurrency;
    final matching = context
        .read<AccountStore>()
        .accounts
        .where((a) => a.currency == base)
        .toList();
    _accountId = matching.isEmpty ? null : matching.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    final acct = context.watch<AccountStore>();
    final base = context.watch<UnitStore>().baseCurrency;
    // Salaries are denominated in the site's main (cash) currency. Only
    // accounts in that currency can receive the payment — posting a salary in
    // one currency into an account owned in another would corrupt balances.
    final accounts =
        acct.accounts.where((a) => a.currency == base).toList();
    return FormDialog(
      icon: Icons.payments,
      title: s.t('crew.pay.title', [widget.member.name]),
      subtitle: s.t('crew.monthlySalary',
          [money(widget.member.salary, currency: base)]),
      children: [
        if (accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(s.t('crew.noAccounts')),
          )
        else
          DropdownButtonFormField<int>(
            initialValue: _accountId,
            decoration: InputDecoration(labelText: s.t('crew.payFrom')),
            items: accounts
                .map((a) => DropdownMenuItem(
                    value: a.id,
                    child: Text('${a.name} (${a.currency})')))
                .toList(),
            onChanged: (v) => setState(() => _accountId = v),
          ),
      ],
      actions: [
        TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: Text(s.t('cancel'))),
        FilledButton(
          onPressed: (accounts.isEmpty || _isSaving)
              ? null
              : () async {
                  setState(() => _isSaving = true);
                  try {
                    await widget.onSave(_accountId);
                  } finally {
                    if (mounted) setState(() => _isSaving = false);
                  }
                },
          child: _isSaving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(s.t('crew.pay')),
        ),
      ],
    );
  }
}

class _StaffDialog extends StatefulWidget {
  final StaffMember? initial;
  final Future<void> Function(String name, String role, String phone, int salary)
      onSave;

  const _StaffDialog({this.initial, required this.onSave});

  @override
  State<_StaffDialog> createState() => _StaffDialogState();
}

class _StaffDialogState extends State<_StaffDialog> {
  late final _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _role =
      TextEditingController(text: widget.initial?.role ?? '');
  late final _phone =
      TextEditingController(text: widget.initial?.phone ?? '');
  late final _salary = TextEditingController(
      text: (widget.initial?.salary ?? 0) > 0
          ? moneyInputText(widget.initial!.salary)
          : '');
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _phone.dispose();
    _salary.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      await widget.onSave(_name.text.trim(), _role.text.trim(),
          _phone.text.trim(), tryParseMoney(_salary.text) ?? 0);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    final base = context.watch<UnitStore>().baseCurrency;
    final isEdit = widget.initial != null;
    return FormDialog(
      icon: isEdit ? Icons.edit_outlined : Icons.person_add_outlined,
      title: isEdit ? s.t('crew.edit') : s.t('crew.add'),
      subtitle: isEdit ? widget.initial!.name : null,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                      labelText: '${s.t('field.name')} *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? s.t('required')
                          : null),
              const SizedBox(height: 12),
              TextFormField(
                controller: _role,
                decoration: InputDecoration(labelText: s.t('field.role')),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: const [PhoneInputFormatter()],
                decoration: InputDecoration(labelText: s.t('field.phone')),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _salary,
                keyboardType: moneyKeyboardType,
                inputFormatters: const [MoneyInputFormatter()],
                decoration: InputDecoration(
                  labelText: s.t('crew.salaryField'),
                  prefixText: '${moneySymbol(base)} ',
                ),
              ),
            ],
          ),
        ),
      ],
      actions: [
        TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: Text(s.t('cancel'))),
        FilledButton(
            onPressed: _isSaving ? null : _submit,
            child: _isSaving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(s.t('save'))),
      ],
    );
  }
}