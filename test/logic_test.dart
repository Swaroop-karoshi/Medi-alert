import 'package:flutter_test/flutter_test.dart';
import 'package:medi_alert/models/medicine.dart';

void main() {
  test('tablet count decrements when medicine is taken', () {
    final medicine = Medicine(
      id: '1',
      patientId: 'p1',
      name: 'Paracetamol',
      dosage: '500mg',
      type: MedicineType.tablet,
      beforeAfterFood: BeforeAfterFood.afterFood,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 10),
      totalTablets: 10,
      remainingTablets: 10,
    );

    final updated = medicine.copyWith(remainingTablets: medicine.remainingTablets - 1);
    expect(updated.remainingTablets, 9);
  });
}
