class DoctorInventoryItem {
  final String id;
  final String doctorId;
  final String medicineName;
  final String unit;
  final int totalQuantity;
  final int currentQuantity;
  final double pricePerUnit;
  final int lowStockThreshold;
  final DateTime updatedAt;

  const DoctorInventoryItem({
    required this.id,
    required this.doctorId,
    required this.medicineName,
    required this.unit,
    required this.totalQuantity,
    required this.currentQuantity,
    required this.pricePerUnit,
    required this.lowStockThreshold,
    required this.updatedAt,
  });

  bool get isLowStock => currentQuantity <= lowStockThreshold;
  bool get isCritical => currentQuantity <= (lowStockThreshold ~/ 2).clamp(1, lowStockThreshold);
  bool get isEmpty => currentQuantity <= 0;

  double get fillRatio =>
      totalQuantity <= 0 ? 0.0 : (currentQuantity / totalQuantity).clamp(0.0, 1.0);

  String get stockLabel {
    if (isEmpty) return 'Out of Stock';
    if (isCritical) return 'Critical';
    if (isLowStock) return 'Low Stock';
    return 'In Stock';
  }

  factory DoctorInventoryItem.fromMap(Map<String, dynamic> map) {
    return DoctorInventoryItem(
      id: map['id'] as String,
      doctorId: map['doctor_id'] as String,
      medicineName: map['medicine_name'] as String,
      unit: map['unit'] as String? ?? 'tablet',
      totalQuantity: map['total_quantity'] as int? ?? 0,
      currentQuantity: map['current_quantity'] as int? ?? 0,
      pricePerUnit: (map['price_per_unit'] as num?)?.toDouble() ?? 0.0,
      lowStockThreshold: map['low_stock_threshold'] as int? ?? 5,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'doctor_id': doctorId,
        'medicine_name': medicineName,
        'unit': unit,
        'total_quantity': totalQuantity,
        'current_quantity': currentQuantity,
        'price_per_unit': pricePerUnit,
        'low_stock_threshold': lowStockThreshold,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}
