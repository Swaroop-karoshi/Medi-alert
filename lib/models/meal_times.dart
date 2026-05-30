import 'package:flutter/foundation.dart';

@immutable
class MealTimes {
  final String patientId;
  final String breakfastTime;
  final String lunchTime;
  final String dinnerTime;

  const MealTimes({
    required this.patientId,
    required this.breakfastTime,
    required this.lunchTime,
    required this.dinnerTime,
  });

  factory MealTimes.fromMap(Map<String, dynamic> map) {
    return MealTimes(
      patientId: map['patient_id'] as String,
      breakfastTime: map['breakfast_time'] as String,
      lunchTime: map['lunch_time'] as String,
      dinnerTime: map['dinner_time'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'patient_id': patientId,
        'breakfast_time': breakfastTime,
        'lunch_time': lunchTime,
        'dinner_time': dinnerTime,
      };
}
