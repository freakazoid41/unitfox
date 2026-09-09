import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/local_db.dart';
import '../data/site_store.dart';
import '../l10n/app_strings.dart';
import '../models/account.dart';
import '../models/unit.dart';
import '../utils/money.dart';
import '../utils/money_input.dart';
import 'dashboard_screen.dart' show AddUnitDialog;

/// First-run wizard: site identity, accounts (cash is the main one), and the
/// initial units. Completing it writes real data and marks onboarding done so
/// demo seeds never appear.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final _siteName = TextEditingController();
  String _mainCurrency = 'EUR';
  final _cashOpening = TextEditingController();
  final _siteFormKey = GlobalKey<FormState>();
  final List<Account> _bankAccounts = [];
  final List<Unit> _units = [];
  bool _saving = false;

  @override
  void dispose() {
    _siteName.dispose();
    _cashOpening.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0 &&
        !(_siteFormKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _step++);
  }

  Future<void> _finish() async {
    final site = context.read<SiteStore>();
    setState(() => _saving = true);
    try {
      final cash = Account(
        id: 0,
        name: 'Cash (main)',
        kind: 'cash',
        currency: _mainCurrency,
        openingBalance: tryParseMoney(_cashOpening.text) ?? 0,
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      final accountRows = [
        cash.toRow(),
        for (final a in _bankAccounts) a.toRow(),
      ];
      final unitRows = [
        for (final u in _units)
          u.toRow()..addAll({'created_at': now}),
      ];
      // Write the property + accounts + units atomically so a failure
      // never leaves a half-built orphan site.
      final propertyId = await LocalDB.completeOnboardingAtomic(
        _siteName.text.trim(),
        _mainCurrency,
        '',
        accountRows,
        unitRows,
      );
      // Update the in-memory SiteStore so the UI transitions immediately.
      await site.completeOnboardingFromDb(
        propertyId,
        _siteName.text.trim(),
        _mainCurrency,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ls(context).t('onb.failure'))));
      }
    }
  }

  void _addBankAccount() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _AccountForm(
          title: ls(context).t('add.account'),
          onSave: (a) => setState(() => _bankAccounts.add(a)),
        ),
      ),
    );
  }

  void _addUnit() async {
    final unit = await Navigator.push<Unit>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AddUnitDialog(
          currency: _mainCurrency,
        ),
      ),
    );
    if (unit != null && mounted) {
      setState(() => _units.add(unit));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    final titles = [
      s.t('onb.step.site'),
      s.t('onb.step.accounts'),
      s.t('onb.step.units'),
    ];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < titles.length; i++) ...[
                    _StepDot(label: titles[i], active: i == _step),
                    if (i < titles.length - 1)
                      const Expanded(child: Divider()),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildStep(context)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: () => setState(() => _step--),
                      child: Text(s.t('back')),
                    ),
                  const SizedBox(width: 8),
                  if (_step < 2)
                    FilledButton(
                      onPressed: _next,
                      child: Text(s.t('next')),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _saving ? null : _finish,
                      icon: const Icon(Icons.check),
                      label: Text(_saving ? s.t('saving') : s.t('finish')),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _buildSiteStep(context);
      case 1:
        return _buildAccountsStep(context);
      default:
        return _buildUnitsStep(context);
    }
  }

  Widget _buildSiteStep(BuildContext context) {
    final s = ls(context);
    return Form(
      key: _siteFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('onb.titleTitle'),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall!
                  .copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(s.t('onb.intro.site')),
          const SizedBox(height: 20),
          TextFormField(
            controller: _siteName,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: '${s.t('onb.propertyName')} *',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? s.t('required') : null,
          ),
        const SizedBox(height: 16),
        Text(s.t('onb.mainCurrency'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(s.t('onb.intro.currency')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _mainCurrency,
          decoration: const InputDecoration(),
          items: Account.currencies
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _mainCurrency = v ?? 'EUR'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _cashOpening,
          keyboardType: moneyKeyboardType,
          inputFormatters: const [MoneyInputFormatter()],
          decoration: InputDecoration(
            labelText: s.t('onb.cashOpening'),
          ),
        ),
      ],
      ),
    );
  }

