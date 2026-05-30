class ScheduleEntry {
  final String id;
  final String medicineId;
  final String time;
  final String repeatType;

  const ScheduleEntry({
    required this.id,
    required this.medicineId,
    required this.time,
    required this.repeatType,
  });

  factory ScheduleEntry.fromMap(Map<String, dynamic> map) => ScheduleEntry(
        id: map['id'] as String,
        medicineId: map['medicine_id'] as String,
        time: map['time'] as String,
        repeatType: map['repeat_type'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'medicine_id': medicineId,
        'time': time,
        'repeat_type': repeatType,
      };
}
