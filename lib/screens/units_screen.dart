import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/unit_store.dart';
import '../data/account_store.dart';
import '../data/language_store.dart';
import '../data/site_store.dart';
import '../models/unit.dart';
import '../utils/money.dart';
import '../l10n/app_strings.dart';
import '../widgets/active_property_label.dart';
import '../theme.dart';
import 'dashboard_screen.dart' show AddUnitDialog;

class UnitsScreen extends StatelessWidget {
  const UnitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UnitStore>();
    final site = context.watch<SiteStore>();
    final s = strings(context);
    final main = site.mainCurrency;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('section.units')),
        centerTitle: true,
        bottom: AppBrand.barGradient,
        actions: const [ActivePropertyLabel()],
      ),
      body: SafeArea(
        child: store.isLoaded
            ? _content(context, store, main)
            : const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: AppBrand.bottomPad),
        child: AppBrand.gradientFab(
          onPressed: () => _addUnit(context),
          tooltip: s.t('add.unit'),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, UnitStore store, String currency) {
    if (store.units.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apartment_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              strings(context).t('onb.noUnits'),
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16 + AppBrand.bottomPad),
      itemCount: store.units.length,
      itemBuilder: (_, i) {
        final u = store.units[i];
        return _UnitTile(
          key: ValueKey(u.id),
          unit: u,
          ledger: store.ledgerFor(u.id) ?? UnitLedger(unit: u, totalCharged: 0, paidBase: 0, outstanding: 0, baseCurrency: currency),
          currency: currency,
          onEdit: () => _editUnit(context, u),
          onDelete: () => _deleteUnit(context, u),
        );
      },
    );
  }

  void _addUnit(BuildContext context) async {
    final s = AppStrings(context.read<LanguageStore>().lang);
    final created = await Navigator.push<Unit>(
      context,
      MaterialPageRoute(
        builder: (_) => AddUnitDialog(
          currency: context.read<UnitStore>().baseCurrency,
        ),
      ),
    );
    if (created != null && context.mounted) {
      await context.read<UnitStore>().addUnit(created);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('unit.added', [created.number]))),
        );
      }
    }
  }

  void _editUnit(BuildContext context, Unit unit) async {
    final updated = await Navigator.push<Unit>(
      context,
      MaterialPageRoute(
        builder: (_) => AddUnitDialog(
          currency: context.read<UnitStore>().baseCurrency,
          initial: unit,
        ),
      ),
    );
    if (updated != null && context.mounted) {
      await context.read<UnitStore>().updateUnit(updated);
    }
  }

  void _deleteUnit(BuildContext context, Unit unit) async {
    final s = strings(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('delete.title', [unit.number])),
        content: Text(s.t('unit.deleteMsg', [unit.number])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(s.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      // Deleting a unit cascade-wipes its payments from the DB; drop them from
      // the transaction log / account balances too so they don't keep counting.
      final removed = await context.read<UnitStore>().removeUnit(unit.id);
      if (context.mounted) {
        context.read<AccountStore>().removePayments(removed);
      }
    }
  }
}

class _UnitTile extends StatelessWidget {
  final UnitLedger ledger;
  final Unit unit;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UnitTile({
    super.key,
    required this.ledger,
    required this.unit,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _statusColor => switch (unit.status) {
        'occupied' => AppBrand.teal,
        'vacant' => AppBrand.gradient[0],
        _ => AppPalette.violet,
      };

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    final scheme = Theme.of(context).colorScheme;
    final owes = ledger.outstanding > 0;
    final dueColor = Colors.orange;
    final now = DateTime.now();
    final leaseExpiringSoon = unit.leaseEnd != null &&
        unit.leaseEnd!.isAfter(now) &&
        unit.leaseEnd!.difference(now).inDays <= 30;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: badge + name + menu ──
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      _statusColor.withValues(alpha: 0.12),
                  child: Text(
                    unit.number,
                    maxLines: 1,
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit.floor.isNotEmpty
                            ? '${unit.number} · ${s.t('unit.floorShort', [unit.floor])}'
                            : unit.number,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        unit.occupiers.isEmpty
                            ? (unit.isRented
                                ? s.t('field.vacant')
                                : s.t('unit.ownUse'))
                            : unit.occupiers.map((o) => o.name).join(', '),
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (unit.leaseEnd != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${s.t('unit.leaseEnd')}: ${unit.leaseEnd!.day.toString().padLeft(2, '0')}.${unit.leaseEnd!.month.toString().padLeft(2, '0')}.${unit.leaseEnd!.year}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: leaseExpiringSoon ? FontWeight.w700 : FontWeight.w500,
                            color: leaseExpiringSoon ? Colors.orange : scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) =>
                      v == 'edit' ? onEdit() : onDelete(),
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
            // ── Financials box ──
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: (owes ? dueColor : AppBrand.teal)
                    .withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: (owes ? dueColor : AppBrand.teal)
                        .withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.t('unit.dueShort', ['']),
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${money(unit.monthlyCharge, currency: currency)}${s.t('unit.percent')}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusPill(unit: unit),
                      if (owes) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: dueColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            s.t('unit.dueShort',
                                [money(ledger.outstanding, currency: currency)]),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: dueColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final Unit unit;
  const _StatusPill({required this.unit});

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    final (color, label) = switch (unit.status) {
      'occupied' => (AppBrand.teal, s.t('field.occupied')),
      'maintenance' => (AppPalette.violet, s.t('field.maintenance')),
      _ => (AppBrand.gradient[0], s.t('field.vacant')),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
