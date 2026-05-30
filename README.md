# Medialert (Android)

Medialert is a dual-role Flutter application for doctors and patients to manage prescriptions, schedules, and medicine adherence with exact background reminders.

## Stack
- Flutter + Riverpod
- Supabase Auth (email/password), Postgres, Realtime
- Hive local storage for offline-first sync and alarm persistence
- `android_alarm_manager_plus` + `flutter_local_notifications` for exact alarms
- `flutter_foreground_task` for always-on Android background execution (foreground service)

## Setup
1. Apply `supabase_schema.sql` in your Supabase SQL editor.
2. Run:
```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```
3. On Android 12+, grant:
- Notification permission
- Exact alarm permission
- Battery optimization exemption
- Keep the persistent "MediAlert is Active" notification enabled (required for foreground service)

## Background execution (Android)
- MediAlert runs an Android foreground service to keep alarms reliable when the app is closed/swiped away.
- The service is configured to restart on device boot and after app updates (package replaced).
- iOS does not support always-on background execution for this kind of app; reminders rely on notifications/alarms instead.

## Current behavior
- Supabase-only authentication (doctor/patient)
- Invite, prescription approval, schedule generation
- Reminder alarms scheduled exactly and restored on app relaunch/reboot
- Offline medicine-log queue with deferred sync
# Medi-alert
# Medi-alert
