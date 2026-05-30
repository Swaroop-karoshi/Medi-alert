import 'dart:convert';

import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

/// Global callback key for navigating to alarm screen from notification tap.
/// Set by main.dart at startup.
typedef NotificationActionCallback =
    void Function(String actionId, Map<String, dynamic> payload);
NotificationActionCallback? globalNotificationActionCallback;

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  // Process background notification actions (taken/skip/denied/snooze).
  DartPluginRegistrant.ensureInitialized();
  debugPrint('Background notification action: ${response.actionId}');

  final actionId = response.actionId;
  if (actionId == null || actionId.isEmpty) return;

  Map<String, dynamic> payload = {};
  if (response.payload != null && response.payload!.isNotEmpty) {
    try {
      payload = Map<String, dynamic>.from(jsonDecode(response.payload!));
    } catch (_) {}
  }

  // Write the action to a Hive box for processing when the app next starts.
  try {
    await Hive.initFlutter();
    final box = await Hive.openBox<Map>('pending_alarm_actions');
    final key = '${response.id}_${DateTime.now().millisecondsSinceEpoch}';
    await box.put(key, <String, dynamic>{
      'action': actionId,
      'notification_id': response.id,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });
    debugPrint('Queued background action: $actionId for key: $key');
  } catch (e) {
    debugPrint('Failed to queue background action: $e');
  }
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const _channelId = 'medicine_alarm_channel_v8';
  static const _lowStockChannelId = 'low_stock_alerts_v1';
  static const _gentleChannelId = 'medicine_gentle_reminders_v2';

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: _handleForegroundAction,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Medicine Alarms',
        description: 'Critical medicine reminders with continuous alarm sound',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('musical_alarm'),
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _lowStockChannelId,
        'Low Stock Alerts',
        description: 'Alerts when a patient medicine is running low',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _gentleChannelId,
        'Medicine Reminders',
        description: 'Gentle reminders before or after medication time',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    _initialized = true;
  }

  static void _handleForegroundAction(NotificationResponse response) {
    debugPrint(
      'Foreground notification action: ID=${response.id}, ActionId=${response.actionId}, Payload=${response.payload}',
    );

    Map<String, dynamic> payload = {};
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        payload = Map<String, dynamic>.from(jsonDecode(response.payload!));
        debugPrint('Decoded notification payload: $payload');
      } catch (e) {
        debugPrint('Failed to decode notification payload: $e');
      }
    }

    final actionId = response.actionId;
    if (actionId != null && actionId.isNotEmpty) {
      debugPrint('Triggering action: $actionId');
      globalNotificationActionCallback?.call(actionId, payload);
    } else {
      debugPrint('No ActionId (body tap). Triggering open_alarm.');
      globalNotificationActionCallback?.call('open_alarm', payload);
    }
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleExactAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    Map<String, dynamic>? payload,
  }) async {
    await init();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(dateTime, tz.local),
      _getNotificationDetails(body: body, payload: payload),
      payload: payload == null ? null : jsonEncode(payload),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    await init();
    await _plugin.show(
      id,
      title,
      body,
      _getNotificationDetails(body: body, payload: payload),
      payload: payload == null ? null : jsonEncode(payload),
    );
  }

  Future<void> scheduleGentleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    Map<String, dynamic>? payload,
  }) async {
    await init();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(dateTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _gentleChannelId,
          'Medicine Reminders',
          channelDescription: 'Gentle reminders before or after medication time',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      payload: payload == null ? null : jsonEncode(payload),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Shows a low-stock alert notification (for doctors and patients).
  Future<void> showLowStockAlert({
    required String patientName,
    required String medicineName,
    required int remaining,
    required String unit,
  }) async {
    await init();
    final id = 'low_stock_${patientName}_$medicineName'.hashCode.abs() % 100000;
    await _plugin.show(
      id,
      '⚠️ Low Stock Alert',
      '$medicineName for $patientName is running low — $remaining $unit remaining.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _lowStockChannelId,
          'Low Stock Alerts',
          channelDescription: 'Alerts when a patient medicine is running low',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFFFF6B35),
          styleInformation: BigTextStyleInformation(
            '$medicineName for $patientName is running low.\n$remaining $unit remaining. Please advise the patient to refill.',
          ),
        ),
      ),
    );
  }

  NotificationDetails _getNotificationDetails({
    String body = '',
    Map<String, dynamic>? payload,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Medicine Alarms',
        channelDescription: 'High-priority reminders for medicine schedules',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
        ongoing: true,
        autoCancel: false,
        additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT = 4
        sound: const RawResourceAndroidNotificationSound('musical_alarm'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        styleInformation: BigTextStyleInformation(body),
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            'taken',
            '✅ Taken',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'skipped',
            '⏭ Skipped',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'snooze',
            '⏰ Snooze',
            showsUserInterface: true,
          ),
        ],
      ),
    );
  }

  /// Process any pending alarm actions that were queued while the app was in the background.
  Future<List<Map<String, dynamic>>> processPendingActions() async {
    try {
      final box = await Hive.openBox<Map>('pending_alarm_actions');
      final pending = <Map<String, dynamic>>[];
      for (final key in box.keys.toList()) {
        final raw = box.get(key);
        if (raw != null) {
          pending.add(Map<String, dynamic>.from(raw));
        }
      }
      await box.clear();
      return pending;
    } catch (e) {
      debugPrint('Error processing pending actions: $e');
      return [];
    }
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();
}
