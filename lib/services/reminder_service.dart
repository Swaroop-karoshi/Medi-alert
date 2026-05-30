import 'dart:ui';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:crypto/crypto.dart';
import 'notification_service.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
void missedMedicineCheckCallback(int id, Map<String, dynamic> params) async {
  try {
    DartPluginRegistrant.ensureInitialized();
    final logId = params['log_id'] as String?;
    final medicine = params['medicine_name'] as String?;
    final minutesLate = params['minutes_late'] as int?;
    
    if (logId == null) return;

    // Initialize Supabase in background isolate
    await Supabase.initialize(
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://pjaskxfemihrqijpqgnw.supabase.co',
      ),
      anonKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBqYXNreGZlbWlocnFpanBxZ253Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzMTQ3OTYsImV4cCI6MjA5MTg5MDc5Nn0.I4YY-AaUq34n2FM76sejFv8M4QvJyddAE8RmTn2ws58',
      ),
    );

    final res = await Supabase.instance.client
        .from('medicine_logs')
        .select('status')
        .eq('id', logId)
        .maybeSingle();

    if (res == null) return;

    final status = res['status'] as String?;
    if (status == 'missed') {
      final ns = NotificationService();
      await ns.init();
      
      final String timeDesc = minutesLate == 60 ? '1 hour' : '$minutesLate minutes';
      
      await ns.scheduleGentleNotification(
        id: id,
        title: '⚠️ Missed Medication',
        body: 'You missed your $medicine dose $timeDesc ago. Please take it if appropriate.',
        dateTime: DateTime.now().add(const Duration(seconds: 1)),
        payload: params,
      );
    }
  } catch (e) {
    debugPrint('Missed check callback failed: $e');
  }
}


