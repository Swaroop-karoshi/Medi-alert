import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/glass_card.dart';
import 'package:uuid/uuid.dart';

import '../../../models/prescription_item.dart';
import '../../../providers/app_providers.dart';
import '../../../services/scheduler_service.dart';
import '../../../services/permission_service.dart';

class PrescriptionApprovalScreen extends ConsumerStatefulWidget {
  const PrescriptionApprovalScreen({super.key, required this.medicineId});
  final String medicineId; // In the new schema, this is the prescription_id

  @override
  ConsumerState<PrescriptionApprovalScreen> createState() =>
      _PrescriptionApprovalScreenState();
}

class _PrescriptionApprovalScreenState
    extends ConsumerState<PrescriptionApprovalScreen> {
  final Map<String, TimeOfDay> _slotTimes = {};
  bool _isLoading = false;

  final Map<String, String> _slotLabels = {
    'before_breakfast': 'Before Breakfast',
    'after_breakfast': 'After Breakfast',
    'before_lunch': 'Before Lunch',
    'after_lunch': 'After Lunch',
    'before_dinner': 'Before Dinner',
    'after_dinner': 'After Dinner',
  };

  @override
  void initState() {
    super.initState();
    Future.microtask(_prefillFromMealTimes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prescriptionsAsync = ref.watch(enhancedPendingPrescriptionsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Review Prescription',
          style: theme.textTheme.titleLarge,
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: SizedBox.expand(
          child: prescriptionsAsync.when(
            data: (prescriptions) {
              final prescription = prescriptions.firstWhere(
                (e) => e['id'] == widget.medicineId,
                orElse: () => {},
              );
              if (prescription.isEmpty) {
                return Center(
                  child: Text(
                    'Prescription not found.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              final parent = prescription['prescriptions'];
              final doctor = parent['profiles'];
              final List itemsData = parent['prescription_items'] ?? [];
              final List<PrescriptionItem> items = itemsData
                  .map((e) => PrescriptionItem.fromMap(e))
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parent['title'],
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Prescribed by Dr. ${doctor['name']}',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        if (parent['notes'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Notes: ${parent['notes']}',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Configure Your Schedule',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...items.map((item) => _buildItemConfig(context, item)),
                  const SizedBox(height: 24),
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Summary',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Divider(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                        ...items.map((item) {
                          final cost = item.prescribedQuantity * item.pricePerUnit;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text('${item.medicineName} x${item.prescribedQuantity}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                ),
                                Text('Rs. ${cost.toStringAsFixed(2)}', style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          );
                        }),
                        Divider(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text('Total Amount', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            ),
                            Text(
                              'Rs. ${items.fold(0.0, (sum, i) => sum + (i.prescribedQuantity * i.pricePerUnit)).toStringAsFixed(2)}',
                              style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (_isLoading)
                    Center(
                      child: CircularProgressIndicator(color: theme.colorScheme.primary),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: () => _approve(prescription, items),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Pay & Approve',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              );
            },
            loading: () => Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary),
            ),
            error: (e, _) => Center(
              child: Text(
                'Error: $e',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
        ),
    );
  }

  Future<void> _prefillFromMealTimes() async {
    final mealTimes = await ref.read(patientMealTimesProvider.future);
    if (!mounted || mealTimes == null) return;

    final breakfast = _parse(mealTimes['breakfast_time'] ?? '08:00:00');
    final lunch = _parse(mealTimes['lunch_time'] ?? '13:00:00');
    final dinner = _parse(mealTimes['dinner_time'] ?? '20:00:00');

    setState(() {
      _slotTimes.putIfAbsent(
        'before_breakfast',
        () => _offset(breakfast, const Duration(minutes: -30)),
      );
      _slotTimes.putIfAbsent('after_breakfast', () => breakfast);
      _slotTimes.putIfAbsent(
        'before_lunch',
        () => _offset(lunch, const Duration(minutes: -30)),
      );
      _slotTimes.putIfAbsent('after_lunch', () => lunch);
      _slotTimes.putIfAbsent(
        'before_dinner',
        () => _offset(dinner, const Duration(minutes: -30)),
      );
      _slotTimes.putIfAbsent('after_dinner', () => dinner);
    });
  }

  TimeOfDay _parse(String hhmmss) {
    final parts = hhmmss.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  TimeOfDay _offset(TimeOfDay source, Duration delta) {
    final base = DateTime(2026, 1, 1, source.hour, source.minute).add(delta);
    final hour = (base.hour + 24) % 24;
    return TimeOfDay(hour: hour, minute: base.minute);
  }

  Widget _glassCard({required Widget child}) {
    return GlassCard(padding: const EdgeInsets.all(20), child: child);
  }

  Widget _buildItemConfig(BuildContext context, PrescriptionItem item) {
    final theme = Theme.of(context);
    final List slots = item.mealConfig['slots'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.medication, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    item.medicineName,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Divider(color: theme.colorScheme.outline.withValues(alpha: 0.2), height: 24),
              Text(
                'Pick a time for each assigned slot:',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              ...slots.map((slot) => _buildSlotPicker(context, slot.toString())),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSlotPicker(BuildContext context, String slotKey) {
    final theme = Theme.of(context);
    final label = _slotLabels[slotKey] ?? slotKey;
    final time = _slotTimes[slotKey];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          final t = await showTimePicker(
            context: context,
            initialTime: time ?? const TimeOfDay(hour: 8, minute: 0),
          );
          if (t != null) setState(() => _slotTimes[slotKey] = t);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                time?.format(context) ?? 'Tap to set',
                style: TextStyle(
                  color: time == null ? theme.colorScheme.error : theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approve(
    Map<String, dynamic> prescriptionLink,
    List<PrescriptionItem> items,
  ) async {
    // 0. Permission Check
    final hasPerms = await PermissionService.hasRequiredPermissions();
    if (!hasPerms) {
      await PermissionService.requestAllPermissions();
      // Even if they deny, we proceed but they might not get alarms
    }

    // Check if all slots have times
    for (final item in items) {
      final List slots = item.mealConfig['slots'] ?? [];
      for (final slot in slots) {
        if (_slotTimes[slot.toString()] == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Please set time for ${_slotLabels[slot] ?? slot}',
                ),
              ),
            );
          }
          return;
        }
      }
    }

    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final client = supabase.client;
      if (client == null) return;

      final userId = ref.read(currentUserProfileProvider).value?.id;
      if (userId == null) return;

      const uuid = Uuid();

      // Fetch existing logs to prevent duplicate key constraint violations
      final itemIds = items.map((e) => e.id).toList();
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

      // 1. Generate Log entries for all items
      final List<Map<String, dynamic>> allLogs = [];

      for (final item in items) {
        final triggers = SchedulerService.generateTimestamps(
          item: item,
          personalSlotTimes: _slotTimes,
        );

        for (final ts in triggers) {
          final tsUtcStr = ts.toUtc().toIso8601String();
          if (existingSet.contains('${item.id}|$tsUtcStr')) continue;

          allLogs.add({
            'id': uuid.v4(),
            'patient_id': userId,
            'prescription_item_id': item.id,
            'scheduled_time': tsUtcStr,
            'status': 'missed',
          });
        }
      }

      // Batch insert logs
      if (allLogs.isNotEmpty) {
        await client.from('medicine_logs').insert(allLogs);

        // 3. Schedule upcoming exact alarms (rolling window)
        final reminderService = ref.read(reminderServiceProvider);
        final now = DateTime.now();
        final windowEnd = now.add(const Duration(days: 14));
        final medicineByItemId = <String, String>{
          for (final item in items) item.id: item.medicineName,
        };

        final doctor = prescriptionLink['prescriptions']['profiles'];
        final doctorName = doctor['name'] as String?;

        for (final log in allLogs) {
          final scheduledTime = DateTime.parse(log['scheduled_time']);
          if (scheduledTime.isAfter(now) && scheduledTime.isBefore(windowEnd)) {
            final alarmId = reminderService.deterministicAlarmId(
              log['id'] as String,
            );
            await reminderService.scheduleAlarm(
              id: alarmId,
              at: scheduledTime,
              medicineName: medicineByItemId[log['prescription_item_id']],
              doctorName: doctorName,
              prescriptionItemId: log['prescription_item_id'] as String,
              logId: log['id'] as String,
            );
          }
        }
      }

      // 2. Update Link status
      await client
          .from('patient_prescriptions')
          .update({
            'status': 'accepted',
            'modified_schedule': _slotTimes.map((k, v) {
              final h = v.hour.toString().padLeft(2, '0');
              final m = v.minute.toString().padLeft(2, '0');
              return MapEntry(k, '$h:$m');
            }),
          })
          .eq('id', prescriptionLink['id']);
          
      // 2.5 Deduct from Doctor Inventory
      for (final item in items) {
        if (item.inventoryItemId != null && item.prescribedQuantity > 0) {
          try {
            await client.rpc('deduct_inventory', params: {
              'item_id': item.inventoryItemId,
              'qty_to_deduct': item.prescribedQuantity,
            });
          } catch (e) {
            debugPrint('Failed to deduct inventory for ${item.medicineName}: $e');
          }
        }
      }

      // 3. Reschedule Native Alarms (Simple trigger for now, real implementation would update ReminderService)
      ref.invalidate(pendingPrescriptionsProvider);
      ref.invalidate(dailyLogsProvider);
      ref.invalidate(enhancedDailyLogsProvider);
      ref.read(refreshTriggerProvider.notifier).state++;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription approved and alarms set!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
