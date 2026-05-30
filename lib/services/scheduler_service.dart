import 'package:flutter/material.dart';

import '../models/prescription_item.dart';

class SchedulerService {
  static List<DateTime> generateTimestamps({
    required PrescriptionItem item,
    required Map<String, TimeOfDay> personalSlotTimes,
  }) {
    final timestamps = <DateTime>[];
    final startDate = DateTime(
      item.durationStart.year,
      item.durationStart.month,
      item.durationStart.day,
    );
    final endDate = DateTime(
      item.durationEnd.year,
      item.durationEnd.month,
      item.durationEnd.day,
      23,
      59,
    );

    final allowedDays = List<String>.from(
      item.frequencyConfig['days'] ?? <String>[],
    );
    final slots = List<String>.from(item.mealConfig['slots'] ?? <String>[]);
    final triggers = List<Map<String, dynamic>>.from(
      item.mealConfig['triggers'] ?? <Map<String, dynamic>>[],
    );

    var cursor = startDate;
    while (!cursor.isAfter(endDate)) {
      final dayName = _weekdayName(cursor.weekday);
      if (allowedDays.contains(dayName)) {
        for (final slot in slots) {
          final chosen = personalSlotTimes[slot];
          if (chosen == null) continue;
          timestamps.add(
            DateTime(
              cursor.year,
              cursor.month,
              cursor.day,
              chosen.hour,
              chosen.minute,
            ),
          );
        }

        for (final trigger in triggers) {
          final computed = _computeTriggerTime(
            trigger,
            cursor,
            personalSlotTimes,
          );
          if (computed != null) {
            timestamps.add(computed);
          }
        }
      }

      cursor = cursor.add(const Duration(days: 1));
    }

    final uniqueTimestamps = timestamps.toSet().toList()..sort();
    return uniqueTimestamps;
  }

  static DateTime? _computeTriggerTime(
    Map<String, dynamic> trigger,
    DateTime day,
    Map<String, TimeOfDay> personalSlotTimes,
  ) {
    final meal = trigger['meal'] as String?;
    final relation = trigger['relation'] as String?;
    if (meal == null || relation == null) return null;

    final slotName = '${relation}_$meal';
    final base = personalSlotTimes[slotName];
    if (base == null) return null;

    final offset = (trigger['offset_minutes'] as num?)?.toInt() ?? 30;
    final baseDate = DateTime(
      day.year,
      day.month,
      day.day,
      base.hour,
      base.minute,
    );
    if (relation == 'before') {
      return baseDate.subtract(Duration(minutes: offset));
    }
    return baseDate.add(Duration(minutes: offset));
  }

  static String _weekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }
}
