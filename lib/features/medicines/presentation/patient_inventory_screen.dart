import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/async_value_widget.dart';
import '../../../providers/app_providers.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PatientInventoryScreen extends ConsumerWidget {
  const PatientInventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(allPrescriptionItemsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('My Medicine Stock', style: theme.textTheme.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(allPrescriptionItemsProvider);
              ref.invalidate(dailyLogsProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMedicineDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
      ),
      body: AsyncValueWidget(
        value: itemsAsync,
        data: (rawItems) {
          if (rawItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No active prescriptions found.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          final items = _groupItems(rawItems);
          
          final lowStockItems = items.where((i) {
            final left = i['tablets_left'] as int? ?? 0;
            final total = i['prescribed_quantity'] as int? ?? 1;
            final config = i['frequency_config'] as Map<String, dynamic>? ?? {};
            final threshold = config['custom_threshold'] as int? ?? (total * 0.2).ceil();
            return left <= threshold;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (lowStockItems.isNotEmpty) ...[
                _buildLowStockAlert(context, lowStockItems),
                const SizedBox(height: 24),
              ],
              Text(
                'Current Inventory',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...items.map((item) => _buildStockCard(context, ref, item)),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _groupItems(List<Map<String, dynamic>> rawItems) {
    final Map<String, Map<String, dynamic>> groupedItems = {};
    for (final item in rawItems) {
      final key = '${item['medicine_name']}_${item['dosage_type']}';
      if (groupedItems.containsKey(key)) {
        groupedItems[key]!['tablets_left'] += item['tablets_left'];
        groupedItems[key]!['prescribed_quantity'] += item['prescribed_quantity'];
        
        // Merge frequency_config to keep custom_threshold if it exists
        final existingConfig = groupedItems[key]!['frequency_config'] as Map<String, dynamic>? ?? {};
        final newConfig = item['frequency_config'] as Map<String, dynamic>? ?? {};
        if (existingConfig['custom_threshold'] == null && newConfig['custom_threshold'] != null) {
          groupedItems[key]!['frequency_config'] = newConfig;
        }
      } else {
        groupedItems[key] = Map<String, dynamic>.from(item);
      }
    }
    return groupedItems.values.toList();
  }

  Widget _buildLowStockAlert(BuildContext context, List<Map<String, dynamic>> lowStock) {
    final theme = Theme.of(context);
    return GlassCard(
      backgroundColor: theme.colorScheme.error.withValues(alpha: 0.1),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Low Stock Alert',
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${lowStock.length} medicines are running out soon.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true)).shimmer(duration: 2.seconds, color: theme.colorScheme.error.withValues(alpha: 0.2));
  }

  Widget _buildStockCard(BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final stockLeft = item['tablets_left'] as int? ?? 0;
    final total = item['prescribed_quantity'] as int? ?? 1;
    
    // Threshold: 20% of total OR custom value from frequency_config
    final config = item['frequency_config'] as Map<String, dynamic>? ?? {};
    final threshold = config['custom_threshold'] as int? ?? (total * 0.2).ceil();
    
    final progress = (stockLeft / total).clamp(0.0, 1.0);
    final isLow = stockLeft <= threshold;
    final color = isLow ? theme.colorScheme.error : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showThresholdDialog(context, ref, item, threshold),
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['medicine_name'] ?? 'Unknown Medicine',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${item['dosage_type']} • Alert at ≤ $threshold',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$stockLeft left',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Prescribed: $total',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    '${(progress * 100).toInt()}% Remaining',
                    style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showThresholdDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> item, int currentThreshold) {
    final theme = Theme.of(context);
    final controller = TextEditingController(text: currentThreshold.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Stock Alert', style: theme.textTheme.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notify me when stock for "${item['medicine_name']}" falls strictly below or equal to:',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                suffixText: 'units',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Default is 20% of total prescribed.',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = int.tryParse(controller.text);
              if (val != null) {
                final client = ref.read(supabaseServiceProvider).client;
                if (client != null) {
                  try {
                    final Map<String, dynamic> config = Map<String, dynamic>.from(item['frequency_config'] ?? {});
                    config['custom_threshold'] = val;

                    await client
                        .from('prescription_items')
                        .update({'frequency_config': config})
                        .eq('id', item['id']);
                    
                    ref.invalidate(allPrescriptionItemsProvider);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update: $e')),
                      );
                    }
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddMedicineDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final nameCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    String dosageType = 'tablet';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add New Medicine', style: theme.textTheme.titleMedium),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: _inputDecoration(context, 'Medicine Name', Icons.medication),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: dosageType,
                  decoration: _inputDecoration(context, 'Dosage Type', Icons.category),
                  items: ['tablet', 'capsule', 'syrup', 'injection', 'drops']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => dosageType = v!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(context, 'Current Stock', Icons.inventory),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || stockCtrl.text.isEmpty) return;
                final qty = int.tryParse(stockCtrl.text) ?? 0;
                
                final client = ref.read(supabaseServiceProvider).client;
                final user = client?.auth.currentUser;
                if (client == null || user == null) return;

                try {
                  // 1. Get or create "Self Managed" prescription
                  final prescriptionRes = await client
                      .from('prescriptions')
                      .select()
                      .eq('doctor_id', user.id)
                      .eq('title', 'Self Managed')
                      .maybeSingle();

                  String pId;
                  if (prescriptionRes == null) {
                    pId = ref.read(uuidProvider).v4();
                    await client.from('prescriptions').insert({
                      'id': pId,
                      'doctor_id': user.id,
                      'title': 'Self Managed',
                      'notes': 'Medicines added manually by patient.',
                    });

                    // 2. Link to self in patient_prescriptions
                    await client.from('patient_prescriptions').insert({
                      'patient_id': user.id,
                      'prescription_id': pId,
                      'status': 'accepted',
                    });
                  } else {
                    pId = prescriptionRes['id'];
                  }

                  // 3. Add the item
                  await client.from('prescription_items').insert({
                    'id': ref.read(uuidProvider).v4(),
                    'prescription_id': pId,
                    'medicine_name': nameCtrl.text,
                    'dosage_type': dosageType,
                    'prescribed_quantity': qty,
                    'duration_start': DateTime.now().toIso8601String(),
                    'duration_end': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
                    'frequency_config': {
                      'days': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                      'times_per_day': 0,
                      'custom_times': [],
                    },
                    'meal_config': {'slots': []},
                  });

                  ref.invalidate(allPrescriptionItemsProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String label, IconData icon) {
    final theme = Theme.of(context);
    return InputDecoration(
      prefixIcon: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      labelText: label,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
