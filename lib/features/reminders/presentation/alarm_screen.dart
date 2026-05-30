import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../providers/app_providers.dart';

/// Full-screen alarm overlay that appears when a medication alarm fires.
/// Shows 4 action buttons: Taken, Skipped, Denied, Snooze.
class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({
    super.key,
    required this.medicineName,
    required this.scheduledTime,
    this.doctorName,
    this.logId,
    this.prescriptionItemId,
    this.alarmId,
  });

  final String medicineName;
  final String scheduledTime;
  final String? doctorName;
  final String? logId;
  final String? prescriptionItemId;
  final int? alarmId;

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsedTime = DateTime.tryParse(widget.scheduledTime)?.toLocal();
    final timeStr = parsedTime != null
        ? DateFormat('hh:mm a').format(parsedTime)
        : widget.scheduledTime;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SizedBox.expand(
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Pulsing alarm icon
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.15);
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.error.withValues(alpha: 0.1),
                    border: Border.all(color: theme.colorScheme.error, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.error.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.alarm,
                    color: theme.colorScheme.error,
                    size: 60,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Title
              Text(
                '⏰ Medication Time!',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ).animate().fadeIn(duration: 500.ms),

              const SizedBox(height: 16),

              // Medicine name
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      widget.medicineName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.doctorName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Dr. ${widget.doctorName}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Scheduled at $timeStr',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms),

              const Spacer(flex: 2),

              // Action buttons
              if (_processing)
                Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Taken button — full width, prominent
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: () => _handleAction('taken'),
                          icon: const Icon(Icons.check_circle, size: 28),
                          label: const Text(
                            'Tablet Taken',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ).animate().slideY(begin: 0.3, end: 0, delay: 400.ms),

                      const SizedBox(height: 16),

                      // Skipped button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () => _handleAction('skipped'),
                          icon: const Icon(Icons.skip_next, size: 24),
                          label: const Text(
                            'Skip this dose',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ).animate().slideY(begin: 0.3, end: 0, delay: 500.ms),

                      const SizedBox(height: 16),

                      // Snooze button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _handleSnooze(),
                          icon: const Icon(Icons.snooze, size: 22),
                          label: const Text(
                            'Snooze 10 Minutes',
                            style: TextStyle(fontSize: 15),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                            side: BorderSide(
                              color: theme.colorScheme.outline.withValues(alpha: 0.2),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ).animate().slideY(begin: 0.3, end: 0, delay: 600.ms),
                    ],
                  ),
                ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(String status) async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      final client = ref.read(supabaseServiceProvider).client;
      final userId = ref.read(currentUserProfileProvider).value?.id;

      if (client != null && userId != null && widget.logId != null) {
        final now = DateTime.now();
        final scheduled = DateTime.tryParse(widget.scheduledTime) ?? now;

        final payload = <String, dynamic>{
          'status': status,
          if (status == 'taken') 'taken_time': now.toIso8601String(),
          if (status == 'taken')
            'deviation_minutes': now.difference(scheduled).inMinutes,
        };

        try {
          await client
              .from('medicine_logs')
              .update(payload)
              .eq('id', widget.logId!);
        } catch (_) {
          // Fallback to sync service
          final sync = ref.read(syncServiceProvider);
          await sync.upsertMedicineLog(
            logId: widget.logId!,
            patientId: userId,
            prescriptionItemId: widget.prescriptionItemId ?? '',
            scheduledTime: scheduled,
            status: status,
            takenTime: status == 'taken' ? now : null,
          );
        }
      }

      // Cancel the notification
      if (widget.alarmId != null) {
        await ref.read(reminderServiceProvider).cancelAlarm(widget.alarmId!);
      }

      // Refresh providers
      ref.invalidate(dailyLogsProvider);
      ref.invalidate(adherenceReportProvider);
      ref.read(refreshTriggerProvider.notifier).state++;

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _handleSnooze() async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      final reminder = ref.read(reminderServiceProvider);
      if (widget.alarmId != null) {
        await reminder.snooze(id: widget.alarmId!, minutes: 10);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alarm snoozed for 10 minutes')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _processing = false);
      }
    }
  }
}
