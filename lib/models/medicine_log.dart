import 'package:flutter/foundation.dart';

enum MedicineLogStatus { taken, missed, skipped, denied }

@immutable
class MedicineLog {
  final String id;
  final String patientId;
  final String prescriptionItemId;
  final DateTime scheduledTime;
  final DateTime? takenTime;
  final MedicineLogStatus status;
  final int? deviationMinutes;

  const MedicineLog({
    required this.id,
    required this.patientId,
    required this.prescriptionItemId,
    required this.scheduledTime,
    this.takenTime,
    required this.status,
    this.deviationMinutes,
  });

  static MedicineLogStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'taken':
        return MedicineLogStatus.taken;
      case 'skipped':
        return MedicineLogStatus.skipped;
      case 'denied':
        return MedicineLogStatus.denied;
      default:
        return MedicineLogStatus.missed;
    }
  }

  factory MedicineLog.fromMap(Map<String, dynamic> map) {
    return MedicineLog(
      id: map['id'] as String,
      patientId: map['patient_id'] as String,
      prescriptionItemId: map['prescription_item_id'] as String,
      scheduledTime: DateTime.parse(map['scheduled_time'] as String),
      takenTime: map['taken_time'] != null ? DateTime.parse(map['taken_time'] as String) : null,
      status: _parseStatus(map['status'] as String?),
      deviationMinutes: map['deviation_minutes'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'patient_id': patientId,
        'prescription_item_id': prescriptionItemId,
        'scheduled_time': scheduledTime.toIso8601String(),
        'taken_time': takenTime?.toIso8601String(),
        'status': status.name,
        'deviation_minutes': deviationMinutes,
      };
}
