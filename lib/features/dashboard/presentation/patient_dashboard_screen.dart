import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/glass_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/app_providers.dart';
import '../../../services/permission_service.dart';
import '../../../widgets/async_value_widget.dart';

class PatientDashboardScreen extends ConsumerStatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  ConsumerState<PatientDashboardScreen> createState() =>
      _PatientDashboardScreenState();
}

class _PatientDashboardScreenState
    extends ConsumerState<PatientDashboardScreen> {
  Map<String, bool>? _permissionStatuses;

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkPermissions);
  }

  Future<void> _checkPermissions() async {
    final statuses = await PermissionService.getPermissionStatuses();
    if (mounted) {
      setState(() => _permissionStatuses = statuses);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logAsync = ref.watch(enhancedDailyLogsProvider);
    final invitesAsync = ref.watch(enhancedPendingInvitesProvider);
    final pendingPrescriptionsAsync = ref.watch(
      enhancedPendingPrescriptionsProvider,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Patient Dashboard',
          style: theme.textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.push('/patient/reports'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: theme.colorScheme.surface,
        child: SafeArea(
          child: Column(
            children: [
              DrawerHeader(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.medication, color: theme.colorScheme.primary, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'MediAlert',
                        style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.alarm, color: theme.colorScheme.onSurfaceVariant),
                title: Text('Test 5s Alarm', style: theme.textTheme.bodyMedium),
                onTap: () async {
                  await PermissionService.requestAllPermissions(context);
                  final reminder = ref.read(reminderServiceProvider);
                  final now = DateTime.now().add(const Duration(seconds: 5));
                  try {
                    await reminder.scheduleAlarm(
                      id: 9999,
                      at: now,
                      medicineName: 'Test Medicine',
                      doctorName: 'Test Doctor',
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Alarm failed: $e')),
                      );
                    }
                    return;
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Test alarm set for 5 seconds! Lock your screen now.',
                        ),
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.bolt, color: Colors.orange),
                title: Text('Background Reliability', style: theme.textTheme.bodyMedium),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/background-stability');
                },
              ),
              const Spacer(),
              ListTile(
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
                title: Text('Sign Out', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                onTap: () => ref.read(authServiceProvider).signOut(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      body: SizedBox.expand(
        child: SafeArea(
          child: Column(
            children: [
              // Permission warning card
              if (_permissionStatuses != null &&
                  _permissionStatuses!.values.any((v) => !v))
                _buildPermissionWarningCard(),
              _buildReliabilityNotice(),
              _buildLowStockSection(ref),
              _buildPendingGuidance(pendingPrescriptionsAsync),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(dailyLogsProvider);
                    ref.invalidate(enhancedDailyLogsProvider);
                    ref.invalidate(enhancedApprovedPrescriptionsProvider);
                    ref.invalidate(enhancedPendingPrescriptionsProvider);
                    ref.read(refreshTriggerProvider.notifier).state++;
                    ref.read(inventoryRefreshProvider.notifier).state++;
                    await _checkPermissions();
                  },
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      const SizedBox(height: 12),
                      Consumer(
                        builder: (context, ref, _) {
                          final user = ref.watch(currentUserProfileProvider).value;
                          if (user == null) return const SizedBox.shrink();
                          final theme = Theme.of(context);
                          return GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  child: Icon(Icons.person, color: theme.colorScheme.primary, size: 32),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome, ${user.name}',
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Patient ID: ${user.shortCode}',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildInvitesSection(context, ref, invitesAsync),
                      _buildPendingPrescriptionsSection(
                        context,
                        pendingPrescriptionsAsync,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle("Today's Schedule"),
                      _buildTimelineSection(context, ref, logAsync),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionWarningCard() {
    final missing = _permissionStatuses!.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: GlassCard(
        backgroundColor: theme.colorScheme.error.withValues(alpha: 0.1),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: theme.colorScheme.error, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Permissions Required',
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error),
                  ),
                  Text(
                    'Missing: ${missing.join(", ")}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                await PermissionService.requestAllPermissions(context);
                await _checkPermissions();
              },
              child: Text('Fix', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.3, end: 0);
  }

  Widget _buildReliabilityNotice() {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: GlassCard(
            backgroundColor: Colors.orange.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Want 100% reliable alarms? Check our Background Guide.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange.shade800),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/background-stability'),
                  child: Text('View', style: TextStyle(color: Colors.orange.shade800)),
                ),
              ],
            ),
          ),
        ).animate().fadeIn();
      }
    );
  }

  Widget _buildLowStockSection(WidgetRef ref) {
    final lowStockAsync = ref.watch(patientLowStockAlertsProvider);
    return lowStockAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: InkWell(
            onTap: () => context.go('/patient/inventory'),
            child: GlassCard(
              backgroundColor: theme.colorScheme.error.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.inventory_2, color: theme.colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Low Stock: ${items.length} medicines need refill!',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 14, color: theme.colorScheme.error),
                ],
              ),
            ),
          ),
        ).animate().shake();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, st) => const SizedBox.shrink(),
    );
  }

  Widget _buildPendingGuidance(
    AsyncValue<List<Map<String, dynamic>>> pendingAsync,
  ) {
    return pendingAsync.when(
      data: (pending) {
        if (pending.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              return GlassCard(
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You have a new prescription! Please "Approve" it below to start your schedule.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              );
            }
          ),
        ).animate().fadeIn();
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildTimelineSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Map<String, dynamic>>> logsAsync,
  ) {
    final approved =
        ref.watch(enhancedApprovedPrescriptionsProvider).value ?? [];

    return AsyncValueWidget(
      value: logsAsync,
      data: (logs) {
        if (logs.isEmpty) {
          if (approved.isNotEmpty) {
            return _buildEmptyState(
              'No medicines scheduled for today. Tap on an "Approved" prescription above to set your timings.',
            );
          }
          return _buildEmptyState('No medicines scheduled for today.');
        }

        return Column(
          children: logs.map((log) => _TimelineTile(log: log)).toList(),
        );
      },
    );
  }



  Widget _buildPendingPrescriptionsSection(
    BuildContext context,
    AsyncValue<List<Map<String, dynamic>>> pendingAsync,
  ) {
    final pending = pendingAsync.value ?? const <Map<String, dynamic>>[];
    if (pending.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildSectionTitle('Pending Prescriptions'),
        const SizedBox(height: 8),
        _prescriptionList(context, pending),
      ],
    );
  }

  Widget _prescriptionList(
    BuildContext context,
    List<Map<String, dynamic>> list,
  ) {
    if (list.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: list.map((p) {
          final parent = p['prescriptions'];
        final doctor = parent['profiles'];
        final itemsCount = (parent['prescription_items'] as List).length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(Icons.description, color: Theme.of(context).colorScheme.primary),
              ),
              title: Text(
                parent['title'],
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                'Dr. ${doctor['name']} • $itemsCount medicine(s)\nNeeds approval',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.outline,
                size: 16,
              ),
              onTap: () {
                context.push('/prescription-approval/${p['id']}');
              },
            ),
          ),
        );
      }).toList(),
      ),
    );
  }

  Widget _buildInvitesSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Map<String, dynamic>>> invitesAsync,
  ) {
    return AsyncValueWidget(
      value: invitesAsync,
      data: (invites) {
        if (invites.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Doctor Invites'),
            const SizedBox(height: 12),
            ...invites.map((invite) => _InviteTile(invite: invite)),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      }
    );
  }

  Widget _buildEmptyState(String message) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.event_note, color: theme.colorScheme.outline, size: 48),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}

