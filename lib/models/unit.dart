import 'dart:convert';

class Occupant {
  final String name;
  final String phone;

  const Occupant({required this.name, this.phone = ''});

  factory Occupant.fromMap(Map<String, dynamic> m) => Occupant(
        name: (m['name'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
      );

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone};

  String get displayLabel =>
      phone.isEmpty ? name : '$name · $phone';
}

class Unit {
  final int id;
  final int propertyId;
  final String number;
  final String floor;
  final String status;
  final String tenantName;
  final int baseRent; // minor units (cents)
  final String extraChargeName;
  final int extraCharge; // minor units (cents)
  final bool ownedByManagement;
  final List<Occupant> occupiers;
  final bool isRented;
  final DateTime? moveInDate;
  final DateTime? moveOutDate;
  final DateTime? leaseEnd;

  const Unit({
    required this.id,
    this.propertyId = 0,
    required this.number,
    required this.floor,
    required this.status,
    required this.tenantName,
    this.baseRent = 0,
    this.extraChargeName = '',
    this.extraCharge = 0,
    this.ownedByManagement = false,
    this.occupiers = const [],
    this.isRented = true,
    this.moveInDate,
    this.moveOutDate,
    this.leaseEnd,
  });

  int get monthlyCharge => baseRent + extraCharge;

  /// Sentinel to pass to [copyWith]'s lease-date parameters when you want to
  /// explicitly clear a date back to null (a plain `null` keeps the old value).
  static const Object clearDate = Object();

  /// Pass [clearDate] to wipe a lease date; omit the parameter (or pass null)
  /// to carry the existing value over.
  Unit copyWith({
    int? propertyId,
    String? number,
    String? floor,
    String? status,
    String? tenantName,
    int? baseRent,
    String? extraChargeName,
    int? extraCharge,
    bool? ownedByManagement,
    List<Occupant>? occupiers,
    bool? isRented,
    Object? moveInDate,
    Object? moveOutDate,
    Object? leaseEnd,
  }) {
    return Unit(
      id: id,
      propertyId: propertyId ?? this.propertyId,
      number: number ?? this.number,
      floor: floor ?? this.floor,
      status: status ?? this.status,
      tenantName: tenantName ?? this.tenantName,
      baseRent: baseRent ?? this.baseRent,
      extraChargeName: extraChargeName ?? this.extraChargeName,
      extraCharge: extraCharge ?? this.extraCharge,
      ownedByManagement: ownedByManagement ?? this.ownedByManagement,
      occupiers: occupiers ?? this.occupiers,
      isRented: isRented ?? this.isRented,
      moveInDate: identical(moveInDate, clearDate)
          ? null
          : (moveInDate as DateTime?) ?? this.moveInDate,
      moveOutDate: identical(moveOutDate, clearDate)
          ? null
          : (moveOutDate as DateTime?) ?? this.moveOutDate,
      leaseEnd: identical(leaseEnd, clearDate)
          ? null
          : (leaseEnd as DateTime?) ?? this.leaseEnd,
    );
  }

  static List<Occupant> _parseOccupiers(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => Occupant.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  static String _encodeOccupiers(List<Occupant> list) =>
      jsonEncode(list.map((o) => o.toMap()).toList());

  factory Unit.fromRow(Map<String, Object?> row) => Unit(
        id: row['id'] as int,
        propertyId: ((row['property_id'] as num?) ?? 0).toInt(),
        number: row['number'] as String,
        floor: (row['floor'] as String?) ?? '',
        status: (row['status'] as String?) ?? 'vacant',
        tenantName: (row['tenant_name'] as String?) ?? '',
        baseRent: ((row['base_rent'] as num?) ?? 0).toInt(),
        extraChargeName: (row['extra_charge_name'] as String?) ?? '',
        extraCharge: ((row['extra_charge'] as num?) ?? 0).toInt(),
        ownedByManagement: ((row['owned_by_management'] as int?) ?? 0) == 1,
        occupiers: _parseOccupiers(row['occupiers'] as String?),
        isRented: ((row['is_rented'] as int?) ?? 1) != 0,
        moveInDate: row['move_in_date'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['move_in_date'] as int),
        moveOutDate: row['move_out_date'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['move_out_date'] as int),
        leaseEnd: row['lease_end'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['lease_end'] as int),
      );

  Map<String, Object?> toRow({int? propertyId}) => {
        'property_id': propertyId ?? this.propertyId,
        'number': number,
        'floor': floor,
        'status': status,
        'tenant_name': tenantName,
        'base_rent': baseRent,
        'extra_charge_name': extraChargeName,
        'extra_charge': extraCharge,
        'owned_by_management': ownedByManagement ? 1 : 0,
        'occupiers': _encodeOccupiers(occupiers),
        'is_rented': isRented ? 1 : 0,
        'move_in_date': moveInDate?.millisecondsSinceEpoch,
        'move_out_date': moveOutDate?.millisecondsSinceEpoch,
        'lease_end': leaseEnd?.millisecondsSinceEpoch,
      };
}