@pragma('vm:entry-point')
void alarmCallback(int id, Map<String, dynamic> params) async {
  try {
    DartPluginRegistrant.ensureInitialized();
    debugPrint('Medicine alarm callback triggered for ID: $id');

    final ns = NotificationService();
    await ns.init();

    final medicine = (params['medicine_name'] as String?)?.trim();
    final doctor = (params['doctor_name'] as String?)?.trim();
    
    String bodyText = 'Time to take your medicine.';
    if (medicine != null && medicine.isNotEmpty) {
      bodyText = 'Time to take $medicine.';
      if (doctor != null && doctor.isNotEmpty) {
        bodyText += ' Prescribed by Dr. $doctor.';
      }
    } else if (doctor != null && doctor.isNotEmpty) {
      bodyText = 'Medicine prescribed by Dr. $doctor is due.';
    }

    await ns.showInstantNotification(
      id: id,
      title: (medicine != null && medicine.isNotEmpty)
          ? '💊 Time for $medicine'
          : '⏰ Medication Time!',
      body: bodyText,
      payload: params,
    );

    // Best-effort: wake the device and bring the app to foreground for the alarm UI.
    // On many OEMs (Samsung/Xiaomi/etc.), this still depends on:
    // - Exact alarms enabled ("Alarms & reminders")
    // - Battery set to Unrestricted / ignore optimizations
    // - Full-screen intents allowed for the app
    try {
      FlutterForegroundTask.wakeUpScreen();
      FlutterForegroundTask.launchApp();
    } catch (e) {
      debugPrint('Failed to bring app to foreground: $e');
    }

    // Write to pending_alarm_display box so the alarm screen can show when app opens
    try {
      await Hive.initFlutter();
      final box = await Hive.openBox<Map>('pending_alarm_display');
      await box.put(id.toString(), <String, dynamic>{
        'alarm_id': id,
        'medicine_name': medicine ?? 'Your Medicine',
        'doctor_name': doctor ?? 'Your Doctor',
        'scheduled_time': params['scheduled_time'],
        'prescription_item_id': params['prescription_item_id'],
        'log_id': params['log_id'],
        'triggered_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to write alarm display data: $e');
    }
  } catch (e, stack) {
    debugPrint('CRITICAL: Alarm callback failed: $e\n$stack');
  }
}

class ReminderService {
  ReminderService(this._notificationService);

  static const _alarmBoxName = 'scheduled_alarms';
  final NotificationService _notificationService;
  late Box<Map> _alarmBox;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    await _notificationService.init();
    _alarmBox = await Hive.openBox<Map>(_alarmBoxName);
    _initialized = true;
    await reschedulePendingAlarms();
  }

  Future<void> scheduleAlarm({
    required int id,
    required DateTime at,
    String? medicineName,
    String? doctorName,
    String? prescriptionItemId,
    String? logId,
  }) async {
    if (at.isBefore(DateTime.now())) return;
    if (!_initialized) {
      await initialize();
    }

    final params = <String, dynamic>{'scheduled_time': at.toIso8601String()};
    if (medicineName != null) {
      params['medicine_name'] = medicineName;
    }
    if (doctorName != null) {
      params['doctor_name'] = doctorName;
    }
    if (prescriptionItemId != null) {
      params['prescription_item_id'] = prescriptionItemId;
    }
    if (logId != null) {
      params['log_id'] = logId;
    }

    await AndroidAlarmManager.oneShotAt(
      at.toLocal(),
      id,
      alarmCallback,
      allowWhileIdle: true,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      params: params,
    );

    // Secondary safety-net path for OEM devices that aggressively delay alarms.
    final notifTitle = (medicineName != null && medicineName.isNotEmpty)
        ? '💊 Time for $medicineName'
        : '⏰ Medication Time!';
    final notifBody = _buildNotificationBody(medicineName, doctorName);
    await _notificationService.scheduleExactAlarm(
      id: id,
      title: notifTitle,
      body: notifBody,
      dateTime: at.toLocal(),
      payload: params,
    );

    // Schedule 1-hour pre-notification
    final preAt = at.subtract(const Duration(hours: 1));
    if (preAt.isAfter(DateTime.now())) {
      final String preBody = (medicineName != null && medicineName.isNotEmpty) 
          ? 'You have your $medicineName dose in 1 hour.'
          : 'You have a medication dose in 1 hour.';
      await _notificationService.scheduleGentleNotification(
        id: id + 100000,
        title: 'ℹ️ Upcoming Medication',
        body: preBody,
        dateTime: preAt.toLocal(),
        payload: params,
      );
    }

    // Schedule Missed-Check callbacks at +10m, +30m, and +60m
    final deltas = [10, 30, 60];
    for (final delta in deltas) {
      final missedAt = at.add(Duration(minutes: delta));
      if (missedAt.isAfter(DateTime.now())) {
        final missedParams = Map<String, dynamic>.from(params);
        missedParams['minutes_late'] = delta;
        await AndroidAlarmManager.oneShotAt(
          missedAt.toLocal(),
          id + (delta * 1000), // Unique ID offset for each delta check
          missedMedicineCheckCallback,
          allowWhileIdle: true,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
          params: missedParams,
        );
      }
    }

    await _alarmBox.put(id.toString(), <String, dynamic>{
      'id': id,
      'at': at.toIso8601String(),
      ...params,
    });
  }

  Future<void> cancelAlarm(int id) async {
    await AndroidAlarmManager.cancel(id);
    await AndroidAlarmManager.cancel(id + 10000); // 10m missed
    await AndroidAlarmManager.cancel(id + 30000); // 30m missed
    await AndroidAlarmManager.cancel(id + 60000); // 60m missed

    await _notificationService.cancel(id);
    await _notificationService.cancel(id + 100000); // pre-notification

    if (_initialized) {
      await _alarmBox.delete(id.toString());
    }
  }

  Future<void> reschedulePendingAlarms() async {
    if (!_initialized) {
      await initialize();
      return;
    }

    final now = DateTime.now();
    final staleIds = <String>[];

    for (final entry in _alarmBox.toMap().entries) {
      final data = Map<String, dynamic>.from(entry.value);
      final at = DateTime.tryParse(data['at'] as String? ?? '');
      if (at == null || at.isBefore(now)) {
        staleIds.add(entry.key as String);
        continue;
      }
      final id = data['id'] as int;
      await scheduleAlarm(
        id: id,
        at: at,
        medicineName: data['medicine_name'] as String?,
        doctorName: data['doctor_name'] as String?,
        prescriptionItemId: data['prescription_item_id'] as String?,
        logId: data['log_id'] as String?,
      );
    }

    if (staleIds.isNotEmpty) {
      await _alarmBox.deleteAll(staleIds);
    }
  }

  Future<void> snooze({required int id, required int minutes}) async {
    final next = DateTime.now().add(Duration(minutes: minutes));
    await scheduleAlarm(id: id, at: next);
  }

  /// Get any pending alarm display data (for showing alarm screen on app open).
  Future<Map<String, dynamic>?> getAndClearPendingAlarmDisplay() async {
    try {
      final box = await Hive.openBox<Map>('pending_alarm_display');
      if (box.isEmpty) return null;

      // Return the most recent pending alarm
      final lastKey = box.keys.last;
      final data = Map<String, dynamic>.from(box.get(lastKey)!);
      await box.clear();

      final triggeredAt = DateTime.tryParse(data['triggered_at'] as String? ?? '');
      if (triggeredAt != null) {
        final age = DateTime.now().difference(triggeredAt);
        if (age.inMinutes > 15) {
          // Alarm is too old (e.g. over 15 mins since callback), ignore it.
          debugPrint('Discarding stale pending alarm display. Age: \${age.inMinutes} mins');
          return null;
        }
      }
      return data;
    } catch (e) {
      debugPrint('Error reading pending alarm display: $e');
      return null;
    }
  }

  int deterministicAlarmId(String seed) {
    final bytes = utf8.encode(seed);
    final digest = md5.convert(bytes).bytes;
    final value =
        ((digest[0] << 24) | (digest[1] << 16) | (digest[2] << 8) | digest[3]) &
        0x7fffffff;
    return value == 0 ? 1 : value;
  }

  static String _buildNotificationBody(String? medicineName, String? doctorName) {
    if (medicineName != null && medicineName.isNotEmpty) {
      if (doctorName != null && doctorName.isNotEmpty) {
        return 'Time to take $medicineName. Prescribed by Dr. $doctorName.';
      }
      return 'Time to take $medicineName.';
    }
    if (doctorName != null && doctorName.isNotEmpty) {
      return 'Medicine prescribed by Dr. $doctorName is due.';
    }
    return 'Time to take your medicine.';
  }
}
