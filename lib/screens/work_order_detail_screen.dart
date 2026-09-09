import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/staff_store.dart';
import '../data/work_order_store.dart';
import '../l10n/app_strings.dart';
import '../models/work_order.dart';
import 'attachment_viewer_screen.dart';

class WorkOrderDetailScreen extends StatelessWidget {
  final int orderId;
  const WorkOrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    final store = context.watch<WorkOrderStore>();
    final matches = store.orders.where((o) => o.id == orderId);
    if (matches.isEmpty) {
      return Scaffold(
        body: Center(child: Text(s.t('wo.notFound'))),
      );
    }
    final order = matches.first;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isOpen = order.status == 'open';
    final isDone = order.status == 'completed';

    final priorityColor = switch (order.priority) {
      'high' => Colors.red,
      'medium' => Colors.orange,
      _ => Colors.green,
    };

    final statusLabel = switch (order.status) {
      'in_progress' => s.t('status.inProgress'),
      'completed' => s.t('status.completed'),
      _ => s.t('status.open'),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('${order.unit} · ${order.category}'),
        actions: [
          IconButton(
            tooltip: s.t('delete'),
            onPressed: () => _confirmDelete(context, order.id),
            icon: const Icon(Icons.delete_outline, size: 22),
            style: IconButton.styleFrom(
              foregroundColor: Colors.red.withValues(alpha: 0.8),
              backgroundColor: Colors.red.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.priority.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: priorityColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDone
                        ? Colors.green.withValues(alpha: 0.12)
                        : scheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          isDone ? Colors.green : scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(order.title,
                style: theme.textTheme.headlineSmall!
                    .copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            if (order.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(order.description,
                  style: theme.textTheme.bodyMedium!
                      .copyWith(color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 20),
            _InfoRow(
                icon: Icons.build_outlined,
                label: s.t('field.category'),
                value: order.category),
            _InfoRow(
                icon: Icons.priority_high,
                label: s.t('field.priority'),
                value: order.priority),
            _InfoRow(
                icon: Icons.person_outline,
                label: s.t('wo.detail.assignedTo'),
                value: order.assignedTo.isEmpty
                    ? s.t('wo.unassigned')
                    : order.assignedTo),
            _InfoRow(
                icon: Icons.schedule,
                label: s.t('wo.detail.status'),
                value: statusLabel),
            _InfoRow(
                icon: Icons.calendar_today,
                label: s.t('wo.detail.created'),
                value: _fmt(context, order.createdAt)),
            if (order.completedAt != null)
              _InfoRow(
                  icon: Icons.task_alt,
                  label: s.t('wo.detail.completed'),
                  value: _fmt(context, order.completedAt!)),
            const SizedBox(height: 24),
            if (isDone && order.photoProof != null)
              _ProofImage(store: store, order: order),
            if (!isDone)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: Icon(isOpen ? Icons.send : Icons.check),
                  label: Text(isOpen
                      ? s.t('wo.dispatchBtn')
                      : s.t('wo.completeBtn')),
                  onPressed: () {
                    if (isOpen) {
                      _dispatch(context, order.id);
                    } else {
                      _complete(context, store, order.id);
                    }
                  },
                ),
              ),
            if (isDone)
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 48),
                    const SizedBox(height: 6),
                    Text(s.t('status.completed'),
                        style: const TextStyle(color: Colors.green)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, int id) {
    final s = ls(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('wo.delete.msg')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.t('cancel'))),
          FilledButton(
            onPressed: () async {
              await context.read<WorkOrderStore>().remove(id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(s.t('delete')),
          ),
        ],
      ),
    );
  }

  void _dispatch(BuildContext context, int id) {
    final s = ls(context);
    final crew = context.read<StaffStore>();
    showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.t('wo.dispatch.title')),
        children: crew.members.isEmpty
            ? [
                SimpleDialogOption(child: Text(s.t('wo.noCrew'))),
              ]
            : crew.members
                .map((m) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, m.dispatchLabel),
                      child: Text(m.dispatchLabel),
                    ))
                .toList(),
      ),
    ).then((staff) {
      if (staff != null && context.mounted) {
        context.read<WorkOrderStore>().dispatch(id, staff);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.t('wo.dispatched', [staff]))));
      }
    });
  }

  void _complete(BuildContext context, WorkOrderStore store, int id) async {
    final s = ls(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(s.t('wo.photo.take')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(s.t('wo.photo.gallery')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || source == null) return;

    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: source, imageQuality: 85);
    if (!context.mounted || xFile == null) return;

    final bytes = await xFile.readAsBytes();
    final name = xFile.name;
    final label = '$name (${bytes.length ~/ 1024} KB)';
    await store.complete(id, photoProof: label, proofBytes: bytes);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.t('wo.completedPhoto'))));
  }

  String _fmt(BuildContext context, DateTime t) {
    final m = ls(context).t('month.${['jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'][t.month - 1]}');
    return '${t.day} $m ${t.year}, '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

/// Loads a completed order's proof image on demand (the blob isn't kept in the
/// in-memory order list) and shows it downsampled for memory.
class _ProofImage extends StatefulWidget {
  final WorkOrderStore store;
  final WorkOrder order;
  const _ProofImage({required this.store, required this.order});

  @override
  State<_ProofImage> createState() => _ProofImageState();
}

class _ProofImageState extends State<_ProofImage> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.store.proofFor(widget.order.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = ls(context);
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snap) {
        final bytes = snap.data ?? widget.order.proofBytes;
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (bytes == null) {
return Card(
            child: ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: Text(widget.order.photoProof!),
              subtitle: Text(s.t('wo.proof.title')),
              dense: true,
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AttachmentViewerScreen(
                    bytes: bytes,
                    name: widget.order.photoProof ?? 'photo.jpg',
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  // Decode at a bound size; the viewer shows full resolution.
                  cacheWidth: 1200,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(widget.order.photoProof!,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    color: scheme.onSurfaceVariant, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
