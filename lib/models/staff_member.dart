/// A member of the maintenance crew who work orders can be dispatched to.
/// A crew member may draw a monthly [salary], owed by the site every month.
class StaffMember {
  final int id;
  final String name;
  final String role;
  final String phone;
  final int salary; // minor units (cents) per month
  final DateTime createdAt;

  const StaffMember({
    required this.id,
    required this.name,
    this.role = '',
    this.phone = '',
    this.salary = 0,
    required this.createdAt,
  });

  factory StaffMember.fromRow(Map<String, Object?> row) => StaffMember(
        id: row['id'] as int,
        name: (row['name'] as String?) ?? '',
        role: (row['role'] as String?) ?? '',
        phone: (row['phone'] as String?) ?? '',
        salary: ((row['salary'] as num?) ?? 0).toInt(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      );

  /// Compact "Name (Role)" used when dispatching work orders.
  String get dispatchLabel =>
      role.isEmpty ? name : '$name ($role)';

  StaffMember copyWith(
          {String? name, String? role, String? phone, int? salary}) =>
      StaffMember(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        phone: phone ?? this.phone,
        salary: salary ?? this.salary,
        createdAt: createdAt,
      );
}