class _TimelineTile extends ConsumerWidget {
  const _TimelineTile({required this.log});
  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final item = log['prescription_items'];
    final time = DateTime.parse(log['scheduled_time']).toLocal();
    final status = log['status']; // taken, missed, skipped, denied

    Color statusColor = theme.colorScheme.outline;
    IconData statusIcon = Icons.schedule;
    if (status == 'taken') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (status == 'skipped') {
      statusColor = Colors.orange;
      statusIcon = Icons.skip_next;
    } else if (status == 'denied') {
      statusColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
      statusIcon = Icons.cancel;
    } else if (status == 'missed' && time.isBefore(DateTime.now())) {
      statusColor = theme.colorScheme.error;
      statusIcon = Icons.error_outline;
    } else if (status == 'missed' && time.isAfter(DateTime.now())) {
      statusColor = theme.colorScheme.primary;
      statusIcon = Icons.schedule;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderRadius: 20,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showDetailPopup(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              title: Text(
                item['medicine_name'],
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} • ${item['dosage_type']} • ${_statusLabel(status, time)}',
                style: theme.textTheme.bodySmall,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == 'missed')
                    TextButton.icon(
                      onPressed: () => _editTodaySchedule(context, ref),
                      icon: const Icon(Icons.add_alarm, size: 18),
                      label: const Text('Set Alarm'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  else
                    Icon(statusIcon, color: statusColor, size: 22),
                  if (status == 'missed') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.check_circle_outline,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      tooltip: 'Mark as taken',
                      onPressed: () => _updateStatus(ref, 'taken'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().slideX(begin: -0.1, end: 0);
  }

  void _showDetailPopup(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final item = log['prescription_items'];
    final time = DateTime.parse(log['scheduled_time']).toLocal();
    
    final startDate = DateTime.parse(item['duration_start']).toLocal();
    final endDate = DateTime.parse(item['duration_end']).toLocal();
    final mealConfig = item['meal_config'] is String 
        ? jsonDecode(item['meal_config']) 
        : item['meal_config'];
    final slots = List<String>.from(mealConfig['slots'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['medicine_name'],
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          item['dosage_type'],
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _detailRow(
                context,
                Icons.date_range,
                'Treatment Period',
                '${startDate.day}/${startDate.month}/${startDate.year} to ${endDate.day}/${endDate.month}/${endDate.year}',
              ),
              const SizedBox(height: 16),
              _detailRow(
                context,
                Icons.restaurant,
                'Instruction',
                slots.map((s) {
                  final label = s.replaceAll('_', ' ');
                  return label[0].toUpperCase() + label.substring(1);
                }).join(', '),
              ),
              const SizedBox(height: 16),
              _detailRow(
                context,
                Icons.access_time,
                'Scheduled for today',
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _editTodaySchedule(context, ref);
                  },
                  icon: const Icon(Icons.add_alarm),
                  label: const Text('Set Alarm / Edit Timing', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }


  String _statusLabel(String status, DateTime time) {
    switch (status) {
      case 'taken':
        return 'Taken ✓';
      case 'skipped':
        return 'Skipped';
      case 'denied':
        return 'Denied';
      case 'missed':
        return time.isBefore(DateTime.now()) ? 'Missed' : 'Upcoming';
      default:
        return '';
    }
  }

  Future<void> _editTodaySchedule(BuildContext context, WidgetRef ref) async {
    final client = ref.read(supabaseServiceProvider).client;
    if (client == null) return;

    final scheduled = DateTime.parse(log['scheduled_time']).toLocal();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: scheduled.hour, minute: scheduled.minute),
    );
    if (picked == null) return;

    final newTime = DateTime(
      scheduled.year,
      scheduled.month,
      scheduled.day,
      picked.hour,
      picked.minute,
    );

    await client
        .from('medicine_logs')
        .update({'scheduled_time': newTime.toUtc().toIso8601String()})
        .eq('id', log['id']);

    final reminder = ref.read(reminderServiceProvider);
    final alarmId = reminder.deterministicAlarmId(log['id'] as String);
    await reminder.cancelAlarm(alarmId);
    if (newTime.isAfter(DateTime.now())) {
      await PermissionService.requestAllPermissions();
      final item = log['prescription_items'];
      final doctorName = item?['prescriptions']?['profiles']?['name'] as String?;
      await reminder.scheduleAlarm(
        id: alarmId,
        at: newTime,
        medicineName: item?['medicine_name'] as String?,
        doctorName: doctorName,
        prescriptionItemId: log['prescription_item_id'] as String,
        logId: log['id'] as String,
      );
    }

    ref.invalidate(enhancedDailyLogsProvider);
    ref.invalidate(enhancedApprovedPrescriptionsProvider);
    ref.read(refreshTriggerProvider.notifier).state++;
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Today schedule updated')));
    }
  }

  Future<void> _updateStatus(WidgetRef ref, String newStatus) async {
    final client = ref.read(supabaseServiceProvider).client;
    if (client == null) return;

    final now = DateTime.now();
    final scheduled = DateTime.parse(log['scheduled_time']).toLocal();
    final payload = <String, dynamic>{
      'status': newStatus,
      if (newStatus == 'taken') 'taken_time': now.toIso8601String(),
      if (newStatus == 'taken')
        'deviation_minutes': now.difference(scheduled).inMinutes,
    };

    try {
      await client.from('medicine_logs').update(payload).eq('id', log['id']);
    } catch (_) {
      final sync = ref.read(syncServiceProvider);
      await sync.upsertMedicineLog(
        logId: log['id'] as String,
        patientId: log['patient_id'] as String,
        prescriptionItemId: log['prescription_item_id'] as String,
        scheduledTime: scheduled,
        status: newStatus,
        takenTime: newStatus == 'taken' ? now : null,
      );
    }

    ref.invalidate(dailyLogsProvider);
    ref.invalidate(adherenceReportProvider);
    ref.read(refreshTriggerProvider.notifier).state++;
  }
}

class _InviteTile extends ConsumerWidget {
  const _InviteTile({required this.invite});
  final Map<String, dynamic> invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final doctor = invite['profiles'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderRadius: 20,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_add, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dr. ${doctor['name']}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Incoming Invitation',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _actionBtn(
                  Icons.close,
                  theme.colorScheme.error,
                  () => _handleResp(ref, 'rejected'),
                ),
                const SizedBox(width: 12),
                _actionBtn(
                  Icons.check,
                  Colors.green,
                  () => _handleResp(ref, 'accepted'),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().slideX(
      begin: 1,
      end: 0,
      duration: 400.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Future<void> _handleResp(WidgetRef ref, String status) async {
    final client = ref.read(supabaseServiceProvider).client;
    if (client == null) return;

    final userId = ref.read(currentUserProfileProvider).value?.id;
    if (userId == null) return;

    // Update invite status
    await client
        .from('doctor_patient_invites')
        .update({'status': status, 'patient_id': userId})
        .eq('id', invite['id']);

    if (status == 'accepted') {
      // Create mapping in doctor_patient_map
      await client.from('doctor_patient_map').insert({
        'doctor_id': invite['doctor_id'],
        'patient_id': userId,
      });
    }

    ref.invalidate(pendingInvitesProvider);
    ref.invalidate(doctorPatientsProvider);
  }
}
