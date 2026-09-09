// ignore_for_file: sort_child_properties_last
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/account_store.dart';
import '../data/expense_store.dart';
import '../data/site_store.dart';
import '../data/unit_store.dart';
import '../models/account.dart';
import '../widgets/form_scaffold.dart';
import '../utils/money.dart';
import '../utils/money_input.dart';
import '../l10n/app_strings.dart';
import '../theme.dart';
import '../widgets/active_property_label.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AccountStore>();
    final s = strings(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('accounts.title')),
        centerTitle: true,
        bottom: AppBrand.barGradient,
        actions: [const ActivePropertyLabel()],
      ),
      body: !store.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16 + AppBrand.bottomPad),
              children: [
                Text(s.t('accounts.intro'),
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                Text(s.t('section.balances'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (store.accounts.isEmpty)
                  Text(s.t('accounts.empty'))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: store.accounts.length,
                    itemBuilder: (_, i) {
                      final a = store.accounts[i];
                      return _AccountCard(
                        key: ValueKey(a.id),
                        balance: store.balanceFor(a.id) ?? AccountBalance(account: a, income: 0, expenses: 0, balance: a.openingBalance),
                        onEdit: () => _editAccount(context, a),
                        onDelete: () => _confirmDelete(context, a),
                      );
                    },
                  ),
              ],
            ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: AppBrand.bottomPad),
        child: AppBrand.gradientFab(
          tooltip: s.t('add.account'),
          onPressed: () => _addAccount(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _addAccount(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AccountDialog(onSave: (a) async {
        await context.read<AccountStore>().addAccount(a);
        if (ctx.mounted) Navigator.pop(ctx);
      }),
    );
  }

  void _editAccount(BuildContext context, Account account) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AccountDialog(
        initial: account,
        onSave: (a) async {
          final store = context.read<AccountStore>();
          final site = context.read<SiteStore>();
          final units = context.read<UnitStore>();
          // Changing the cash account's currency re-bases the whole ledger:
          // historical charges/payments stay in the old currency, so warn when
          // real ledger data exists and only proceed on explicit consent.
          final currencyChanges = a.kind == 'cash' && a.currency != account.currency;
          if (currencyChanges && units.hasLedgerData && ctx.mounted) {
            final proceed = await _confirmLedgerCurrencyChange(ctx, account.currency);
            if (proceed != true) return;
          }
          await store.updateAccount(account.id, a);
          // Keep the site's main/base currency in sync with the cash account.
          if (currencyChanges) {
            await site.updateMainCurrency(a.currency);
            units.setBaseCurrency(a.currency);
          }
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<bool?> _confirmLedgerCurrencyChange(
      BuildContext ctx, String oldCurrency) {
    final s = strings(ctx);
    return showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text(s.t('account.currencyChangeTitle')),
        content: Text(s.t('account.currencyChangeMsg', [oldCurrency])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(s.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(s.t('account.currencyChangeConfirm')),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Account account) {
    final s = strings(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => _DeleteConfirmDialog(
        title: s.t('delete.title', [account.name]),
        message: s.t('delete.msg.account'),
        onConfirm: () async {
          final accounts = context.read<AccountStore>();
          final unitsStore = context.read<UnitStore>();
          final expenses = context.read<ExpenseStore>();
          final removedPayments =
              await accounts.deleteAccount(account.id);
          unitsStore.removePayments(removedPayments);
          // The DB cascade also wiped the account's expenses; drop them from
          // the expense store too so monthly totals don't count deleted rows.
          expenses.removeForAccount(account.id);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final AccountBalance balance;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AccountCard({
    super.key,
    required this.balance,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    final a = balance.account;
    final isBank = a.kind == 'bank';
    final balanceColor = balance.balance >= 0 ? AppBrand.teal : Colors.red;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: icon + name + menu ──
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      (isBank ? Colors.indigo : Colors.green).withValues(alpha: 0.12),
                  child: Icon(
                      isBank ? Icons.account_balance : Icons.payments,
                      color: isBank ? Colors.indigo : Colors.green,
                      size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (a.bankName.isNotEmpty || a.iban.isNotEmpty)
                        Text(
                          [a.bankName, if (a.iban.isNotEmpty) a.iban]
                              .where((e) => e.isNotEmpty)
                              .join(' · '),
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: s.t('account.actions'),
                  onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                  icon: const Icon(Icons.more_vert, size: 22),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          const Icon(Icons.edit_outlined, size: 20),
                          const SizedBox(width: 10),
                          Text(s.t('edit')),
                        ])),
                    PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline,
                              size: 20, color: Colors.red.shade400),
                          const SizedBox(width: 10),
                          Text(s.t('delete'),
                              style: TextStyle(color: Colors.red.shade400)),
                        ])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Balance + in/out row ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: balanceColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: balanceColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  // Balance
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.t('section.balances'),
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            money(balance.balance, currency: a.currency),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                                color: balanceColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // In / Out
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _InOutChip(
                        label: 'in',
                        value: money(balance.income, currency: a.currency),
                        color: Colors.green,
                      ),
                      const SizedBox(height: 4),
                      _InOutChip(
                        label: 'out',
                        value: money(balance.expenses, currency: a.currency),
                        color: Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── Opening balance ──
            if (a.openingBalance != 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${s.t('field.opening')} ${money(a.openingBalance, currency: a.currency)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InOutChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InOutChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ),
        const SizedBox(width: 4),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _DeleteConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final Future<void> Function() onConfirm;

  const _DeleteConfirmDialog({
    required this.title,
    required this.message,
    required this.onConfirm,
  });

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Text(widget.message),
      actions: [
        TextButton(
            onPressed: _isDeleting ? null : () => Navigator.pop(context),
            child: Text(s.t('cancel'))),
        FilledButton(
          onPressed: _isDeleting
              ? null
              : () async {
                  setState(() => _isDeleting = true);
                  try {
                    await widget.onConfirm();
                  } finally {
                    if (mounted) setState(() => _isDeleting = false);
                  }
                },
          child: _isDeleting
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(s.t('delete')),
        ),
      ],
    );
  }
}

class _AccountDialog extends StatefulWidget {
  final Account? initial;
  final Future<void> Function(Account account) onSave;

  const _AccountDialog({this.initial, required this.onSave});

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _bankName =
      TextEditingController(text: widget.initial?.bankName ?? '');
  late final _iban = TextEditingController(text: widget.initial?.iban ?? '');
  late String _kind = widget.initial?.kind ?? 'bank';
  late String _currency = widget.initial?.currency ?? 'EUR';
  final _formKey = GlobalKey<FormState>();
  late final _opening =
      TextEditingController(text: widget.initial == null ? '' : moneyInputText(widget.initial!.openingBalance));
  bool _isSaving = false;

  @override
  void dispose() {
    _name.dispose();
    _bankName.dispose();
    _iban.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _name.text.trim();
    final opening = tryParseMoney(_opening.text) ?? 0;
    setState(() => _isSaving = true);
    try {
      await widget.onSave(Account(
        id: widget.initial?.id ?? 0,
        name: name,
        kind: _kind,
        bankName: _bankName.text.trim(),
        iban: _iban.text.trim(),
        currency: _currency,
        openingBalance: opening,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    final isEdit = widget.initial != null;
    return FormDialog(
      icon: isEdit ? Icons.edit_outlined : Icons.account_balance,
      title: isEdit ? s.t('edit.account') : s.t('add.account'),
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
                      labelText: '${s.t('field.accountName')} *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? s.t('required') : null),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'bank', label: Text(s.t('field.bank'))),
                  ButtonSegment(value: 'cash', label: Text(s.t('field.cash'))),
                ],
                selected: {_kind},
                onSelectionChanged: (sel) =>
                    setState(() => _kind = sel.first),
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
              const SizedBox(height: 12),
              if (_kind == 'bank') ...[
                TextField(
                    controller: _bankName,
                    decoration:
                        InputDecoration(labelText: s.t('field.bankName'))),
                const SizedBox(height: 12),
                TextField(
                    controller: _iban,
                    decoration:
                        InputDecoration(labelText: s.t('field.iban'))),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration:
                    InputDecoration(labelText: s.t('field.currency')),
                items: Account.currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _currency = v ?? 'EUR'),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _opening,
                  keyboardType: moneyKeyboardType,
                  inputFormatters: const [MoneyInputFormatter()],
                  decoration:
                      InputDecoration(labelText: s.t('field.opening'))),
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