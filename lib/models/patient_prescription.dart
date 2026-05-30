import 'dart:convert';
import 'package:flutter/foundation.dart';

enum PrescriptionStatus { pending, accepted, rejected }

@immutable
class PatientPrescription {
  final String id;
  final String prescriptionId;
  final String patientId;
  final PrescriptionStatus status;
  final Map<String, dynamic>? modifiedSchedule;
  final DateTime createdAt;

  const PatientPrescription({
    required this.id,
    required this.prescriptionId,
    required this.patientId,
    required this.status,
    this.modifiedSchedule,
    required this.createdAt,
  });

  factory PatientPrescription.fromMap(Map<String, dynamic> map) {
    return PatientPrescription(
      id: map['id'] as String,
      prescriptionId: map['prescription_id'] as String,
      patientId: map['patient_id'] as String,
      status: map['status'] == 'accepted' 
          ? PrescriptionStatus.accepted 
          : (map['status'] == 'rejected' ? PrescriptionStatus.rejected : PrescriptionStatus.pending),
      modifiedSchedule: map['modified_schedule'] != null
          ? (map['modified_schedule'] is String 
              ? jsonDecode(map['modified_schedule'] as String) as Map<String, dynamic>
              : map['modified_schedule'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'prescription_id': prescriptionId,
        'patient_id': patientId,
        'status': status.name,
        'modified_schedule': modifiedSchedule,
        'created_at': createdAt.toIso8601String(),
      };
}
