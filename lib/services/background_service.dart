import 'dart:io';
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/material.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  void onStart(DateTime timestamp, SendPort? sendPort) {
    debugPrint('Foreground task started at $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    // We don't need to do frequent work, just keep the process alive
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {
    debugPrint('Foreground task destroyed at $timestamp');
  }
}

class BackgroundService {
  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'medi_alert_foreground',
        channelName: 'MediAlert Active Monitoring',
        channelDescription: 'Keeps MediAlert active to ensure medication alarms ring reliably.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 30000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<bool> start() async {
    if (!Platform.isAndroid) return true;

    if (await FlutterForegroundTask.isRunningService) {
      return true;
    }

    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'MediAlert is Active',
      notificationText: 'Monitoring your medication schedule...',
      callback: startCallback,
    );

    return result.success;
  }

  static Future<bool> stop() async {
    if (!Platform.isAndroid) return true;
    
    final result = await FlutterForegroundTask.stopService();
    return result.success;
  }
}
