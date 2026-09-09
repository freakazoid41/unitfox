import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/account_store.dart';
import '../data/expense_store.dart';
import '../data/unit_store.dart';
import '../l10n/app_strings.dart';
import '../models/payment.dart';
import '../utils/money.dart';
import 'attachment_viewer_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  DateTime? _from;
  DateTime? _to;
  int? _unitFilter;
  String _typeFilter = 'all'; // all | income | expense
  String? _incomeTypeFilter; // Aidat | Yakıt | Diğer | null = all

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitStore>();
    final acct = context.watch<AccountStore>();
    final s = ls(context);

    final allTxns = acct.transactions(from: _from, to: _to);
    final txns = allTxns
        .where((t) => _typeFilter == 'all' || t.kind == _typeFilter)
        .where((t) =>
            _incomeTypeFilter == null ||
            (t.kind == 'income' && t.paymentType == _incomeTypeFilter))
        .where((t) => _unitFilter == null || t.unitId == _unitFilter)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('finance.transactions')),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: s.t('tx.filterDate'),
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
          ),
        ],
      ),
      body: (!units.isLoaded || !acct.isLoaded)
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickRange,
                        icon: const Icon(Icons.filter_list),
                        label: Text(_rangeLabel),
                      ),
                    ),
                    if (_from != null || _to != null)
                      IconButton(
                          onPressed: () => setState(() {
                                _from = null;
                                _to = null;
                              }),
                          icon: const Icon(Icons.clear)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue: _unitFilter,
                        decoration:
                            InputDecoration(labelText: s.t('field.unit')),
                        items: [
                          DropdownMenuItem<int?>(
                              value: null, child: Text(s.t('tx.allUnits'))),
                          ...units.units.map((u) => DropdownMenuItem<int?>(
                              value: u.id, child: Text(u.number))),
                        ],
                        onChanged: (v) => setState(() => _unitFilter = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _typeFilter,
                        decoration:
                            InputDecoration(labelText: s.t('field.type')),
                        items: [
                          DropdownMenuItem(
                              value: 'all', child: Text(s.t('tx.all'))),
                          DropdownMenuItem(
                              value: 'income',
                              child: Text(s.t('tx.kind.income'))),
                          DropdownMenuItem(
                              value: 'expense',
                              child: Text(s.t('tx.kind.expense'))),
                        ],
                        onChanged: (v) =>
                            setState(() => _typeFilter = v ?? 'all'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _incomeTypeFilter,
                  decoration:
                      InputDecoration(labelText: s.t('tx.incomeType')),
                  items: [
                    DropdownMenuItem<String?>(
                        value: null, child: Text(s.t('tx.allIncomeTypes'))),
                    DropdownMenuItem(
                        value: PaymentType.aidat, child: Text(s.t('incomeType.aidat'))),
                    DropdownMenuItem(
                        value: PaymentType.fuel, child: Text(s.t('incomeType.fuel'))),
                    DropdownMenuItem(
                        value: PaymentType.other, child: Text(s.t('incomeType.other'))),
                  ],
                  onChanged: (v) => setState(() => _incomeTypeFilter = v),
                ),
                const SizedBox(height: 8),
                Text(s.t('tx.log'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (txns.isEmpty)
                  Text(s.t('tx.noMatch'))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: txns.length,
                    itemBuilder: (_, i) => _TxnRow(
                      key: ValueKey('${txns[i].kind}-${txns[i].ownerId}-${txns[i].date.millisecondsSinceEpoch}'),
                      txn: txns[i],
                    ),
                  ),
              ],
            ),
    );
  }

  String get _rangeLabel {
    final s = ls(context);
    if (_from == null && _to == null) return s.t('tx.allTime');
    String f(DateTime d) =>
        '${d.day}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    final from = _from == null ? '' : f(_from!);
    final to = _to == null ? '' : f(_to!);
    return '$from — $to';
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      initialDateRange: (_from != null && _to != null)
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }
}

class _TxnRow extends StatefulWidget {
  final Txn txn;
  const _TxnRow({super.key, required this.txn});

  @override
  State<_TxnRow> createState() => _TxnRowState();
}

class _TxnRowState extends State<_TxnRow> {
  bool _loading = false;

  bool get _hasAttachment =>
      widget.txn.attachment != null || widget.txn.attachmentName.isNotEmpty;

  Future<void> _openAttachment() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final t = widget.txn;
      if (t.attachmentName.isEmpty) return;
      final acct = context.read<AccountStore>();
      final bytes = t.attachment ??
          (t.kind == 'income'
              ? await acct.paymentAttachment(t.ownerId!)
              : await acct.expenseAttachment(t.ownerId!));
      if (bytes == null) return;
      if (!mounted) return;
      final fileName =
          t.attachmentName.isEmpty ? 'attachment.pdf' : t.attachmentName;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AttachmentViewerScreen(bytes: bytes, name: fileName),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    final t = widget.txn;
    final isIn = t.kind == 'income';
    final color = isIn ? Colors.green : Colors.orange;
    final acctName = context.watch<AccountStore>().accountName(t.accountId);
    final kindLabel = isIn ? s.t('tx.kind.income') : s.t('tx.kind.expense');
    final unitNum = t.unitId != null
        ? context.read<AccountStore>().unitNumber(t.unitId!)
        : null;
    final typeLabel = t.paymentType != null
        ? _translatePaymentType(s, t.paymentType!)
        : null;
    final title = unitNum != null && typeLabel != null
        ? '$unitNum · $typeLabel'
        : (unitNum ?? t.label);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(isIn ? Icons.south_west : Icons.north_east, color: color),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${_dl(t.date)} · $kindLabel'
            '${acctName != null ? ' · $acctName' : ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(money(t.amount, currency: t.currency),
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isIn ? Colors.green : Colors.red)),
            PopupMenuButton<String>(
              tooltip: '',
              padding: EdgeInsets.zero,
              onSelected: (v) => _handleMenu(v, context, t),
              icon: const Icon(Icons.more_vert, size: 20),
              itemBuilder: (_) => [
                if (_hasAttachment)
                  PopupMenuItem(
                    value: 'view',
                    child: Row(children: [
                      const Icon(Icons.attach_file, size: 18),
                      const SizedBox(width: 8),
                      Text(s.t('wo.proof.title')),
                    ]),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                    const SizedBox(width: 8),
                    Text(s.t('delete'), style: TextStyle(color: Colors.red.shade400)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenu(String action, BuildContext context, Txn t) async {
    if (action == 'view') {
      _openAttachment();
      return;
    }
    if (action != 'delete') return;
    final s = ls(context);
    final acct = context.read<AccountStore>();
    final unitStore = context.read<UnitStore>();
    final expenseStore = context.read<ExpenseStore>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('delete.title', [t.label])),
        content: Text(s.t('delete')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.t('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      if (t.kind == 'income' && t.ownerId != null) {
        await acct.removePayment(t.ownerId!);
        unitStore.removePayment(t.ownerId!);
      } else if (t.kind == 'expense' && t.ownerId != null) {
        await expenseStore.remove(t.ownerId!);
        await acct.refreshTransactions();
      }
    }
  }

  String _dl(DateTime d) =>
      '${d.day}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _translatePaymentType(AppStrings s, String type) {
    switch (type) {
      case 'Aidat':
        return s.t('incomeType.aidat');
      case 'Yakıt':
        return s.t('incomeType.fuel');
      case 'Diğer':
        return s.t('incomeType.other');
      default:
        return type;
    }
  }
}