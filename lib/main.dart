import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'routes/app_router.dart';
import 'services/notification_service.dart';
import 'services/permission_service.dart';
import 'services/background_service.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Global navigator key is now imported from app_router.dart

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await Hive.initFlutter();
  await AndroidAlarmManager.initialize();
  await BackgroundService.initialize();

  runApp(const ProviderScope(child: SmartMedicineReminderApp()));
}

class SmartMedicineReminderApp extends ConsumerStatefulWidget {
  const SmartMedicineReminderApp({super.key});

  @override
  ConsumerState<SmartMedicineReminderApp> createState() =>
      _SmartMedicineReminderAppState();
}

class _SmartMedicineReminderAppState
    extends ConsumerState<SmartMedicineReminderApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      // 1. Set up notification handler FIRST before initializing services
      _setupNotificationActionHandler();

      await initializeBackends(ref);
      await ref.read(notificationServiceProvider).init();
      await ref.read(reminderServiceProvider).initialize();
      await ref.read(syncServiceProvider).syncPending();

      // Trigger permission requests with context after a short delay
      // to ensure the app UI is ready for dialogs
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 1000), () async {
          if (mounted) {
            final navContext = rootNavigatorKey.currentContext;
            await PermissionService.requestAllPermissions(navContext ?? context);

            // Keep the app process alive on Android so alarms remain reliable
            // even if the user swipes the app away.
            if (Platform.isAndroid) {
              await BackgroundService.start();
            }
          }
        });
      }

      // Best-effort: start early too (may be a no-op until notification permission is granted).
      if (Platform.isAndroid) {
        await BackgroundService.start();
      }

      // Process any pending alarm actions queued while app was in background
      await _processPendingNotificationActions();

      // Check if there's a pending alarm display (alarm fired while app was closed)
      await _checkPendingAlarmDisplay();
    });
  }

  void _setupNotificationActionHandler() {
    globalNotificationActionCallback = (String actionId, Map<String, dynamic> payload) {
      _handleNotificationAction(actionId, payload);
    };
  }

  /// Returns true only if a user is currently authenticated.  
  bool get _isAuthenticated {
    final authData = ref.read(authStateProvider);
    return authData.asData?.value != null;
  }

  Future<void> _handleNotificationAction(
    String actionId,
    Map<String, dynamic> payload,
  ) async {
    // Don't process alarm actions if user is not logged in
    if (!_isAuthenticated) return;

    final logId = payload['log_id'] as String?;
    final prescriptionItemId = payload['prescription_item_id'] as String?;
    final scheduledTimeStr = payload['scheduled_time'] as String?;
    final medicineName = payload['medicine_name'] as String?;

    if (actionId == 'open_alarm' || actionId == '') {
      // Navigate to alarm screen
      _navigateToAlarmScreen(
        medicineName: medicineName,
        doctorName: payload['doctor_name'] as String?,
        scheduledTime: scheduledTimeStr,
        logId: logId,
        prescriptionItemId: prescriptionItemId,
      );
      return;
    }

    if (actionId == 'snooze') {
      // Snooze for 10 minutes
      final reminder = ref.read(reminderServiceProvider);
      if (logId != null) {
        final alarmId = reminder.deterministicAlarmId(logId);
        await reminder.snooze(id: alarmId, minutes: 10);
      }
      return;
    }

    // For taken/skipped/denied actions
    if (['taken', 'skipped', 'denied'].contains(actionId)) {
      final userId = ref.read(currentUserProfileProvider).value?.id;
      if (userId == null || logId == null) return;

      final now = DateTime.now();
      final scheduledTime = scheduledTimeStr != null
          ? DateTime.parse(scheduledTimeStr)
          : now;

      final sync = ref.read(syncServiceProvider);
      await sync.upsertMedicineLog(
        logId: logId,
        patientId: userId,
        prescriptionItemId: prescriptionItemId ?? '',
        scheduledTime: scheduledTime,
        status: actionId,
        takenTime: actionId == 'taken' ? now : null,
      );

      // Cancel the alarm notification
      final reminder = ref.read(reminderServiceProvider);
      final alarmId = reminder.deterministicAlarmId(logId);
      await reminder.cancelAlarm(alarmId);

      // Refresh providers
      ref.invalidate(dailyLogsProvider);
      ref.invalidate(adherenceReportProvider);
      ref.read(refreshTriggerProvider.notifier).state++;
    }
  }

  Future<void> _processPendingNotificationActions() async {
    final notifService = ref.read(notificationServiceProvider);
    final pendingActions = await notifService.processPendingActions();

    for (final action in pendingActions) {
      final actionId = action['action'] as String? ?? '';
      final payload = Map<String, dynamic>.from(action['payload'] ?? {});
      await _handleNotificationAction(actionId, payload);
    }
  }

  Future<void> _checkPendingAlarmDisplay() async {
    // Don't show alarm screen if user is not logged in
    if (!_isAuthenticated) return;

    final reminder = ref.read(reminderServiceProvider);
    final pendingAlarm = await reminder.getAndClearPendingAlarmDisplay();

    if (pendingAlarm != null) {
      // Small delay to ensure the router is ready
      await Future.delayed(const Duration(milliseconds: 500));
      _navigateToAlarmScreen(
        medicineName: pendingAlarm['medicine_name'] as String?,
        doctorName: pendingAlarm['doctor_name'] as String?,
        scheduledTime: pendingAlarm['scheduled_time'] as String?,
        logId: pendingAlarm['log_id'] as String?,
        prescriptionItemId: pendingAlarm['prescription_item_id'] as String?,
        alarmId: pendingAlarm['alarm_id'] as int?,
      );
    }
  }

  void _navigateToAlarmScreen({
    String? medicineName,
    String? doctorName,
    String? scheduledTime,
    String? logId,
    String? prescriptionItemId,
    int? alarmId,
  }) {
    final router = ref.read(appRouterProvider);
    final params = <String, String>{
      'medicine': medicineName ?? 'Your Medicine',
      'time': scheduledTime ?? DateTime.now().toIso8601String(),
    };
    if (doctorName != null) params['doctor'] = doctorName;
    if (logId != null) params['logId'] = logId;
    if (prescriptionItemId != null) params['itemId'] = prescriptionItemId;
    if (alarmId != null) params['alarmId'] = alarmId.toString();

    final uri = Uri(path: '/alarm', queryParameters: params);
    router.push(uri.toString());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.microtask(() async {
        await ref.read(syncServiceProvider).syncPending();
        await ref.read(reminderServiceProvider).reschedulePendingAlarms();
        await _processPendingNotificationActions();
        await _checkPendingAlarmDisplay();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return WithForegroundTask(
      child: MaterialApp.router(
        title: AppConstants.appName,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
        routerConfig: router,
        builder: (context, child) {
          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: child ?? const SizedBox.shrink(),
          );
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
