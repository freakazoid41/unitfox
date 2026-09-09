import 'package:flutter/foundation.dart';

import 'local_db.dart';

/// A single apartment building / property the manager runs. Each property
/// owns its own units, accounts, expenses, work orders, staff and currency.
class Property {
  final int id;
  final String name;
  final String address;
  final String currency;
  final DateTime createdAt;

  const Property({
    required this.id,
    required this.name,
    this.address = '',
    required this.currency,
    required this.createdAt,
  });

  factory Property.fromRow(Map<String, Object?> row) => Property(
        id: row['id'] as int,
        name: (row['name'] as String?) ?? '',
        address: (row['address'] as String?) ?? '',
        currency: (row['currency'] as String?) ?? 'EUR',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      );

  Map<String, Object?> toRow() => {
        'name': name,
        'address': address,
        'currency': currency,
        'created_at': createdAt.millisecondsSinceEpoch,
      };
}

/// Holds the manager's portfolio of properties and which one is active.
/// The active property also drives the display currency used across the app.
class SiteStore extends ChangeNotifier {
  final bool _usePersistence;
  List<Property> _properties = [];
  int? _activePropertyId;
  bool _loaded = false;

  SiteStore({bool usePersistence = true}) : _usePersistence = usePersistence;

  bool get isLoaded => _loaded;
  bool get onboarded => _activePropertyId != null;
  List<Property> get properties => List.unmodifiable(_properties);

  Property? get activeProperty {
    for (final p in _properties) {
      if (p.id == _activePropertyId) return p;
    }
    return null;
  }

  int? get activePropertyId => _activePropertyId;

  /// The active property's name (or the first property / placeholder).
  String get siteName => activeProperty?.name ?? '';
  String get mainCurrency => activeProperty?.currency ?? 'EUR';

  Future<void> load() async {
    if (!_usePersistence) {
      _properties = [
        Property(
          id: 1,
          name: 'Sunset Villa',
          currency: 'EUR',
          createdAt: DateTime(2020),
        ),
      ];
      _activePropertyId = 1;
      _loaded = true;
      notifyListeners();
      return;
    }
    final rows = await LocalDB.getProperties();
    _properties = rows.map(Property.fromRow).toList();
    _activePropertyId = _properties.isEmpty
        ? null
        : await LocalDB.getActivePropertyId() ??
            _properties.first.id;
    if (_activePropertyId != null &&
        !_properties.any((p) => p.id == _activePropertyId)) {
      _activePropertyId = _properties.first.id;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Switches the app to a different property and persists the selection.
  Future<void> switchProperty(int propertyId) async {
    if (_activePropertyId == propertyId) return;
    _activePropertyId = propertyId;
    if (_usePersistence) await LocalDB.setActivePropertyId(propertyId);
    notifyListeners();
  }

  /// Called after [LocalDB.completeOnboardingAtomic] has written the
  /// property + accounts + units in a single transaction. Updates the
  /// in-memory state so the UI transitions into HomeShell immediately.
  Future<void> completeOnboardingFromDb(
      int propertyId, String name, String currency) async {
    _properties = [
      ..._properties,
      Property(
        id: propertyId,
        name: name,
        currency: currency,
        createdAt: DateTime.now(),
      ),
    ];
    _activePropertyId = propertyId;
    notifyListeners();
  }

  /// Called when the first-run wizard finishes: creates the first property and
  /// marks it active. Returns the new property's id.
  Future<int> completeOnboarding(String name, String currency) async {
    late final Property created;
    if (_usePersistence) {
      final id = await LocalDB.insertProperty(Property(
        id: 0,
        name: name.trim(),
        currency: currency,
        createdAt: DateTime.now(),
      ).toRow());
      created = Property(
        id: id,
        name: name.trim(),
        currency: currency,
        createdAt: DateTime.now(),
      );
      await LocalDB.setActivePropertyId(id);
    } else {
      created = Property(
        id: 1,
        name: name.trim(),
        currency: currency,
        createdAt: DateTime.now(),
      );
    }
    _properties = [..._properties, created];
    _activePropertyId = created.id;
    notifyListeners();
    return created.id;
  }

  /// Adds a new empty property under the portfolio.
  Future<Property> addProperty(String name, String currency,
      {String address = ''}) async {
    final now = DateTime.now();
    late final Property created;
    if (_usePersistence) {
      final id = await LocalDB.insertProperty(
        Property(id: 0, name: name.trim(), currency: currency, address: address, createdAt: now)
            .toRow(),
      );
      created = Property(
          id: id, name: name.trim(), currency: currency, address: address, createdAt: now);
    } else {
      final maxId = _properties.isEmpty
          ? 0
          : _properties.map((p) => p.id).reduce((a, b) => a > b ? a : b);
      created = Property(
          id: maxId + 1,
          name: name.trim(),
          currency: currency,
          address: address,
          createdAt: now);
    }
    _properties = [..._properties, created];
    notifyListeners();
    return created;
  }

  /// Edits an existing property's details. If the edited property is the active
  /// one, the display currency updates everywhere automatically.
  Future<void> updateProperty(int id, String name, String currency,
      {String address = ''}) async {
    final index = _properties.indexWhere((p) => p.id == id);
    if (index == -1) return;
    final old = _properties[index];
    final updated = Property(
      id: old.id,
      name: name.trim(),
      currency: currency,
      address: address,
      createdAt: old.createdAt,
    );
    if (_usePersistence) {
      await LocalDB.updateProperty(id, {
        'name': updated.name,
        'currency': updated.currency,
        'address': updated.address,
      });
    }
    _properties = [..._properties]..[index] = updated;
    notifyListeners();
  }

  /// Removes a property and all its scoped data. De-selects it if active,
  /// falling back to the first remaining property.
  Future<void> deleteProperty(int id) async {
    if (_usePersistence) await LocalDB.deleteProperty(id);
    _properties = _properties.where((p) => p.id != id).toList();
    if (_activePropertyId == id) {
      _activePropertyId = _properties.isEmpty ? null : _properties.first.id;
      if (_usePersistence && _activePropertyId != null) {
        await LocalDB.setActivePropertyId(_activePropertyId!);
      }
    }
    notifyListeners();
  }

  /// Used by Account Screen to keep the active property's display currency in
  /// sync when its cash account currency changes.
  Future<void> updateMainCurrency(String currency) async {
    final p = activeProperty;
    if (p == null || p.currency == currency) return;
    if (_usePersistence) {
      await LocalDB.updateProperty(p.id, {'currency': currency});
    }
    final updated = Property(
      id: p.id,
      name: p.name,
      address: p.address,
      currency: currency,
      createdAt: p.createdAt,
    );
    _properties =
        _properties.map((x) => x.id == p.id ? updated : x).toList();
    notifyListeners();
  }
}