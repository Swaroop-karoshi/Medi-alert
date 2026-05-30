import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/prescription_item.dart';
import '../../../providers/app_providers.dart';
import '../../../services/permission_service.dart';
import '../../../services/scheduler_service.dart';
import '../../../widgets/glass_card.dart';

class ApprovedPrescriptionScreen extends ConsumerStatefulWidget {
  const ApprovedPrescriptionScreen({super.key, required this.linkId});

  final String linkId;

  @override
  ConsumerState<ApprovedPrescriptionScreen> createState() =>
      _ApprovedPrescriptionScreenState();
}

class _ApprovedPrescriptionScreenState
    extends ConsumerState<ApprovedPrescriptionScreen> {
  final Map<String, TimeOfDay> _slotTimes = {};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final approvedAsync = ref.watch(enhancedApprovedPrescriptionsProvider);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Approved Medication Timings',
          style: theme.textTheme.titleLarge,
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: approvedAsync.when(
        data: (approved) {
          final link = approved.firstWhere(
            (e) => e['id'] == widget.linkId,
            orElse: () => <String, dynamic>{},
          );
          if (link.isEmpty) {
            return const Center(child: Text('Prescription not found'));
          }

          final parent = link['prescriptions'] as Map<String, dynamic>;
          final itemMaps = List<Map<String, dynamic>>.from(
            parent['prescription_items'] ?? const [],
          );
          final items = itemMaps.map(PrescriptionItem.fromMap).toList();
          _ensureDefaults(link, items);

          final allSlots = _extractSlots(items);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _glassCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.assignment_turned_in, color: theme.colorScheme.primary),
                  ),
                  title: Text(parent['title'] ?? 'Prescription', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Dr. ${parent['profiles']?['name'] ?? 'Unknown'}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Modify Approved Timings',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...allSlots.map((slot) => _slotTile(context, slot)),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _saving ? null : () => _save(link, items),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(_saving ? 'Saving...' : 'Save & Regenerate Alarms', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Set<String> _extractSlots(List<PrescriptionItem> items) {
    final result = <String>{};
    for (final item in items) {
      final slots = List<String>.from(item.mealConfig['slots'] ?? const []);
      result.addAll(slots);
    }
    return result;
  }

  void _ensureDefaults(
    Map<String, dynamic> link,
    List<PrescriptionItem> items,
  ) {
    if (_slotTimes.isNotEmpty) return;

    final saved = Map<String, dynamic>.from(link['modified_schedule'] ?? {});
    final allSlots = _extractSlots(items);
    for (final slot in allSlots) {
      final raw = saved[slot]?.toString();
      if (raw != null && raw.contains(':')) {
        final p = raw.split(':');
        _slotTimes[slot] = TimeOfDay(
          hour: int.parse(p[0]),
          minute: int.parse(p[1]),
        );
      } else {
        _slotTimes[slot] = const TimeOfDay(hour: 8, minute: 0);
      }
    }
  }

  Widget _glassCard({required Widget child}) {
    return GlassCard(padding: const EdgeInsets.all(20), child: child);
  }

  Widget _slotTile(BuildContext context, String slotKey) {
    final theme = Theme.of(context);
    final label = slotKey.replaceAll('_', ' ');
    final time = _slotTimes[slotKey] ?? const TimeOfDay(hour: 8, minute: 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderRadius: 16,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(
            label[0].toUpperCase() + label.substring(1),
            style: theme.textTheme.bodyLarge,
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              time.format(context),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
            );
            if (picked != null) {
              setState(() => _slotTimes[slotKey] = picked);
            }
          },
        ),
      ),
    );
  }

  Future<void> _save(
    Map<String, dynamic> link,
    List<PrescriptionItem> items,
  ) async {
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseServiceProvider).client;
      final userId = ref.read(currentUserProfileProvider).value?.id;
      if (client == null || userId == null) return;

      await PermissionService.requestAllPermissions();

      final scheduleMap = _slotTimes.map((k, v) {
        final h = v.hour.toString().padLeft(2, '0');
        final m = v.minute.toString().padLeft(2, '0');
        return MapEntry(k, '$h:$m');
      });

      await client
          .from('patient_prescriptions')
          .update({'modified_schedule': scheduleMap})
          .eq('id', link['id']);

      final itemIds = items.map((e) => e.id).toList();
      final now = DateTime.now();
      await client
          .from('medicine_logs')
          .delete()
          .eq('patient_id', userId)
          .eq('status', 'missed')
          .inFilter('prescription_item_id', itemIds)
          .gte('scheduled_time', now.toUtc().toIso8601String());

      // Fetch existing logs to prevent duplicate key constraint violations for today's past logs
      final existingResponse = await client
          .from('medicine_logs')
          .select('scheduled_time, prescription_item_id')
          .eq('patient_id', userId)
          .inFilter('prescription_item_id', itemIds);

      final existingSet = <String>{};
      if (existingResponse != null) {
        for (final row in existingResponse as List) {
          final st = DateTime.parse(row['scheduled_time'] as String).toUtc().toIso8601String();
          final itemId = row['prescription_item_id'] as String;
          existingSet.add('$itemId|$st');
        }
      }

      const uuid = Uuid();
      final reminder = ref.read(reminderServiceProvider);
      final medicineByItem = {for (final i in items) i.id: i.medicineName};
      final logs = <Map<String, dynamic>>[];
      final horizon = now.add(const Duration(days: 14));

      for (final item in items) {
        final generated = SchedulerService.generateTimestamps(
          item: item,
          personalSlotTimes: _slotTimes,
        );
        for (final ts in generated) {
          final isToday = ts.year == now.year && ts.month == now.month && ts.day == now.day;
          if (!isToday && !ts.isAfter(now)) continue;

          final tsUtcStr = ts.toUtc().toIso8601String();
          if (existingSet.contains('${item.id}|$tsUtcStr')) continue;

          final logId = uuid.v4();
          logs.add({
            'id': logId,
            'patient_id': userId,
            'prescription_item_id': item.id,
            'scheduled_time': tsUtcStr,
            'status': 'missed',
          });
          final doctorName = link['prescriptions']?['profiles']?['name'] as String?;
          if (ts.isBefore(horizon)) {
            await reminder.scheduleAlarm(
              id: reminder.deterministicAlarmId(logId),
              at: ts,
              medicineName: medicineByItem[item.id],
              doctorName: doctorName,
              prescriptionItemId: item.id,
              logId: logId,
            );
          }
        }
      }
      if (logs.isNotEmpty) {
        await client.from('medicine_logs').insert(logs);
      }

      ref.invalidate(enhancedApprovedPrescriptionsProvider);
      ref.invalidate(dailyLogsProvider);
      ref.invalidate(enhancedDailyLogsProvider);
      ref.read(refreshTriggerProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Approved timings updated')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
