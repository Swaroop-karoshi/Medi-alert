enum MedicineType { tablet, syrup, injection }
enum BeforeAfterFood { beforeFood, afterFood }

class Medicine {
  final String id;
  final String patientId;
  final String prescribedBy;
  final String name;
  final String dosage;
  final MedicineType type;
  final BeforeAfterFood beforeAfterFood;
  final DateTime startDate;
  final DateTime endDate;
  final int totalTablets;
  final int remainingTablets;
  final String status;

  const Medicine({
    required this.id,
    required this.patientId,
    this.prescribedBy = '',
    required this.name,
    required this.dosage,
    required this.type,
    required this.beforeAfterFood,
    required this.startDate,
    required this.endDate,
    required this.totalTablets,
    required this.remainingTablets,
    this.status = 'pending',
  });

  bool get isLowStock => remainingTablets < 5;

  Medicine copyWith({int? remainingTablets, String? status}) => Medicine(
        id: id,
        patientId: patientId,
        prescribedBy: prescribedBy,
        name: name,
        dosage: dosage,
        type: type,
        beforeAfterFood: beforeAfterFood,
        startDate: startDate,
        endDate: endDate,
        totalTablets: totalTablets,
        remainingTablets: remainingTablets ?? this.remainingTablets,
        status: status ?? this.status,
      );

  factory Medicine.fromMap(Map<String, dynamic> map) => Medicine(
        id: map['id'] as String,
        patientId: map['patient_id'] as String,
        prescribedBy: map['prescribed_by'] as String? ?? '',
        name: map['name'] as String,
        dosage: map['dosage'] as String,
        type: MedicineType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => MedicineType.tablet,
        ),
        beforeAfterFood: (map['before_after_food'] == 'after_food')
            ? BeforeAfterFood.afterFood
            : BeforeAfterFood.beforeFood,
        startDate: DateTime.parse(map['start_date'] as String),
        endDate: DateTime.parse(map['end_date'] as String),
        totalTablets: map['total_tablets'] as int,
        remainingTablets: map['remaining_tablets'] as int,
        status: map['status'] as String? ?? 'pending',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'patient_id': patientId,
        'prescribed_by': prescribedBy,
        'name': name,
        'dosage': dosage,
        'type': type.name,
        'before_after_food': beforeAfterFood == BeforeAfterFood.afterFood
            ? 'after_food'
            : 'before_food',
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'total_tablets': totalTablets,
        'remaining_tablets': remainingTablets,
        'status': status,
      };
}
