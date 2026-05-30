import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';

import '../../../models/doctor_inventory_item.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/async_value_widget.dart';

class DoctorInventoryScreen extends ConsumerStatefulWidget {
  const DoctorInventoryScreen({super.key});

  @override
  ConsumerState<DoctorInventoryScreen> createState() =>
      _DoctorInventoryScreenState();
}

class _DoctorInventoryScreenState extends ConsumerState<DoctorInventoryScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inventoryAsync = ref.watch(doctorInventoryProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'My Inventory',
          style: theme.textTheme.titleLarge,
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: SizedBox.expand(
        child: SafeArea(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  indicatorColor: theme.colorScheme.primary,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  tabs: const [
                    Tab(text: 'All Medicines'),
                    Tab(text: 'Low Stock'),
                  ],
                ),
                Expanded(
                  child: AsyncValueWidget(
                    value: inventoryAsync,
                    data: (inventory) {
                      if (inventory.isEmpty) {
                        return Center(
                          child: Text(
                            'No inventory items yet.\nTap + to add a medicine.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        );
                      }

                      final lowStock =
                          inventory.where((e) => e.isLowStock).toList();

                      return TabBarView(
                        children: [
                          _buildList(inventory),
                          _buildList(lowStock),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
        onPressed: () => _showAddEditDialog(null),
      ),
    );
  }

  Widget _buildList(List<DoctorInventoryItem> items) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Nothing here.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final stockColor = item.isEmpty
            ? theme.colorScheme.error
            : item.isCritical
                ? Colors.orange
                : item.isLowStock
                    ? Colors.amber
                    : Colors.green;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            borderRadius: 16,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: stockColor.withValues(alpha: 0.1),
                child: Text(
                  '${item.currentQuantity}',
                  style: theme.textTheme.labelMedium?.copyWith(color: stockColor, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                item.medicineName,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Price: Rs. ${item.pricePerUnit.toStringAsFixed(2)} / ${item.unit} \nThreshold: ${item.lowStockThreshold}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              trailing: IconButton(
                icon: Icon(Icons.edit, color: theme.colorScheme.onSurfaceVariant),
                onPressed: () => _showAddEditDialog(item),
              ),
            ),
          ).animate().slideY(begin: 0.1, delay: (i * 20).ms),
        );
      },
    );
  }

  Future<void> _showAddEditDialog(DoctorInventoryItem? item) async {
    final theme = Theme.of(context);
    final nameCtrl = TextEditingController(text: item?.medicineName ?? '');
    final currentQtyCtrl =
        TextEditingController(text: item?.currentQuantity.toString() ?? '100');
    final totalQtyCtrl =
        TextEditingController(text: item?.totalQuantity.toString() ?? '100');
    final priceCtrl =
        TextEditingController(text: item?.pricePerUnit.toString() ?? '5.0');
    final thresholdCtrl =
        TextEditingController(text: item?.lowStockThreshold.toString() ?? '20');
    String unit = item?.unit ?? 'tablet';

    final isEdit = item != null;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: theme.scaffoldBackgroundColor,
              title: Text(
                isEdit ? 'Edit Inventory Item' : 'Add Medication',
                style: theme.textTheme.titleLarge,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Medicine Name',
                        labelStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: unit,
                      dropdownColor: theme.colorScheme.surface,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        labelStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      items: ['tablet', 'capsule', 'ml', 'drops', 'injection']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: theme.colorScheme.onSurface))))
                          .toList(),
                      onChanged: (v) => setState(() => unit = v!),
                    ),
                    TextField(
                      controller: currentQtyCtrl,
                      keyboardType: TextInputType.number,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Current Amount in Stock',
                        labelStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      onChanged: (v) {
                        if (!isEdit) totalQtyCtrl.text = v;
                      },
                    ),
                    if (isEdit)
                      TextField(
                        controller: totalQtyCtrl,
                        keyboardType: TextInputType.number,
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration(
                          labelText: 'Total Capacity',
                          labelStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Price per Unit (Rs.)',
                        labelStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    TextField(
                      controller: thresholdCtrl,
                      keyboardType: TextInputType.number,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Low Stock Alert Threshold',
                        labelStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final cQty = int.tryParse(currentQtyCtrl.text) ?? 0;
                    final tQty = int.tryParse(totalQtyCtrl.text) ?? cQty;
                    final price = double.tryParse(priceCtrl.text) ?? 0.0;
                    final threshold = int.tryParse(thresholdCtrl.text) ?? 20;

                    if (name.isEmpty) return;

                    final user = ref.read(currentUserProfileProvider).value;
                    if (user == null) return;

                    final client = ref.read(supabaseServiceProvider).client!;

                    try {
                      if (isEdit) {
                        await client.from('doctor_inventory').update({
                          'medicine_name': name,
                          'unit': unit,
                          'current_quantity': cQty,
                          'total_quantity': tQty,
                          'price_per_unit': price,
                          'low_stock_threshold': threshold,
                          'updated_at': DateTime.now().toUtc().toIso8601String(),
                        }).eq('id', item.id);
                      } else {
                        await client.from('doctor_inventory').insert({
                          'id': const Uuid().v4(),
                          'doctor_id': user.id,
                          'medicine_name': name,
                          'unit': unit,
                          'current_quantity': cQty,
                          'total_quantity': tQty,
                          'price_per_unit': price,
                          'low_stock_threshold': threshold,
                        });
                      }
                      ref.read(inventoryRefreshProvider.notifier).state++;
                      if (context.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      debugPrint('Error saving inventory: $e');
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
