// ignore_for_file: sort_child_properties_last
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/site_store.dart';
import '../data/language_store.dart';
import '../data/unit_store.dart';
import '../data/fx_store.dart';
import '../l10n/app_strings.dart';
import '../models/account.dart';
import '../theme.dart';
import '../widgets/form_scaffold.dart';

/// Portfolio screen: lists every property and lets the manager add, rename,
/// recolor-currency, or delete one.
class PropertiesScreen extends StatelessWidget {
  const PropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final site = context.watch<SiteStore>();
    final s = strings(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('properties.title')),
        centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            site.properties.isEmpty
                ? s.t('properties.introEmpty')
                : s.t('properties.introList'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (site.properties.isEmpty)
            Text(s.t('properties.empty'))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: site.properties.length,
              itemBuilder: (_, i) {
                final p = site.properties[i];
                return _PropertyCard(
                  key: ValueKey(p.id),
                  property: p,
                  active: p.id == site.activePropertyId,
                  onEdit: () => _edit(context, p),
                  onSelect: () {
                    site.switchProperty(p.id);
                    Navigator.pop(context);
                  },
                  onDelete: () => _confirmDelete(context, p),
                );
              },
            ),
        ],
      ),
      floatingActionButton: AppBrand.gradientFab(
        tooltip: s.t('properties.add'),
        onPressed: () => _add(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _add(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _PropertyDialog(
        onSave: (name, currency, address) async {
          final site = context.read<SiteStore>();
          final created = await site.addProperty(name, currency, address: address);
          // Jump straight into the new building so the manager can set it up.
          await site.switchProperty(created.id);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _edit(BuildContext context, Property p) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _PropertyDialog(
        initial: p,
        onSave: (name, currency, address) async {
          final site = context.read<SiteStore>();
          final units = context.read<UnitStore>();
          final fx = context.read<FxStore>();
          // Same guard as the cash-account path: re-denominating a ledger that
          // already holds charges/payments silently mislabels every amount.
          final changesCurrency = p.currency != currency;
          final carriesLedger =
              p.id == site.activePropertyId && units.hasLedgerData;
          if (changesCurrency && carriesLedger) {
            final ok = await _confirmCurrencyChange(ctx);
            if (ok != true) return;
          }
          await site.updateProperty(p.id, name, currency, address: address);
          if (p.id == site.activePropertyId) {
            units.setBaseCurrency(currency);
            unawaited(fx.refresh(currency));
          }
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<bool?> _confirmCurrencyChange(BuildContext ctx) {
    final s = AppStrings(ctx.read<LanguageStore>().lang);
    return showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(s.t('account.currencyChangeTitle')),
        content: Text(s.t('properties.currencyChangeMsg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(s.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(s.t('account.currencyChangeConfirm')),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Property p) {
    final s = AppStrings(context.read<LanguageStore>().lang);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('delete.title', [p.name])),
        content: Text(s.t('properties.delete.msg')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.t('cancel'))),
          FilledButton(
            onPressed: () async {
              await context.read<SiteStore>().deleteProperty(p.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(s.t('delete')),
          ),
        ],
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final Property property;
  final bool active;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSelect;

  const _PropertyCard({
    super.key,
    required this.property,
    required this.active,
    required this.onEdit,
    required this.onDelete,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              (active ? Colors.indigo : Colors.grey).withValues(alpha: 0.12),
          child: Icon(Icons.apartment, color: active ? Colors.indigo : Colors.grey),
        ),
        title: Row(
          children: [
            Flexible(child: Text(property.name, overflow: TextOverflow.ellipsis)),
            if (active) ...[
              const SizedBox(width: 6),
              Chip(
                label: Text(s.t('properties.active')),
                labelStyle: const TextStyle(fontSize: 10),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
                backgroundColor: Colors.indigo.withValues(alpha: 0.15),
              ),
            ],
          ],
        ),
        subtitle: Text(property.currency),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!active)
              IconButton(
                tooltip: s.t('properties.view'),
                onPressed: onSelect,
                icon: const Icon(Icons.visibility_outlined),
              ),
            IconButton(
                tooltip: s.t('edit'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined)),
            IconButton(
                tooltip: s.t('delete'),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline)),
          ],
        ),
        isThreeLine: false,
      ),
    );
  }
}

class _PropertyDialog extends StatefulWidget {
  final Property? initial;
  final Future<void> Function(String name, String currency, String address) onSave;
  const _PropertyDialog({this.initial, required this.onSave});

  @override
  State<_PropertyDialog> createState() => _PropertyDialogState();
}

class _PropertyDialogState extends State<_PropertyDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _address = TextEditingController(text: widget.initial?.address ?? '');
  late String _currency = widget.initial?.currency ?? 'EUR';
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      await widget.onSave(_name.text.trim(), _currency, _address.text.trim());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    final isEdit = widget.initial != null;
    return FormDialog(
      icon: isEdit ? Icons.edit_outlined : Icons.add_business,
      title: isEdit ? s.t('properties.edit') : s.t('properties.add'),
      subtitle: isEdit ? widget.initial!.name : null,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                    labelText: '${s.t('field.propertyName')} *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? s.t('required') : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration:
                    InputDecoration(labelText: s.t('field.mainCurrency')),
                items: Account.currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _currency = v ?? 'EUR'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _address,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: s.t('field.address')),
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
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(s.t('save'))),
      ],
    );
  }
}