Future<void> _confirmRemoveAccount(Account a) async {
    final s = ls(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('delete.title', [a.name])),
        content: Text(s.t('delete.msg.account')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.t('delete')),
          ),
        ],
      ),
    );
    if (ok == true && mounted) setState(() => _bankAccounts.remove(a));
  }

  Future<void> _confirmRemoveUnit(int index) async {
    final s = ls(context);
    final u = _units[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('delete.title', [u.number])),
        content: Text(s.t('unit.deleteMsg', [u.number])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.t('delete')),
          ),
        ],
      ),
    );
    if (ok == true && mounted) setState(() => _units.removeAt(index));
  }

  Widget _buildAccountsStep(BuildContext context) {
    final s = ls(context);
    final opening = tryParseMoney(_cashOpening.text) ?? 0;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(s.t('onb.title.accounts'),
            style: Theme.of(context)
                .textTheme
                .headlineSmall!
                .copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(s.t('onb.intro.accounts')),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.payments),
            title: Text(s.t('onb.cashMain')),
            subtitle: Text(s.t('onb.openingLine', [_mainCurrency, money(opening, currency: _mainCurrency)])),
            isThreeLine: true,
          ),
        ),
        const SizedBox(height: 8),
        ..._bankAccounts.map((a) => Card(
              child: ListTile(
                title: Text(a.name),
                subtitle: Text(
                    '${a.currency} · ${a.bankName} ${a.iban} · ${s.t('field.opening')} ${money(a.openingBalance, currency: a.currency)}'.trim()),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmRemoveAccount(a),
                ),
              ),
            )),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addBankAccount,
          icon: const Icon(Icons.account_balance),
          label: Text(s.t('onb.addBank')),
        ),
      ],
    ),
    );
  }

  Widget _buildUnitsStep(BuildContext context) {
    final s = ls(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.t('onb.title.units'),
            style: Theme.of(context)
                .textTheme
                .headlineSmall!
                .copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(s.t('onb.intro.units')),
        const SizedBox(height: 16),
        Expanded(
          child: _units.isEmpty
              ? Center(child: Text(s.t('onb.noUnits')))
              : ListView.builder(
                  itemCount: _units.length,
                  itemBuilder: (_, i) {
                    final u = _units[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.home),
                        title: Text(u.number),
                        subtitle: Text(
                            '${u.occupiers.isEmpty ? s.t('field.vacant') : u.occupiers.map((o) => o.name).join(', ')}'
                            ' · ${money(u.monthlyCharge, currency: _mainCurrency)}${s.t('unit.percent')}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmRemoveUnit(i),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addUnit,
          icon: const Icon(Icons.add_home),
          label: Text(s.t('add.unit')),
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool active;
  const _StepDot({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? Theme.of(context).colorScheme.primary : Colors.grey;
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _AccountForm extends StatefulWidget {
  final String title;
  final ValueChanged<Account> onSave;
  const _AccountForm({required this.title, required this.onSave});

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  final _name = TextEditingController();
  final _bankName = TextEditingController();
  final _iban = TextEditingController();
  final _opening = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _currency = 'EUR';

  @override
  void dispose() {
    _name.dispose();
    _bankName.dispose();
    _iban.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _name.text.trim();
    widget.onSave(Account(
      id: 0,
      name: name,
      kind: 'bank',
      bankName: _bankName.text.trim(),
      iban: _iban.text.trim(),
      currency: _currency,
      openingBalance: tryParseMoney(_opening.text) ?? 0,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check, size: 20),
              label: Text(s.t('add')),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                    labelText: '${s.t('field.accountName')} *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? s.t('required') : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: InputDecoration(labelText: s.t('field.currency')),
                items: Account.currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _currency = v ?? 'EUR'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _bankName,
                decoration: InputDecoration(labelText: s.t('field.bankName')),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _iban,
                decoration: const InputDecoration(labelText: 'IBAN'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _opening,
                keyboardType: moneyKeyboardType,
                inputFormatters: const [MoneyInputFormatter()],
                decoration: InputDecoration(
                    labelText: s.t('field.opening')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
