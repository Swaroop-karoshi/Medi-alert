import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/glass_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../models/doctor_inventory_item.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/async_value_widget.dart';

class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final countAsync = ref.watch(doctorPatientsProvider);
    final lowStockAsync = ref.watch(doctorLowStockAlertsProvider);


    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Doctor Dashboard', style: theme.textTheme.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: SizedBox.expand(
        child: SafeArea(
          child: AsyncValueWidget(
            value: userAsync,
            data: (user) => ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                const SizedBox(height: 20),
                Text('Welcome back,', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                Text('Dr. ${user?.name ?? "Doctor"}', style: theme.textTheme.headlineMedium),
                Text('ID: ${user?.shortCode ?? "---"}', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 32),
                _buildStatsRow(context, countAsync, lowStockAsync),
                const SizedBox(height: 40),
                Text('Quick Actions', style: theme.textTheme.titleLarge),
                _actionTile(context, 'New Prescription', 'Assign meds to multiple patients', Icons.add_circle, '/add-medicine', theme.colorScheme.primary),
                const SizedBox(height: 32),
                // Low Stock Alerts Section
                _buildLowStockSection(context, lowStockAsync),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    AsyncValue<List<dynamic>> countAsync,
    AsyncValue<List<DoctorInventoryItem>> lowStockAsync,
  ) {
    final theme = Theme.of(context);
    final lowStockCount = lowStockAsync.maybeWhen(
      data: (d) => d.length,
      orElse: () => 0,
    );
    return Row(
      children: [
        Expanded(
          child: _statCard(
            context,
            'Total Patients',
            countAsync.maybeWhen(data: (d) => d.length.toString(), orElse: () => '0'),
            Icons.group,
            theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _statCard(
            context,
            'Low Stock',
            lowStockCount.toString(),
            Icons.warning_amber_rounded,
            lowStockCount > 0 ? theme.colorScheme.error : Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _statCard(BuildContext context, String label, String value, IconData icon, Color iconColor) {
    final theme = Theme.of(context);
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.headlineMedium),
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    ).animate().fadeIn().scale(delay: 200.ms);
  }

  Widget _buildLowStockSection(
    BuildContext context,
    AsyncValue<List<DoctorInventoryItem>> lowStockAsync,
  ) {
    final theme = Theme.of(context);
    return lowStockAsync.when(
      data: (alerts) {
        if (alerts.isEmpty) {
          return GlassCard(
            borderRadius: 20,
            backgroundColor: Colors.green.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your inventory stock levels are healthy.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚠️ My Low Stock Alerts (${alerts.length})',
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...alerts.map((alert) {
              final color = alert.isCritical ? theme.colorScheme.error : Colors.orange;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  borderRadius: 18,
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.2),
                      child: Text(
                        '${alert.currentQuantity}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      alert.medicineName,
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      '${alert.currentQuantity} ${alert.unit}(s) left • threshold: ${alert.lowStockThreshold}',
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, color: theme.colorScheme.outline, size: 14),
                    onTap: () => context.go('/doctor/inventory'),
                  ),
                ),
              ).animate().slideX(begin: 0.1, end: 0, delay: 50.ms);
            }),
          ],
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(color: theme.colorScheme.primary),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }



  Widget _actionTile(BuildContext context, String title, String subtitle, IconData icon, String route, Color accent, {bool isTab = false}) {
    final theme = Theme.of(context);
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: accent),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: Icon(Icons.arrow_forward_ios, color: theme.colorScheme.outline, size: 16),
        onTap: () => isTab ? context.go(route) : context.push(route),
      ),
    ).animate().slideX(begin: 0.2, end: 0, delay: 300.ms);
  }
}
