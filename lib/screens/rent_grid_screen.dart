import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/unit_store.dart';
import '../l10n/app_strings.dart';
import '../models/unit.dart';
import '../theme.dart';
import '../utils/money.dart';
import '../widgets/active_property_label.dart';

class RentGridScreen extends StatefulWidget {
  const RentGridScreen({super.key});

  @override
  State<RentGridScreen> createState() => _RentGridScreenState();
}

class _RentGridScreenState extends State<RentGridScreen> {
  Unit? _selectedUnit;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UnitStore>();
    final s = strings(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('rentGrid.title')),
        centerTitle: true,
        bottom: AppBrand.barGradient,
        actions: const [ActivePropertyLabel()],
      ),
      body: store.isLoaded
          ? _selectedUnit == null
              ? _buildUnitList(context, store)
              : _buildCalendar(context, store, _selectedUnit!)
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildUnitList(BuildContext context, UnitStore store) {
    final s = strings(context);
    final rented = store.units.where((u) => u.status == 'occupied').toList();

    if (rented.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            s.t('rentGrid.noUnits'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            s.t('rentGrid.selectUnit'),
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16 + AppBrand.bottomPad),
            itemCount: rented.length,
            itemBuilder: (_, i) {
              final u = rented[i];
              final ledger = store.ledgerFor(u.id);
              final owes = ledger != null && ledger.outstanding > 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () => setState(() => _selectedUnit = u),
                  leading: CircleAvatar(
                    backgroundColor:
                        AppBrand.teal.withValues(alpha: 0.12),
                    child: Text(
                      u.number,
                      style: const TextStyle(
                        color: AppBrand.teal,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  title: Text(
                    u.number,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    u.occupiers.isEmpty
                        ? s.t('field.vacant')
                        : u.occupiers.map((o) => o.name).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (owes)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            money(ledger.outstanding,
                                currency: store.baseCurrency),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 22),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context, UnitStore store, Unit unit) {
    final s = strings(context);
    final now = DateTime.now();
    final baseCurrency = store.baseCurrency;

    // 12 months: current + 11 forward. Rows come from the store's per-month
    // balances, which apply surplus credit across months — so the grid's
    // "remaining" always agrees with the arrears summary (and vice versa).
    // Forward months without a posted charge are shown as scheduled (projected
    // rent), so the grid reads as a plan instead of empty grey cells.
    final balances = {
      for (final r in store.monthBalancesAll(unit.id)) r.ym: r,
    };
    final months = <_MonthData>[];
    for (var i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month + i, 1);
      final ym = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      final row = balances[ym];
      final isFuture = i > 0;
      months.add(_MonthData(
        ym: ym,
        label: _monthLabel(ym, s),
        year: d.year,
        charged: row?.charged ?? (isFuture ? unit.monthlyCharge : 0),
        paid: row?.paidBase ?? 0,
        remaining: row?.remaining ?? 0,
        upcoming: row == null && isFuture,
      ));
    }

    final ledger = store.ledgerFor(unit.id);
    final outstanding = ledger?.outstanding ?? 0;

    return Column(
      children: [
        // Unit header
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppBrand.tealGradient,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  unit.number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.occupiers.isEmpty
                          ? s.t('field.vacant')
                          : unit.occupiers.first.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${money(unit.monthlyCharge, currency: baseCurrency)}/mo',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (outstanding > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    money(outstanding, currency: baseCurrency),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _LegendDot(color: AppBrand.teal, label: s.t('rentGrid.paid')),
              const SizedBox(width: 14),
              _LegendDot(
                  color: Colors.orange, label: s.t('rentGrid.partial')),
              const SizedBox(width: 14),
              _LegendDot(color: Colors.red, label: s.t('rentGrid.unpaid')),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _selectedUnit = null),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      s.t('rentGrid.allUnits'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Calendar grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16 + AppBrand.bottomPad),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.15,
              ),
              itemCount: months.length,
              itemBuilder: (_, i) {
                final m = months[i];
                return _CalendarCell(
                  month: m,
                  currency: baseCurrency,
                  unitId: unit.id,
                  appStrings: s,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _monthLabel(String ym, AppStrings s) {
    final parts = ym.split('-');
    final month = int.tryParse(parts[1]) ?? 1;
    const keys = ['', 'month.jan', 'month.feb', 'month.mar', 'month.apr',
      'month.may', 'month.jun', 'month.jul', 'month.aug', 'month.sep',
      'month.oct', 'month.nov', 'month.dec'];
    return s.t(keys[month]);
  }
}

class _MonthData {
  final String ym;
  final String label;
  final int year;
  final int charged;
  final int paid;
  final int remaining;
  final bool upcoming; // projected charge, no charge posted yet
  const _MonthData({
    required this.ym,
    required this.label,
    required this.year,
    required this.charged,
    required this.paid,
    required this.remaining,
    this.upcoming = false,
  });
}

class _CalendarCell extends StatelessWidget {
  final _MonthData month;
  final String currency;
  final int unitId;
  final AppStrings appStrings;
  const _CalendarCell(
      {required this.month,
      required this.currency,
      required this.unitId,
      required this.appStrings});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final parts = month.ym.split('-');
    final m = int.tryParse(parts[1]) ?? 1;
    final y = int.tryParse(parts[0]) ?? now.year;
    final isCurrentMonth = y == now.year && m == now.month;
    final isPast = y < now.year || (y == now.year && m < now.month);

    Color color;
    IconData icon;

    if (month.upcoming) {
      // Not billed yet — a scheduled (projected) month, never an owed one.
      color = Colors.blueGrey;
      icon = Icons.event_available;
    } else if (month.charged <= 0) {
      color = Colors.grey;
      icon = Icons.remove_circle_outline;
    } else if (month.remaining <= 0) {
      // Settled: paid outright this month or covered by surplus credit.
      color = AppBrand.teal;
      icon = Icons.check_circle;
    } else if (month.remaining < month.charged) {
      color = Colors.orange;
      icon = Icons.hourglass_top;
    } else if (isPast) {
      color = Colors.red;
      icon = Icons.cancel;
    } else {
      color = Colors.red;
      icon = Icons.pending;
    }

    return GestureDetector(
      onTap: month.charged > 0
          ? () => _showDetail(context, month, currency)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isCurrentMonth ? 0.20 : 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrentMonth
                ? color
                : color.withValues(alpha: 0.3),
            width: isCurrentMonth ? 2 : 1,
          ),
          boxShadow: isCurrentMonth
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${month.year}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 2),
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 4),
            Text(
              month.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: color,
              ),
            ),
            if (month.charged > 0) ...[
              const SizedBox(height: 2),
              Text(
                money(month.charged, currency: currency),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetail(
      BuildContext context, _MonthData month, String currency) {
    final s = strings(context);
    final remaining = month.remaining < 0 ? 0 : month.remaining;
    final String status;
    if (month.upcoming) {
      status = s.t('rentGrid.upcoming');
    } else if (month.charged > 0 && remaining <= 0) {
      status = s.t('rentGrid.paid');
    } else if (month.charged > 0 && remaining < month.charged) {
      status = s.t('rentGrid.partial');
    } else {
      status = s.t('rentGrid.unpaid');
    }
    final statusColor = month.upcoming
        ? Colors.blueGrey
        : remaining <= 0
            ? AppBrand.teal
            : remaining < month.charged
                ? Colors.orange
                : Colors.red;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  month.upcoming
                      ? Icons.event_available
                      : remaining <= 0
                          ? Icons.check_circle
                          : remaining < month.charged
                              ? Icons.hourglass_top
                              : Icons.cancel,
                  color: statusColor,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  '${month.label} ${month.ym.split('-')[0]}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(
              label: s.t('rentGrid.charged'),
              value: money(month.charged, currency: currency),
            ),
            if (!month.upcoming) ...[
              const SizedBox(height: 8),
              _DetailRow(
                label: s.t('rentGrid.received'),
                value: money(month.paid, currency: currency),
              ),
              const SizedBox(height: 8),
              _DetailRow(
                label: s.t('rentGrid.status'),
                value: status,
                valueColor: statusColor,
              ),
              if (month.charged > 0 && remaining > 0) ...[
                const SizedBox(height: 8),
                _DetailRow(
                  label: s.t('rentGrid.remaining'),
                  value: money(remaining, currency: currency),
                  valueColor: Colors.red,
                ),
              ],
            ] else
              const SizedBox(height: 8),
            if (month.charged > 0 && !month.upcoming) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _confirmRemoveCharge(context, unitId, month.ym);
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(s.t('rentGrid.removeCharge')),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoveCharge(
      BuildContext context, int unitId, String ym) async {
    final s = strings(context);
    final store = context.read<UnitStore>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(s.t('delete.title', [ym])),
        content: Text(s.t('delete.msg.charge', [ym])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(s.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(s.t('delete')),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await store.removeCharge(unitId, ym);
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
