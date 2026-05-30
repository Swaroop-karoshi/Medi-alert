import 'package:flutter/foundation.dart';

enum InviteStatus { pending, accepted, rejected }

@immutable
class DoctorPatientInvite {
  final String id;
  final String doctorId;
  final String patientEmail;
  final InviteStatus status;
  final DateTime createdAt;

  const DoctorPatientInvite({
    required this.id,
    required this.doctorId,
    required this.patientEmail,
    required this.status,
    required this.createdAt,
  });

  factory DoctorPatientInvite.fromMap(Map<String, dynamic> map) {
    return DoctorPatientInvite(
      id: map['id'] as String,
      doctorId: map['doctor_id'] as String,
      patientEmail: map['patient_email'] as String,
      status: map['status'] == 'accepted' 
          ? InviteStatus.accepted 
          : (map['status'] == 'rejected' ? InviteStatus.rejected : InviteStatus.pending),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'doctor_id': doctorId,
        'patient_email': patientEmail,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
      };
}
