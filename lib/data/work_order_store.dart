import 'package:flutter/foundation.dart';

import '../models/work_order.dart';
import 'local_db.dart';

class WorkOrderStore extends ChangeNotifier {
  final bool _usePersistence;
  int _propertyId = 0;
  int _loadGen = 0;
  List<WorkOrder> _orders = [];
  bool _loaded = false;

  WorkOrderStore({bool usePersistence = true})
      : _usePersistence = usePersistence;

  List<WorkOrder> get orders => List.unmodifiable(_orders);
  int get propertyId => _propertyId;
  int get openCount => _orders.where((o) => o.status == 'open').length;
  int get inProgressCount =>
      _orders.where((o) => o.status == 'in_progress').length;
  bool get isLoaded => _loaded;

  /// Loads from the local DB. Since the DB is the source of truth, the UI
  /// renders instantly from disk with zero network dependency.
  Future<void> load({int? propertyId, bool seedIfEmpty = true}) async {
    final gen = ++_loadGen;
    _propertyId = propertyId ?? _propertyId;
    if (!_usePersistence) {
      _orders = _seed();
      _loaded = true;
      notifyListeners();
      return;
    }
    var rows =
        await LocalDB.getWorkOrders(propertyId: _propertyId, includeBlob: false);
    if (rows.isEmpty && seedIfEmpty && !await LocalDB.isOnboarded()) {
      final seeded = <WorkOrder>[];
      for (final w in _seed()) {
        final id = await LocalDB.insertWorkOrder(w, propertyId: _propertyId);
        seeded.add(_withId(w, id));
      }
      rows = seeded..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    if (gen != _loadGen) return;
    _orders = rows;
    _loaded = true;
    notifyListeners();
  }

  /// Fetches a completed order's proof image bytes on demand.
  Future<Uint8List?> proofFor(int id) => LocalDB.getWorkOrderProof(id);

  /// Optimistic local write + outbox. UI updates immediately; sync follows.
  /// Saves old state for rollback if the DB write fails.
  Future<void> dispatch(int id, String staff) async {
    final i = _orders.indexWhere((o) => o.id == id);
    if (i == -1) return;
    final oldOrder = _orders[i];
    _orders[i] = _orders[i].copyWith(status: 'in_progress', assignedTo: staff);
    try {
      await LocalDB.updateWorkOrderStatus(id, 'in_progress', assignedTo: staff);
      notifyListeners();
    } catch (e) {
      _orders[i] = oldOrder;
      rethrow;
    }
  }

  Future<void> complete(int id, {String? photoProof, Uint8List? proofBytes}) async {
    final i = _orders.indexWhere((o) => o.id == id);
    if (i == -1) return;
    final oldOrder = _orders[i];
    final now = DateTime.now();
    _orders[i] = _orders[i].copyWith(
        status: 'completed', completedAt: now, photoProof: photoProof);
    try {
      await LocalDB.updateWorkOrderStatus(id, 'completed',
          completedAt: now, photoProof: photoProof, proofBytes: proofBytes);
      notifyListeners();
    } catch (e) {
      _orders[i] = oldOrder;
      rethrow;
    }
  }

  Future<void> add(WorkOrder order) async {
    final id = await LocalDB.insertWorkOrder(order, propertyId: _propertyId);
    final created = _withId(order, id);
    _orders.insert(0, created);
    _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  /// Deletes a work order and its proof photo. Removes it from memory and the
  /// DB so it disappears immediately and never returns on reload.
  Future<void> remove(int id) async {
    await LocalDB.deleteWorkOrder(id);
    _orders = _orders.where((o) => o.id != id).toList();
    notifyListeners();
  }

  WorkOrder _withId(WorkOrder order, int id) => WorkOrder(
        id: id,
        unit: order.unit,
        category: order.category,
        title: order.title,
        description: order.description,
        priority: order.priority,
        status: order.status,
        assignedTo: order.assignedTo,
        createdAt: order.createdAt,
        completedAt: order.completedAt,
        photoProof: order.photoProof,
        proofBytes: order.proofBytes,
      );

  List<WorkOrder> _seed() => [
        WorkOrder(
          id: 0,
          unit: 'B-202',
          category: 'Plumbing',
          title: 'Washing machine leak',
          description:
              'Water leaking from under the sink in the laundry. Needs immediate attention.',
          priority: 'high',
          status: 'open',
          assignedTo: '',
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
        WorkOrder(
          id: 0,
          unit: 'A-102',
          category: 'Electrical',
          title: 'Kitchen outlet not working',
          description: 'Top-left socket in the kitchen has no power.',
          priority: 'medium',
          status: 'open',
          assignedTo: '',
          createdAt: DateTime.now().subtract(const Duration(hours: 7)),
        ),
        WorkOrder(
          id: 0,
          unit: 'C-301',
          category: 'HVAC',
          title: 'AC not cooling',
          description: 'Aircon runs but room stays warm.',
          priority: 'high',
          status: 'in_progress',
          assignedTo: 'Mike (HVAC)',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
}