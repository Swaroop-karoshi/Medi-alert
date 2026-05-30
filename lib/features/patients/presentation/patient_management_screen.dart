import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/glass_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../providers/app_providers.dart';
import '../../../widgets/async_value_widget.dart';
import '../../../models/app_user.dart';

class PatientManagementScreen extends ConsumerStatefulWidget {
  const PatientManagementScreen({super.key});

  @override
  ConsumerState<PatientManagementScreen> createState() =>
      _PatientManagementScreenState();
}

class _PatientManagementScreenState
    extends ConsumerState<PatientManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Patient Management',
          style: theme.textTheme.titleLarge,
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(text: 'Directory'),
            Tab(text: 'My Network'),
          ],
        ),
      ),
      body: SizedBox.expand(
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _DirectoryView(searchCtrl: _searchCtrl),
              _NetworkView(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectoryView extends ConsumerWidget {
  const _DirectoryView({required this.searchCtrl});
  final TextEditingController searchCtrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final patientsAsync = ref.watch(searchedPatientsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: GlassCard(
            borderRadius: 16,
            padding: EdgeInsets.zero,
            child: TextField(
              controller: searchCtrl,
              onChanged: (val) =>
                  ref.read(patientSearchQueryProvider.notifier).state = val,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search by name, email, or DOC_ID...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ),
        Expanded(
          child: AsyncValueWidget(
            value: patientsAsync,
            data: (patients) {
              if (patients.isEmpty) {
                return Center(
                  child: Text(
                    'No patients found.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: patients.length,
                itemBuilder: (context, i) {
                  final patient = patients[i];
                  return _PatientTile(patient: patient, isNetwork: false);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NetworkView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final networkAsync = ref.watch(doctorPatientsProvider);

    return AsyncValueWidget(
      value: networkAsync,
      data: (patients) {
        if (patients.isEmpty) {
          return Center(
            child: Text(
              'No linked patients yet.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: patients.length,
          itemBuilder: (context, i) {
            final patient = patients[i];
            return _PatientTile(patient: patient, isNetwork: true);
          },
        );
      },
    );
  }
}

class _PatientTile extends ConsumerStatefulWidget {
  const _PatientTile({required this.patient, required this.isNetwork});
  final AppUser patient;
  final bool isNetwork;

  @override
  ConsumerState<_PatientTile> createState() => _PatientTileState();
}

class _PatientTileState extends ConsumerState<_PatientTile> {
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderRadius: 16,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(Icons.person, color: theme.colorScheme.primary),
          ),
          title: Text(
            widget.patient.name,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${widget.patient.email} • ID: ${widget.patient.shortCode}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          trailing: widget.isNetwork
              ? const Icon(Icons.check_circle, color: Colors.green)
              : _isSending
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              : OutlinedButton(
                  onPressed: _sendInvite,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                    foregroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Invite', style: TextStyle(fontSize: 12)),
                ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }

  Future<void> _sendInvite() async {
    setState(() => _isSending = true);
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final doctor = ref.read(currentUserProfileProvider).value;
      if (doctor == null) return;

      await supabase.insert('doctor_patient_invites', {
        'doctor_id': doctor.id,
        'patient_id': widget.patient.id,
        'patient_email': widget.patient.email,
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invite sent to ${widget.patient.name}!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
