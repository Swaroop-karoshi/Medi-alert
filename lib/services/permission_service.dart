import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionService {
  static const MethodChannel _settingsChannel = MethodChannel('medi_alert/settings');

  /// Request all permissions needed for the app to function correctly.
  /// If [context] is provided, shows explanatory dialogs before requesting.
  static Future<void> requestAllPermissions([BuildContext? context]) async {
    if (!Platform.isAndroid) return;

    // 1. Notifications
    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      if (context != null && context.mounted) {
        await _showExplanatoryDialog(
          context,
          title: 'Notifications',
          message:
              'MediAlert needs permission to show notifications so you receive '
              'medicine reminders even when you are not looking at the app.',
        );
      }
      if (await Permission.notification.request().isPermanentlyDenied) {
        await openAppSettings();
      }
    }

    // 2. Exact Alarms (Android 12+)
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 31) {
      if (!await Permission.scheduleExactAlarm.isGranted) {
        if (context != null && context.mounted) {
          await _showExplanatoryDialog(
            context,
            title: 'Exact Alarms',
            message:
                'MediAlert needs the "Alarms & Reminders" permission to ensure '
                'your medicine reminders trigger at the exact second as scheduled.\n\n'
                'On the next screen, look for "MediAlert" and toggle the switch to ON.',
          );
        }
        // Some OEMs (notably Samsung) don't reliably show our app in the
        // "Alarms & reminders" list unless we open the exact screen via intent.
        final requested = await _requestExactAlarmPermissionViaPlatform();
        if (!requested) {
          final status = await Permission.scheduleExactAlarm.request();
          if (!status.isGranted) {
            await openAppSettings();
          }
        }
      }
    }

    // 3. Ignore Battery Optimizations (run in background)
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      if (context != null && context.mounted) {
        await _showExplanatoryDialog(
          context,
          title: 'Background Execution',
          message:
              'MediAlert needs to run in the background so it can ring alarms '
              'for your medicines even when the app is closed.\n\n'
              'Please allow "Ignore Battery Optimizations" on the next screen.',
        );
      }
      if (await Permission.ignoreBatteryOptimizations.request().isDenied) {
        await openAppSettings();
      }
    }

    // 4. System Alert Window (appear on top of any screen)
    if (!await Permission.systemAlertWindow.isGranted) {
      if (context != null && context.mounted) {
        await _showExplanatoryDialog(
          context,
          title: 'Appear on Top',
          message:
              'MediAlert needs permission to display alarm screens on top of '
              'other apps. This ensures you see medicine reminders immediately, '
              'even if you are using another app.',
        );
      }
      if (await Permission.systemAlertWindow.request().isDenied) {
        await openAppSettings();
      }
    }
  }

  static Future<void> openAppStabilitySettings() async {
    await openAppSettings();
  }

  static Future<bool> _requestExactAlarmPermissionViaPlatform() async {
    if (!Platform.isAndroid) return true;
    try {
      final ok = await _settingsChannel.invokeMethod<bool>(
        'requestExactAlarmPermission',
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasRequiredPermissions() async {
    if (!Platform.isAndroid) return true;

    final notif = await Permission.notification.isGranted;

    bool exactAlarm = true;
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 31) {
      exactAlarm = await Permission.scheduleExactAlarm.isGranted;
    }

    final battery = await Permission.ignoreBatteryOptimizations.isGranted;
    final overlay = await Permission.systemAlertWindow.isGranted;

    return notif && exactAlarm && battery && overlay;
  }

  /// Returns a map of permission name → granted status for UI display.
  static Future<Map<String, bool>> getPermissionStatuses() async {
    if (!Platform.isAndroid) {
      return {
        'Notifications': true,
        'Exact Alarms': true,
        'Background Execution': true,
        'Appear on Top': true,
      };
    }

    final notif = await Permission.notification.isGranted;

    bool exactAlarm = true;
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 31) {
      exactAlarm = await Permission.scheduleExactAlarm.isGranted;
    }

    final battery = await Permission.ignoreBatteryOptimizations.isGranted;
    final overlay = await Permission.systemAlertWindow.isGranted;

    return {
      'Notifications': notif,
      'Exact Alarms': exactAlarm,
      'Background Execution': battery,
      'Appear on Top': overlay,
    };
  }

  static Future<bool> _showExplanatoryDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.security, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return true;
  }
}
