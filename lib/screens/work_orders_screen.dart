// ignore_for_file: sort_child_properties_last
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/unit_store.dart';
import '../data/work_order_store.dart';
import '../models/unit.dart';
import '../models/work_order.dart';
import '../l10n/app_strings.dart';
import '../theme.dart';
import '../widgets/active_property_label.dart';
import 'work_order_detail_screen.dart';

class WorkOrdersScreen extends StatelessWidget {
  const WorkOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkOrderStore>();
    final unitsReady = context.watch<UnitStore>().isLoaded;
    final s = strings(context);

    if (!store.isLoaded) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final orders = store.orders;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('wo.title')),
        centerTitle: true,
        bottom: AppBrand.barGradient,
        actions: [const ActivePropertyLabel()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16 + AppBrand.bottomPad),
        children: [
          Row(
            children: [
              _SummaryChip(
                  label: s.t('wo.summary.open'),
                  value: store.openCount,
                  color: Colors.orange),
              const SizedBox(width: 8),
              _SummaryChip(
                  label: s.t('wo.summary.inProgress'),
                  value: store.inProgressCount,
                  color: Colors.blue),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: orders.length,
            itemBuilder: (_, i) => _OrderCard(
              key: ValueKey(orders[i].id),
              order: orders[i],
              onDelete: () => _confirmDelete(context, orders[i]),
            ),
          ),
        ],
      ),
      floatingActionButton: unitsReady
          ? Padding(
              padding: EdgeInsets.only(bottom: AppBrand.bottomPad),
              child: AppBrand.gradientFab(
                onPressed: () => _newOrder(context),
                tooltip: s.t('wo.new.title'),
                child: const Icon(Icons.add),
              ),
            )
          : null,
    );
  }

  void _newOrder(BuildContext context) {
    final units = context.read<UnitStore>().units;
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _NewOrderPage(
          unitOptions: units,
          onSave: (order) async {
            await context.read<WorkOrderStore>().add(order);
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WorkOrder order) {
    final s = ls(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('delete.title', [order.title])),
        content: Text(s.t('wo.delete.msg')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.t('cancel'))),
          FilledButton(
            onPressed: () async {
              await context.read<WorkOrderStore>().remove(order.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(s.t('delete')),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
      avatar: Icon(Icons.circle, size: 12, color: color),
      label: Text('$label · $value'),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final WorkOrder order;
  final VoidCallback onDelete;
  const _OrderCard({super.key, required this.order, required this.onDelete});

  Color get _priorityColor => switch (order.priority) {
        'high' => Colors.red,
        'medium' => Colors.orange,
        _ => AppBrand.teal,
      };

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    final statusLabel = switch (order.status) {
      'in_progress' => s.t('status.inProgress'),
      'completed' => s.t('status.completed'),
      _ => s.t('status.open'),
    };
    final priorityLabel = switch (order.priority) {
      'high' => s.t('wo.priority.high'),
      'medium' => s.t('wo.priority.medium'),
      _ => s.t('wo.priority.low'),
    };
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => WorkOrderDetailScreen(orderId: order.id)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dark header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppBrand.charcoal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      order.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          size: 20, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _priorityColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      priorityLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // White body
            Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.home, size: 16, color: AppBrand.charcoal.withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Text(
                        order.unit,
                        style: TextStyle(
                          color: AppBrand.charcoal.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: order.status == 'completed'
                              ? AppBrand.teal.withValues(alpha: 0.12)
                              : AppBrand.gradient[0].withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: order.status == 'completed'
                                ? AppBrand.teal
                                : AppBrand.gradient[0],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (order.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      order.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppBrand.charcoal.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (order.assignedTo.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person, size: 14, color: AppBrand.charcoal.withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Text(
                          order.assignedTo,
                          style: TextStyle(
                            color: AppBrand.charcoal.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewOrderPage extends StatefulWidget {
  final List<Unit> unitOptions;
  final Future<void> Function(WorkOrder order) onSave;

  const _NewOrderPage({required this.unitOptions, required this.onSave});

  @override
  State<_NewOrderPage> createState() => _NewOrderPageState();
}

class _NewOrderPageState extends State<_NewOrderPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  String? _selectedUnitId;
  String _category = 'Plumbing';
  String _priority = 'medium';
  String? _unitError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.unitOptions.length == 1) {
      _selectedUnitId = widget.unitOptions.first.id.toString();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (_selectedUnitId == null || title.isEmpty) {
      setState(() => _unitError = _selectedUnitId == null
          ? ls(context).t('wo.invalidUnit')
          : null);
      return;
    }
    final match = widget.unitOptions.cast<Unit?>().firstWhere(
      (u) => u!.id.toString() == _selectedUnitId,
      orElse: () => null,
    );
    if (match == null) {
      setState(() => _unitError = ls(context).t('wo.invalidUnit'));
      return;
    }
    setState(() { _unitError = null; _isSaving = true; });
    try {
      final order = WorkOrder(
        id: 0,
        unit: match.number,
        category: _category,
        title: title,
        description: _description.text.trim(),
        priority: _priority,
        status: 'open',
        assignedTo: '',
        createdAt: DateTime.now(),
      );
      await widget.onSave(order);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ls(context).t('wo.invalidUnit')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('wo.new.title')),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: Text(s.t('cancel')),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            child: _isSaving
                ? const SizedBox(
                    height: 16, width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(s.t('wo.create')),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedUnitId,
              decoration: InputDecoration(
                labelText: '${s.t('field.unit')} *',
                errorText: _unitError,
              ),
              items: [
                for (final u in widget.unitOptions)
                  DropdownMenuItem(
                    value: u.id.toString(),
                    child: Text(
                      '${u.number}${u.occupiers.isNotEmpty ? ' — ${u.occupiers.first.name}' : ''}',
                    ),
                  ),
              ],
              onChanged: (v) => setState(() {
                _selectedUnitId = v;
                _unitError = null;
              }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: s.t('field.category')),
              items: [for (final (v, k) in const [
                ('Plumbing', 'wo.cat.plumbing'),
                ('Electrical', 'wo.cat.electrical'),
                ('HVAC', 'wo.cat.hvac'),
                ('General', 'wo.cat.general'),
              ])
                DropdownMenuItem(value: v, child: Text(s.t(k)))],
              onChanged: (v) => setState(() => _category = v ?? 'Plumbing'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: '${s.t('field.title')} *'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _description,
              maxLines: 4,
              decoration: InputDecoration(labelText: s.t('field.desc')),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: InputDecoration(labelText: s.t('field.priority')),
              items: [for (final (v, l) in [
                ('high', 'wo.priority.high'),
                ('medium', 'wo.priority.medium'),
                ('low', 'wo.priority.low'),
              ])
                DropdownMenuItem(value: v, child: Text(s.t(l)))],
              onChanged: (v) => setState(() => _priority = v ?? 'medium'),
            ),
          ],
        ),
      ),
    );
  }
}