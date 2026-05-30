import 'dart:convert';
import 'package:flutter/foundation.dart';

@immutable
class PrescriptionItem {
  final String id;
  final String prescriptionId;
  final String medicineName;
  final String dosageType;
  final Map<String, dynamic> frequencyConfig;
  final DateTime durationStart;
  final DateTime durationEnd;
  final Map<String, dynamic> mealConfig;

  final String? inventoryItemId;
  final int prescribedQuantity;
  final double pricePerUnit;

  const PrescriptionItem({
    required this.id,
    required this.prescriptionId,
    required this.medicineName,
    required this.dosageType,
    required this.frequencyConfig,
    required this.durationStart,
    required this.durationEnd,
    required this.mealConfig,
    this.inventoryItemId,
    this.prescribedQuantity = 0,
    this.pricePerUnit = 0.0,
  });

  factory PrescriptionItem.fromMap(Map<String, dynamic> map) {
    return PrescriptionItem(
      id: map['id'] as String,
      prescriptionId: map['prescription_id'] as String,
      medicineName: map['medicine_name'] as String,
      dosageType: map['dosage_type'] as String,
      frequencyConfig: map['frequency_config'] is String 
          ? jsonDecode(map['frequency_config'] as String) as Map<String, dynamic>
          : map['frequency_config'] as Map<String, dynamic>,
      durationStart: DateTime.parse(map['duration_start'] as String),
      durationEnd: DateTime.parse(map['duration_end'] as String),
      mealConfig: map['meal_config'] is String
          ? jsonDecode(map['meal_config'] as String) as Map<String, dynamic>
          : map['meal_config'] as Map<String, dynamic>,
      inventoryItemId: map['inventory_item_id'] as String?,
      prescribedQuantity: map['prescribed_quantity'] as int? ?? 0,
      pricePerUnit: (map['price_per_unit'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'prescription_id': prescriptionId,
        'medicine_name': medicineName,
        'dosage_type': dosageType,
        'frequency_config': frequencyConfig,
        'duration_start': durationStart.toIso8601String(),
        'duration_end': durationEnd.toIso8601String(),
        'meal_config': mealConfig,
        'inventory_item_id': inventoryItemId,
        'prescribed_quantity': prescribedQuantity,
        'price_per_unit': pricePerUnit,
      };
}
