import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/glass_card.dart';

import '../../../models/app_user.dart';
import '../../../models/doctor_inventory_item.dart';
import '../../../providers/app_providers.dart';

class AddMedicineScreen extends ConsumerStatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  ConsumerState<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends ConsumerState<AddMedicineScreen> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DoctorInventoryItem? _selectedMedicine;


  final List<String> _selectedDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  String _dosageType = 'tablet';
  
  // Frequency & Timing State
  int _selectedFreqIndex = 0; // 0: once, 1: twice, 2: thrice, 3: custom
  final List<TimeOfDay> _times = [const TimeOfDay(hour: 8, minute: 0)];
  final List<String> _slotsPerTime = ['before_breakfast'];
  
  final _searchController = SearchController();
  AppUser? _chosenPatient; // For single patient selection as per audio "dropdown to select patient" 
  // though the original code supported multiple. I will support single for the new UI or a search based one.

  // Inventory fields
  final _prescribedQtyCtrl = TextEditingController(text: '30');

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final patientsAsync = ref.watch(doctorPatientsProvider);
    final inventoryAsync = ref.watch(doctorInventoryProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'New Prescription',
          style: theme.textTheme.titleLarge,
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: SizedBox.expand(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _sectionTitle(context, '1. Select Patient'),
              const SizedBox(height: 12),
              _buildPatientSearch(patientsAsync),
              const SizedBox(height: 24),
              
              _sectionTitle(context, '2. Medicine Details'),
              const SizedBox(height: 12),
              _glassCard(
                child: Column(
                  children: [
                    _textField(
                      context,
                      _titleCtrl,
                      'Prescription Title (e.g., Fever Regimen)',
                      Icons.title,
                    ),
                    const SizedBox(height: 16),
                    inventoryAsync.when(
                      data: (inventory) {
                        return DropdownButtonFormField<DoctorInventoryItem>(
                          isExpanded: true,
                          initialValue: _selectedMedicine,
                          dropdownColor: theme.colorScheme.surface,
                          style: theme.textTheme.bodyLarge,
                          decoration: _inputDecoration(
                            context,
                            'Select Medicine',
                            Icons.medication,
                          ),
                          items: inventory.map((e) {
                            return DropdownMenuItem(
                              value: e,
                              child: Text(
                                '${e.medicineName} (${e.unit})',
                                style: TextStyle(color: theme.colorScheme.onSurface),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedMedicine = v;
                              if (v != null) {
                                _dosageType = v.unit;
                              }
                            });
                          },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, st) => Text('Error loading inventory', style: TextStyle(color: theme.colorScheme.error)),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _dosageType,
                      dropdownColor: theme.colorScheme.surface,
                      style: theme.textTheme.bodyLarge,
                      decoration: _inputDecoration(
                        context,
                        'Dosage Type',
                        Icons.category,
                      ),
                      items: ['tablet', 'syrup', 'injection', 'capsule', 'drop']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: theme.colorScheme.onSurface))),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _dosageType = v!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              _sectionTitle(context, '3. Schedule & Frequency'),
              const SizedBox(height: 12),
              _glassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How often per day?',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    _buildFrequencySelector(context),
                    const SizedBox(height: 24),
                    Text(
                      'Set Times & Slots',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_times.length, (index) => _buildTimeSlotRow(index)),
                    if (_selectedFreqIndex == 3) // For "Custom"
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton.icon(
                          onPressed: () => setState(() {
                            _times.add(const TimeOfDay(hour: 8, minute: 0));
                            _slotsPerTime.add('before_breakfast');
                          }),
                          icon: const Icon(Icons.add),
                          label: const Text('Add another time'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              _sectionTitle(context, '4. Duration & Quantity'),
              const SizedBox(height: 12),
              _glassCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _datePicker(
                            context,
                            'Start Date',
                            _startDate,
                            (d) => setState(() => _startDate = d),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _datePicker(
                            context,
                            'End Date',
                            _endDate,
                            (d) => setState(() => _endDate = d),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _prescribedQtyCtrl,
                      keyboardType: TextInputType.number,
                      style: theme.textTheme.bodyLarge,
                      decoration: _inputDecoration(
                        context,
                        'Total Quantity (e.g. 30)',
                        Icons.inventory_2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Create & Send Prescription',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }

  Widget _glassCard({required Widget child}) {
    return GlassCard(padding: const EdgeInsets.all(20), child: child);
  }

  Widget _buildPatientSearch(AsyncValue<List<AppUser>> patientsAsync) {
    return patientsAsync.when(
      data: (patients) {
        return SearchAnchor(
          searchController: _searchController,
          builder: (context, controller) {
            return _inputField(
              context,
              label: _chosenPatient?.name ?? 'Search for a patient (Name or Email)',
              icon: Icons.person_search,
              onTap: () => controller.openView(),
            );
          },
          suggestionsBuilder: (context, controller) {
            final query = controller.text.toLowerCase();
            final filtered = patients.where((p) =>
                p.name.toLowerCase().contains(query) ||
                p.email.toLowerCase().contains(query) ||
                p.shortCode.toLowerCase().contains(query));

            return filtered.map((p) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(p.name),
                  subtitle: Text('${p.email} • ID: ${p.shortCode}'),
                  onTap: () {
                    setState(() {
                      _chosenPatient = p;
                      controller.closeView(p.name);
                    });
                  },
                ));
          },
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error loading patients: $e'),
    );
  }

  Widget _inputField(BuildContext context,
      {required String label, required IconData icon, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencySelector(BuildContext context) {
    final theme = Theme.of(context);
    final options = ['Once a day', 'Twice a day', 'Thrice a day', 'Custom'];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.5,
      children: List.generate(options.length, (index) {
        final isSelected = _selectedFreqIndex == index;
        return InkWell(
          onTap: () {
            setState(() {
              _selectedFreqIndex = index;
              _updateTimeLists(index + 1);
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                options[index],
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  void _updateTimeLists(int count) {
    // count is 1-based. 4 means Custom.
    final List<TimeOfDay> defaults = [
      const TimeOfDay(hour: 8, minute: 0),
      const TimeOfDay(hour: 14, minute: 0),
      const TimeOfDay(hour: 20, minute: 0),
    ];
    final List<String> slots = [
      'before_breakfast',
      'after_lunch',
      'before_dinner',
    ];

    if (count <= 3) {
      _times.clear();
      _slotsPerTime.clear();
      for (int i = 0; i < count; i++) {
        _times.add(defaults[i]);
        _slotsPerTime.add(slots[i]);
      }
    } else {
      // Custom mode: start with 1 entry if empty
      if (_times.isEmpty) {
        _times.add(defaults[0]);
        _slotsPerTime.add(slots[0]);
      }
    }
  }

  Widget _buildTimeSlotRow(int index) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _times[index],
                );
                if (picked != null) setState(() => _times[index] = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.access_time_rounded, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _times[index].format(context),
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: DropdownButtonFormField<String>(
              initialValue: _slotsPerTime[index],
              isExpanded: true,
              dropdownColor: theme.colorScheme.surface,
              decoration: _inputDecoration(context, 'Slot', Icons.tag).copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                prefixIcon: null, // Remove icon to save space
              ),
              items: _slotLabels.entries.map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, style: const TextStyle(fontSize: 12)),
              )).toList(),
              onChanged: (v) => setState(() => _slotsPerTime[index] = v!),
            ),
          ),
          if (_selectedFreqIndex == 3 || _times.length > 1) 
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.redAccent),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                if (_times.length > 1) {
                  setState(() {
                    _times.removeAt(index);
                    _slotsPerTime.removeAt(index);
                  });
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _textField(BuildContext context, TextEditingController ctrl, String label, IconData icon) {
    final theme = Theme.of(context);
    return TextField(
      controller: ctrl,
      style: theme.textTheme.bodyLarge,
      decoration: _inputDecoration(context, label, icon),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String label, IconData icon) {
    final theme = Theme.of(context);
    return InputDecoration(
      prefixIcon: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      labelText: label,
      labelStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
    );
  }

  Widget _datePicker(BuildContext context, String label, DateTime date, Function(DateTime) onPick) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (d != null) onPick(d);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}/${date.month}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_chosenPatient == null ||
        _times.isEmpty ||
        _selectedMedicine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient, times, and medicine.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseServiceProvider).client;
      final doctor = ref.read(currentUserProfileProvider).value;
      if (client == null || doctor == null) return;

      final uuid = ref.read(uuidProvider);

      // 1. Create Prescription parent
      final prescriptionId = uuid.v4();
      await client.from('prescriptions').insert({
        'id': prescriptionId,
        'doctor_id': doctor.id,
        'title': _titleCtrl.text.isEmpty ? 'New Prescription' : _titleCtrl.text,
        'notes': _notesCtrl.text,
      });

      // 2. Create Prescription Item
      final itemId = uuid.v4();
      await client.from('prescription_items').insert({
        'id': itemId,
        'prescription_id': prescriptionId,
        'medicine_name': _selectedMedicine!.medicineName,
        'dosage_type': _dosageType, // Use the selected dosage type
        'frequency_config': {
          'days': _selectedDays,
          'times_per_day': _times.length,
          'custom_times': _times.map((t) => '${t.hour}:${t.minute}').toList(),
        },
        'duration_start': _startDate.toIso8601String(),
        'duration_end': _endDate.toIso8601String(),
        'meal_config': {'slots': _slotsPerTime},
        'inventory_item_id': _selectedMedicine!.id,
        'prescribed_quantity': int.tryParse(_prescribedQtyCtrl.text) ?? 30,
        'price_per_unit': _selectedMedicine!.pricePerUnit,
      });

      // 3. Link patient
      await client.from('patient_prescriptions').insert({
        'id': uuid.v4(),
        'prescription_id': prescriptionId,
        'patient_id': _chosenPatient!.id,
        'status': 'pending',
      });



      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescriptions sent successfully!')),
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
