import 'dart:typed_data';

class WorkOrder {
  final int id;
  final String unit;
  final String category;
  final String title;
  final String description;
  final String priority;
  final String status;
  final String assignedTo;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? photoProof;
  final Uint8List? proofBytes;

  const WorkOrder({
    required this.id,
    required this.unit,
    required this.category,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    required this.assignedTo,
    required this.createdAt,
    this.completedAt,
    this.photoProof,
    this.proofBytes,
  });

  WorkOrder copyWith({
    String? status,
    DateTime? completedAt,
    String? photoProof,
    String? assignedTo,
    Uint8List? proofBytes,
  }) {
    return WorkOrder(
      id: id,
      unit: unit,
      category: category,
      title: title,
      description: description,
      priority: priority,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      photoProof: photoProof ?? this.photoProof,
      proofBytes: proofBytes ?? this.proofBytes,
    );
  }
}
