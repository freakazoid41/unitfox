import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/unit_store.dart';
import '../data/site_store.dart';
import '../data/expense_store.dart';
import '../data/fx_store.dart';
import '../data/staff_store.dart';
import '../models/unit.dart';
import '../utils/money.dart';
import '../utils/money_input.dart';
import '../utils/metrics.dart';
import '../l10n/app_strings.dart';
import '../widgets/ad_banner_card.dart';
import '../widgets/form_scaffold.dart';
import '../widgets/active_property_label.dart';
import '../widgets/stat_card.dart';

import '../theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UnitStore>();
    final site = context.watch<SiteStore>();
    final s = strings(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('dashboard.title')),
        centerTitle: true,
        bottom: AppBrand.barGradient,
        actions: const [ActivePropertyLabel()],
      ),
      body: SafeArea(
        child: store.isLoaded
            ? _content(context, store, site)
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _content(BuildContext context, UnitStore store, SiteStore site) {
    final main = site.mainCurrency;
    final expenses = context.watch<ExpenseStore>();
    final staff = context.watch<StaffStore>();
    final fx = context.watch<FxStore>();
    final s = ls(context);
    final (received, guessedIncome) = monthlyIncomeGuessed(store, main, fx);
    final foreignCredits = nonBaseCredits(store, main, fx);
    final (spent, guessedExpense) = monthlyExpensesGuessed(expenses, main, fx);
    final awaiting = awaitingCrewSalaries(staff, expenses);
    final occupancyPct = store.units.isEmpty
        ? 0
        : (store.occupiedCount * 100 ~/ store.units.length);
    final now = DateTime.now();
    final renewals = store.units.where((u) {
      final end = u.leaseEnd;
      if (end == null) return false;
      return end.isAfter(now) && end.difference(now).inDays <= 30;
    }).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16 + AppBrand.bottomPad),
      children: [
        _HeroHeader(),
        const SizedBox(height: 12),
        const AdBannerCard(),
        const SizedBox(height: 20),
        // ── Overview ──
        Text(s.t('dashboard.overview'),
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _OverviewCard(
                value: '${store.units.length}',
                label: s.t('section.units'),
                icon: Icons.apartment,
                color: AppBrand.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                value: '$occupancyPct%',
                label: s.t('dashboard.occupied'),
                icon: Icons.home,
                color: AppBrand.gradient[0],
                trailing: SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: occupancyPct / 100,
                        strokeWidth: 4.5,
                        backgroundColor: AppBrand.teal.withValues(alpha: 0.15),
                        valueColor:
                            const AlwaysStoppedAnimation(AppBrand.teal),
                      ),
                      Center(
                        child: Text(
                          '$occupancyPct',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // ── Key Cards (lease renewals + maintenance) ──
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 124,
                child: _KeyCard(
                  title: s.t('dashboard.leaseRenewals'),
                  count: '$renewals',
                  icon: Icons.people,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 124,
                child: _KeyCard(
                  title: s.t('dashboard.maintenance'),
                  count: '${store.maintenanceCount} ${s.t('dashboard.active')}',
                  icon: Icons.build,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _KeyCard(
          title: s.t('dashboard.rentPayments'),
          count: money(spent, currency: main),
          icon: Icons.receipt_long,
          wide: true,
          colors: [Colors.orange, Colors.redAccent],
        ),
        const SizedBox(height: 24),
        // ── Financial Summary ──
        Text(s.t('dashboard.thisMonth'),
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: s.t('stat.awaiting.month'),
                cents: store.totalOutstanding,
                currency: main,
                icon: Icons.savings,
                color: Colors.orange,
                caption: foreignCredits > 0
                    ? s.t('stat.awaiting.foreign', [
                        money(foreignCredits, currency: main),
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
                cents: awaiting,
                currency: main,
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
                cents: received,
                currency: main,
                color: Colors.green,
                icon: Icons.trending_up,
                caption: guessedIncome ? s.t('stat.approx') : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: s.t('stat.expenses.month'),
                cents: spent,
                currency: main,
                color: Colors.red,
                icon: Icons.trending_down,
                caption: guessedExpense ? s.t('stat.approx') : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StatCard(
          label: s.t('finance.monthlyTxns'),
          cents: monthlyTransactionCount(store, expenses),
          currency: '',
          icon: Icons.swap_horiz,
          color: Colors.blue,
          plain: true,
        ),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    const iconSize = 52.0;
    return Padding(
      padding: const EdgeInsets.only(top: iconSize * 0.7),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppBrand.tealGradient,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppBrand.tealGradient[1].withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ls(context).t('dashboard.greeting'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ls(context).t('dashboard.subtitle'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -iconSize * 0.6,
            right: 20,
            width: iconSize,
            height: iconSize,
            child: Image.asset(
              'assets/banner_icon.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => CircleAvatar(
                radius: iconSize / 2,
                backgroundColor: AppBrand.gradient[0],
                child: const Icon(Icons.person, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Widget? trailing;
  const _OverviewCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      maxLines: 1,
                      style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 2),
                Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _KeyCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final bool wide;
  final List<Color> colors;
  const _KeyCard({
    required this.title,
    required this.count,
    required this.icon,
    this.wide = false,
    this.colors = AppBrand.gradient,
  });

  Widget _texts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.2)),
        const SizedBox(height: 4),
        Text(count,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors[0].withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: wide
          ? Row(
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(child: _texts()),
                const SizedBox(width: 8),
                Flexible(
                  flex: 0,
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 48, maxHeight: 48),
                    child: Image.asset(
                      'assets/fox_wallet.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(height: 10),
                _texts(),
              ],
            ),
    );
  }
}

class AddUnitDialog extends StatefulWidget {
  final Unit? initial;
  final String currency;
  const AddUnitDialog({super.key, this.initial, required this.currency});

  @override
  State<AddUnitDialog> createState() => AddUnitDialogState();
}

class AddUnitDialogState extends State<AddUnitDialog> {
  late final _number = TextEditingController(text: widget.initial?.number ?? '');
  late final _floor = TextEditingController(text: widget.initial?.floor ?? '');
  late final _rent = TextEditingController(
      text: widget.initial == null
          ? ''
          : moneyInputText(widget.initial!.baseRent));
  late final _extraChargeName =
      TextEditingController(text: widget.initial?.extraChargeName ?? '');
  late final _extraCharge = TextEditingController(
      text: widget.initial == null
          ? ''
          : moneyInputText(widget.initial!.extraCharge));
  late String _status = widget.initial?.status ?? 'vacant';
  late bool _isRented = widget.initial != null ? widget.initial!.isRented : true;
  DateTime? _moveInDate;
  DateTime? _moveOutDate;
  DateTime? _leaseEnd;

  final List<({TextEditingController name, TextEditingController phone})>
      _occupants = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _moveInDate = widget.initial?.moveInDate;
    _moveOutDate = widget.initial?.moveOutDate;
    _leaseEnd = widget.initial?.leaseEnd;
    for (final o in widget.initial?.occupiers ?? const []) {
      _occupants.add((
        name: TextEditingController(text: o.name),
        phone: TextEditingController(text: o.phone),
      ));
    }
    if (_occupants.isEmpty) {
      _addOccupant();
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _floor.dispose();
    _rent.dispose();
    _extraChargeName.dispose();
    _extraCharge.dispose();
    for (final o in _occupants) {
      o.name.dispose();
      o.phone.dispose();
    }
    super.dispose();
  }

  void _addOccupant() {
    setState(() {
      _occupants.add((
        name: TextEditingController(),
        phone: TextEditingController(),
      ));
    });
  }

  void _removeOccupant(int index) {
    if (_occupants.length <= 1) return;
    final o = _occupants.removeAt(index);
    o.name.dispose();
    o.phone.dispose();
    setState(() {});
  }

  Unit? _buildUnit() {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    final rent = tryParseMoney(_rent.text) ?? 0;
    final extraCharge = tryParseMoney(_extraCharge.text) ?? 0;
    final occupiers = _occupants
        .map((o) => Occupant(
              name: o.name.text.trim(),
              phone: o.phone.text.trim(),
            ))
        .where((o) => o.name.isNotEmpty)
        .toList();
    return Unit(
      id: widget.initial?.id ?? 0,
      number: _number.text.trim(),
      floor: _floor.text.trim(),
      status: _status,
      tenantName: occupiers.isEmpty ? '' : occupiers.first.name,
      baseRent: rent,
      extraChargeName: _extraChargeName.text.trim(),
      extraCharge: extraCharge,
      ownedByManagement: widget.initial?.ownedByManagement ?? false,
      occupiers: occupiers,
      isRented: _isRented,
      moveInDate: _moveInDate,
      moveOutDate: _moveOutDate,
      leaseEnd: _leaseEnd,
    );
  }

  void _save() {
    final unit = _buildUnit();
    if (unit == null) return;
    Navigator.pop(context, unit);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final s = strings(context);
    final rent = tryParseMoney(_rent.text) ?? 0;
    final extra = tryParseMoney(_extraCharge.text) ?? 0;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isEdit ? s.t('edit.unit') : s.t('add.unit')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, size: 20),
              label: Text(s.t('save')),
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
              FieldSection(s.t('field.details')),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _number,
                      decoration: InputDecoration(
                          labelText: '${s.t('field.number')} *'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? s.t('required')
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                        controller: _floor,
                        decoration:
                            InputDecoration(labelText: s.t('field.floor'))),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                      value: 'vacant', label: Text(s.t('field.vacant'))),
                  ButtonSegment(
                      value: 'occupied',
                      label: Text(s.t('field.occupied'))),
                  ButtonSegment(
                      value: 'maintenance',
                      label: Text(s.t('field.maintenance'))),
                ],
                selected: {_status},
                onSelectionChanged: (sel) =>
                    setState(() => _status = sel.first),
                showSelectedIcon: false,
                style: const ButtonStyle(
                    visualDensity: VisualDensity.compact),
              ),
              const SizedBox(height: 14),
              FieldSection(s.t('unit.usage')),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text(s.t('unit.rented'))),
                  ButtonSegment(
                      value: false, label: Text(s.t('unit.ownUse'))),
                ],
                selected: {_isRented},
                onSelectionChanged: (sel) =>
                    setState(() => _isRented = sel.first),
                showSelectedIcon: false,
                style: const ButtonStyle(
                    visualDensity: VisualDensity.compact),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(s.t('unit.occupiers'),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall!
                          .copyWith(fontWeight: FontWeight.w600)),
                  IconButton.outlined(
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: _addOccupant,
                    tooltip: s.t('unit.addOccupant'),
                    style: IconButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ],
              ),
              for (var i = 0; i < _occupants.length; i++)
                _OccupantRow(
                    key: ValueKey('occ_${_occupants[i].name.text}_$i'),
                    index: i,
                    nameCtrl: _occupants[i].name,
                    phoneCtrl: _occupants[i].phone,
                    canRemove: _occupants.length > 1,
                    onRemove: () => _removeOccupant(i),
                  ),
              const SizedBox(height: 6),
              FieldSection(s.t('unit.leaseDates')),
              _DateField(
                label: s.t('unit.moveInDate'),
                date: _moveInDate,
                onChanged: (d) => setState(() => _moveInDate = d),
              ),
              const SizedBox(height: 10),
              _DateField(
                label: s.t('unit.moveOutDate'),
                date: _moveOutDate,
                onChanged: (d) => setState(() => _moveOutDate = d),
              ),
              const SizedBox(height: 10),
              _DateField(
                label: s.t('unit.leaseEnd'),
                date: _leaseEnd,
                onChanged: (d) => setState(() => _leaseEnd = d),
              ),
              const SizedBox(height: 14),
              FieldSection(s.t('field.renting')),
              TextFormField(
                controller: _rent,
                keyboardType: moneyKeyboardType,
                inputFormatters: const [MoneyInputFormatter()],
                decoration: InputDecoration(
                  labelText: s.t('field.baseRent'),
                  prefixText: '${moneySymbol(widget.currency)} ',
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _extraChargeName,
                  decoration: InputDecoration(
                    labelText: s.t('field.extraName'),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4),
                    fillColor: Colors.transparent,
                    filled: false,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _extraCharge,
                keyboardType: moneyKeyboardType,
                inputFormatters: const [MoneyInputFormatter()],
                decoration: InputDecoration(
                  labelText: s.t('field.extraAmount'),
                  prefixText: '${moneySymbol(widget.currency)} ',
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calculate_outlined,
                        size: 18,
                        color: scheme.onPrimaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.t('unit.monthlyTotal',
                            [money(rent + extra, currency: widget.currency)]),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OccupantRow extends StatelessWidget {
  final int index;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final bool canRemove;
  final VoidCallback onRemove;

  const _OccupantRow({
    super.key,
    required this.index,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: '${s.t('field.name')} ${index + 1}',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: const [PhoneInputFormatter()],
              decoration: InputDecoration(labelText: s.t('field.phone')),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 22),
            color: canRemove ? Colors.red.shade300 : Colors.grey.shade400,
            onPressed: canRemove ? onRemove : null,
            tooltip: s.t('unit.removeOccupant'),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;
  const _DateField({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = strings(context);
    final text = date == null
        ? ''
        : '${date!.day.toString().padLeft(2, '0')}.${date!.month.toString().padLeft(2, '0')}.${date!.year}';
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2050),
        );
        if (context.mounted) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          text.isEmpty ? s.t('unit.tapToSet') : text,
          style: TextStyle(
            color: text.isEmpty
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}