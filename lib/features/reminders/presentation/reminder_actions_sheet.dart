import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/glass_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../models/medicine_log.dart';
import '../../../providers/app_providers.dart';

class ReminderActionsSheet extends ConsumerWidget {
  const ReminderActionsSheet({
    super.key,
    required this.alarmId,
    required this.prescriptionItemId,
    required this.scheduledTime,
    this.medicineName,
  });

  final int alarmId;
  final String prescriptionItemId;
  final DateTime scheduledTime;

  /// The name of the medicine (shown in the sheet header).
  final String? medicineName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminder = ref.read(reminderServiceProvider);
    final displayName =
        (medicineName != null && medicineName!.isNotEmpty) ? medicineName! : 'Medicine';

    return GlassCard(
      borderRadius: 30,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // Medicine icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white12,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medication, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            'Time for $displayName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.greenAccent,
              child: Icon(Icons.check, color: Colors.black),
            ),
            title: const Text(
              'Mark as Taken',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Reduces inventory count by 1',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            onTap: () => _logIntake(ref, context, MedicineLogStatus.taken),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orangeAccent,
              child: Icon(Icons.redo, color: Colors.black),
            ),
            title: const Text(
              'Skip this Dose',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => _logIntake(ref, context, MedicineLogStatus.skipped),
          ),
          const Divider(color: Colors.white10, indent: 20, endIndent: 20),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.snooze, color: Colors.white),
            ),
            title: const Text(
              'Snooze 10 minutes',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              reminder.snooze(id: alarmId, minutes: 10);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    ).animate().slideY(begin: 1, end: 0, curve: Curves.easeOutCubic);
  }

  Future<void> _logIntake(
    WidgetRef ref,
    BuildContext context,
    MedicineLogStatus status,
  ) async {
    final client = ref.read(supabaseServiceProvider).client;
    final userId = ref.read(currentUserProfileProvider).value?.id;

    if (userId == null || client == null) return;

    String? existingLogId;
    try {
      final existing = await client
          .from('medicine_logs')
          .select('id')
          .eq('patient_id', userId)
          .eq('prescription_item_id', prescriptionItemId)
          .eq('scheduled_time', scheduledTime.toIso8601String())
          .maybeSingle();
      existingLogId = existing?['id'] as String?;
    } catch (_) {
      // Fall back to deterministic id when lookup fails.
    }

    final reminderService = ref.read(reminderServiceProvider);
    final logId =
        existingLogId ??
        'alarm_${reminderService.deterministicAlarmId("$prescriptionItemId:${scheduledTime.toIso8601String()}")}';

    final log = MedicineLog(
      id: logId,
      patientId: userId,
      prescriptionItemId: prescriptionItemId,
      scheduledTime: scheduledTime,
      takenTime: status == MedicineLogStatus.taken ? DateTime.now() : null,
      status: status,
    );

    await ref
        .read(syncServiceProvider)
        .upsertMedicineLog(
          logId: log.id,
          patientId: log.patientId,
          prescriptionItemId: log.prescriptionItemId,
          scheduledTime: log.scheduledTime,
          status: status.name,
          takenTime: log.takenTime,
        );

    await reminderService.cancelAlarm(alarmId);

    ref.invalidate(dailyLogsProvider);
    ref.invalidate(adherenceReportProvider);
    ref.read(inventoryRefreshProvider.notifier).state++;

    if (context.mounted) Navigator.pop(context);
  }
}
