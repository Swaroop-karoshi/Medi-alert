import 'package:flutter/foundation.dart';

@immutable
class Prescription {
  final String id;
  final String doctorId;
  final String title;
  final String? notes;
  final DateTime createdAt;

  const Prescription({
    required this.id,
    required this.doctorId,
    required this.title,
    this.notes,
    required this.createdAt,
  });

  factory Prescription.fromMap(Map<String, dynamic> map) {
    return Prescription(
      id: map['id'] as String,
      doctorId: map['doctor_id'] as String,
      title: map['title'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'doctor_id': doctorId,
        'title': title,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}
