import 'package:flutter/foundation.dart';

import '../models/staff_member.dart';
import 'local_db.dart';

/// Manages the maintenance crew. Crew members are the people work orders can
/// be dispatched to. Stored locally; seeded with a sensible default crew on
/// first run (unless the site has already been onboarded).
class StaffStore extends ChangeNotifier {
  final bool _usePersistence;
  int _propertyId = 0;
  int _loadGen = 0;
  List<StaffMember> _members = [];
  bool _loaded = false;

  StaffStore({bool usePersistence = true})
      : _usePersistence = usePersistence;

  List<StaffMember> get members => List.unmodifiable(_members);
  int get propertyId => _propertyId;
  bool get isLoaded => _loaded;

  Future<void> load({int? propertyId, bool seedIfEmpty = true}) async {
    final gen = ++_loadGen;
    _propertyId = propertyId ?? _propertyId;
    if (!_usePersistence) {
      _members = _seed();
      _loaded = true;
      notifyListeners();
      return;
    }
    var rows = await LocalDB.getStaffMembers(_propertyId);
    if (rows.isEmpty && seedIfEmpty && !await LocalDB.isOnboarded()) {
      for (final s in _seed()) {
        final id = await LocalDB.insertStaffMember({
          'property_id': _propertyId,
          'name': s.name,
          'role': s.role,
          'phone': s.phone,
          'salary': s.salary,
          'created_at': s.createdAt.millisecondsSinceEpoch,
        });
        _members = [..._members, StaffMember(
          id: id,
          name: s.name,
          role: s.role,
          phone: s.phone,
          salary: s.salary,
          createdAt: s.createdAt,
        )];
      }
      _members.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      rows = await LocalDB.getStaffMembers(_propertyId);
    }
    if (gen != _loadGen) return;
    _members = rows.map(StaffMember.fromRow).toList();
    _loaded = true;
    notifyListeners();
  }

  Future<void> add(StaffMember member) async {
    if (!_usePersistence) {
      _members = [..._members, member];
      _members.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      notifyListeners();
      return;
    }
    final id = await LocalDB.insertStaffMember({
      'property_id': _propertyId,
      'name': member.name,
      'role': member.role,
      'phone': member.phone,
      'salary': member.salary,
      'created_at': member.createdAt.millisecondsSinceEpoch,
    });
    _members = [..._members, StaffMember(
      id: id,
      name: member.name,
      role: member.role,
      phone: member.phone,
      salary: member.salary,
      createdAt: member.createdAt,
    )];
    _members.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
  }

  Future<void> update(
      int id, String name, String role, String phone, int salary) async {
    if (_usePersistence) {
      await LocalDB.updateStaffMember(id, {
        'name': name,
        'role': role,
        'phone': phone,
        'salary': salary,
      });
      // Update work order references that still point at the old name.
      final old = _members.where((m) => m.id == id);
      if (old.isNotEmpty) {
        final oldName = old.first.name;
        if (oldName != name) {
          final woRows = await LocalDB.db.query('work_orders',
              where: 'assigned_to = ?', whereArgs: [oldName]);
          for (final row in woRows) {
            await LocalDB.updateWorkOrderStatus(row['id'] as int,
                row['status'] as String, assignedTo: name);
          }
        }
      }
    }
    _members = [
      for (final m in _members)
        if (m.id == id)
          m.copyWith(name: name, role: role, phone: phone, salary: salary)
        else
          m,
    ];
    notifyListeners();
  }

  Future<void> remove(int id) async {
    if (_usePersistence) {
      // Clear work order references before deleting the staff member.
      final member = _members.where((m) => m.id == id);
      if (member.isNotEmpty) {
        final name = member.first.name;
        final woRows = await LocalDB.db.query('work_orders',
            where: 'assigned_to = ?', whereArgs: [name]);
        for (final row in woRows) {
          await LocalDB.updateWorkOrderStatus(row['id'] as int,
              row['status'] as String, assignedTo: '');
        }
      }
      await LocalDB.deleteStaffMember(id);
    }
    _members = _members.where((m) => m.id != id).toList();
    notifyListeners();
  }

  List<StaffMember> _seed() {
    final now = DateTime.now();
    return [
      StaffMember(id: 0, name: 'Mike', role: 'HVAC', createdAt: now),
      StaffMember(id: 0, name: 'Sara', role: 'Plumbing', createdAt: now),
      StaffMember(id: 0, name: 'General crew', createdAt: now),
    ];
  }
}