import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, SupabaseClient, User;
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/doctor_inventory_item.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';

final uuidProvider = Provider((ref) => Uuid());

final supabaseReadyProvider = StateProvider<bool>((ref) => false);

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  final ready = ref.watch(supabaseReadyProvider);
  return ready ? Supabase.instance.client : null;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(ref.watch(supabaseClientProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(ref.watch(notificationServiceProvider));
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(supabaseServiceProvider));
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

final currentUserProfileProvider = FutureProvider<AppUser?>((ref) async {
  final uUser = ref.watch(authStateProvider).value;
  if (uUser == null) return null;

  final supabase = ref.watch(supabaseServiceProvider);
  final rows = await supabase.fetchRows(
    'profiles',
    column: 'id',
    value: uUser.id,
  );
  if (rows.isNotEmpty) {
    return AppUser.fromMap(rows.first);
  }
  return null;
});

/// Increment this to force re-fetch of daily logs and other dependent providers.
final refreshTriggerProvider = StateProvider<int>((ref) => 0);

final patientSearchQueryProvider = StateProvider<String>((ref) => '');

final searchedPatientsProvider = FutureProvider<List<AppUser>>((ref) async {
  final query = ref.watch(patientSearchQueryProvider);
  final supabase = ref.watch(supabaseServiceProvider);
  final client = supabase.client;
  if (client == null) return [];

  var request = client.from('profiles').select().eq('role', 'patient');

  if (query.isNotEmpty) {
    request = request.or(
      'name.ilike.%$query%,email.ilike.%$query%,short_code.ilike.%$query%',
    );
  }

  final data = await request.limit(20);
  return List<Map<String, dynamic>>.from(data).map(AppUser.fromMap).toList();
});

final pendingInvitesProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return Stream.value([]);

  final supabase = ref.watch(supabaseServiceProvider);
  final client = supabase.client;
  if (client == null) return Stream.value([]);

  return client.from('doctor_patient_invites').stream(primaryKey: ['id']);
});

final enhancedPendingInvitesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final user = ref.watch(currentUserProfileProvider).value;
      if (user == null) return [];

      final rawInvites = ref.watch(pendingInvitesProvider).value ?? [];
      if (rawInvites.isEmpty) return [];

      final pending = rawInvites.where((i) {
        if (i['status'] != 'pending') return false;
        final invitePatientId = i['patient_id'] as String?;
        final inviteEmail = i['patient_email'] as String?;
        return invitePatientId == user.id || inviteEmail == user.email;
      }).toList();
      if (pending.isEmpty) return [];

      final supabase = ref.watch(supabaseServiceProvider);
      final client = supabase.client;
      if (client == null) return [];

      final List<Map<String, dynamic>> enhanced = [];
      for (final invite in pending) {
        final doctorData = await client
            .from('profiles')
            .select()
            .eq('id', invite['doctor_id'])
            .single();
        enhanced.add({...invite, 'profiles': doctorData});
      }
      return enhanced;
    });

final patientMealTimesProvider = FutureProvider<Map<String, String>?>((
  ref,
) async {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return null;

  final supabase = ref.watch(supabaseServiceProvider);
  final client = supabase.client;
  if (client == null) return null;

  try {
    final data = await client
        .from('meal_times')
        .select()
        .eq('patient_id', user.id)
        .single();
    return Map<String, String>.from(data);
  } catch (_) {
    return null;
  }
});

final pendingPrescriptionsProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) {
    final user = ref.watch(currentUserProfileProvider).value;
    if (user == null) return Stream.value([]);

    final supabase = ref.watch(supabaseServiceProvider);
    final client = supabase.client;
    if (client == null) return Stream.value([]);

    return client.from('patient_prescriptions').stream(primaryKey: ['id']);
  },
);

final enhancedPendingPrescriptionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final user = ref.watch(currentUserProfileProvider).value;
      if (user == null) return [];

      final rawPrescriptions =
          ref.watch(pendingPrescriptionsProvider).value ?? [];
      if (rawPrescriptions.isEmpty) return [];

      final pending = rawPrescriptions
          .where((p) => p['status'] == 'pending' && p['patient_id'] == user.id)
          .toList();
      if (pending.isEmpty) return [];

      final supabase = ref.watch(supabaseServiceProvider);
      final client = supabase.client;
      if (client == null) return [];

      final List<Map<String, dynamic>> enhanced = [];
      for (final link in pending) {
        final pData = await client
            .from('prescriptions')
            .select('*, profiles:doctor_id(*), prescription_items(*)')
            .eq('id', link['prescription_id'])
            .single();
        enhanced.add({...link, 'prescriptions': pData});
      }
      return enhanced;
    });

final enhancedApprovedPrescriptionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final user = ref.watch(currentUserProfileProvider).value;
      if (user == null) return [];

      final rawPrescriptions =
          ref.watch(pendingPrescriptionsProvider).value ?? [];
      if (rawPrescriptions.isEmpty) return [];

      final approved = rawPrescriptions
          .where((p) => p['status'] == 'accepted' && p['patient_id'] == user.id)
          .toList();
      if (approved.isEmpty) return [];

      final supabase = ref.watch(supabaseServiceProvider);
      final client = supabase.client;
      if (client == null) return [];

      final List<Map<String, dynamic>> enhanced = [];
      for (final link in approved) {
        final pData = await client
            .from('prescriptions')
            .select('*, profiles:doctor_id(*), prescription_items(*)')
            .eq('id', link['prescription_id'])
            .single();
        enhanced.add({...link, 'prescriptions': pData});
      }
      return enhanced;
    });

final dailyLogsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return Stream.value([]);

  final supabase = ref.watch(supabaseServiceProvider);
  final client = supabase.client;
  if (client == null) return Stream.value([]);

  return client
      .from('medicine_logs')
      .stream(primaryKey: ['id'])
      .eq('patient_id', user.id);
});

final enhancedDailyLogsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  // Watch the refresh trigger so we re-fetch when it changes
  ref.watch(refreshTriggerProvider);

  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return [];

  final rawLogs = ref.watch(dailyLogsProvider).value ?? [];
  if (rawLogs.isEmpty) return [];

  final supabase = ref.watch(supabaseServiceProvider);
  final client = supabase.client;
  if (client == null) return [];

  final today = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);
  final endOfToday = DateTime(today.year, today.month, today.day, 23, 59, 59);

  final todayLogs = rawLogs.where((l) {
    if (l['patient_id'] != user.id) return false;
    final ts = DateTime.parse(l['scheduled_time']).toLocal();
    return ts.isAfter(startOfToday.subtract(const Duration(seconds: 1))) &&
        ts.isBefore(endOfToday.add(const Duration(seconds: 1)));
  }).toList();

  final List<String> itemIds = todayLogs
      .map((l) => l['prescription_item_id'] as String)
      .toSet()
      .toList();
  if (itemIds.isEmpty) return [];

  // Fetch items joined with prescriptions and doctor profiles
  final itemsData = await client
      .from('prescription_items')
      .select('*, prescriptions(*, profiles:doctor_id(*))')
      .inFilter('id', itemIds);

  final Map<String, dynamic> itemsMap = {
    for (var item in itemsData) item['id']: item,
  };

  final List<Map<String, dynamic>> enhanced = [];
  for (final log in todayLogs) {
    final item = itemsMap[log['prescription_item_id']];
    if (item != null) {
      enhanced.add({
        ...log,
        'prescription_items': item,
      });
    }
  }

  enhanced.sort((a, b) {
    final tA = DateTime.parse(a['scheduled_time']);
    final tB = DateTime.parse(b['scheduled_time']);
    return tA.compareTo(tB);
  });

  return enhanced;
});

final adherenceReportProvider = FutureProvider<Map<String, int>>((ref) async {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return {'taken': 0, 'missed': 0, 'skipped': 0, 'denied': 0};

  final supabase = ref.watch(supabaseServiceProvider);
  final client = supabase.client;
  if (client == null) return {'taken': 0, 'missed': 0, 'skipped': 0, 'denied': 0};

  final data = await client
      .from('medicine_logs')
      .select('status,scheduled_time')
      .eq('patient_id', user.id);
  final List logs = List.from(data);
  final now = DateTime.now();
  final dueLogs = logs.where((l) {
    final scheduled = DateTime.tryParse(l['scheduled_time'] as String? ?? '');
    return scheduled != null && !scheduled.isAfter(now);
  }).toList();

  int taken = dueLogs.where((l) => l['status'] == 'taken').length;
  int missed = dueLogs.where((l) => l['status'] == 'missed').length;
  int skipped = dueLogs.where((l) => l['status'] == 'skipped').length;
  int denied = dueLogs.where((l) => l['status'] == 'denied').length;

  return {'taken': taken, 'missed': missed, 'skipped': skipped, 'denied': denied};
});

/// Adherence report for a specific patient — used by the doctor.
final patientAdherenceReportProvider =
    FutureProvider.family<Map<String, int>, String>((ref, patientId) async {
      final supabase = ref.watch(supabaseServiceProvider);
      final client = supabase.client;
      if (client == null) return {'taken': 0, 'missed': 0, 'skipped': 0, 'denied': 0};

      final data = await client
          .from('medicine_logs')
          .select('status,scheduled_time')
          .eq('patient_id', patientId);
      final List logs = List.from(data);
      final now = DateTime.now();
      final dueLogs = logs.where((l) {
        final scheduled = DateTime.tryParse(l['scheduled_time'] as String? ?? '');
        return scheduled != null && !scheduled.isAfter(now);
      }).toList();

      int taken = dueLogs.where((l) => l['status'] == 'taken').length;
      int missed = dueLogs.where((l) => l['status'] == 'missed').length;
      int skipped = dueLogs.where((l) => l['status'] == 'skipped').length;
      int denied = dueLogs.where((l) => l['status'] == 'denied').length;

      return {'taken': taken, 'missed': missed, 'skipped': skipped, 'denied': denied};
    });

/// Daily chart data for a specific patient — used by the doctor.
final patientDailyChartDataProvider =
    FutureProvider.family<List<Map<String, double>>, String>((ref, patientId) async {
      final supabase = ref.watch(supabaseServiceProvider);
      final client = supabase.client;
      if (client == null) return List.generate(7, (_) => {'taken': 0, 'missed': 0, 'skipped': 0, 'denied': 0});

      final sevenDaysAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String();

      final data = await client
          .from('medicine_logs')
          .select('scheduled_time, status')
          .eq('patient_id', patientId)
          .gte('scheduled_time', sevenDaysAgo);

      final List logs = List.from(data);
      final now = DateTime.now();

      return List.generate(7, (i) {
        final day = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: 6 - i));
        final dayLogs = logs.where((l) {
          final ts = DateTime.parse(l['scheduled_time']);
          return ts.year == day.year && ts.month == day.month && ts.day == day.day;
        });
        return {
          'taken': dayLogs.where((l) => l['status'] == 'taken').length.toDouble(),
          'missed': dayLogs.where((l) => l['status'] == 'missed').length.toDouble(),
          'skipped': dayLogs.where((l) => l['status'] == 'skipped').length.toDouble(),
          'denied': dayLogs.where((l) => l['status'] == 'denied').length.toDouble(),
        };
      });
    });

final dailyChartDataProvider = FutureProvider<List<Map<String, double>>>((ref) async {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return List.generate(7, (_) => {'taken': 0, 'missed': 0, 'skipped': 0, 'denied': 0});

  final supabase = ref.watch(supabaseServiceProvider);
  final client = supabase.client;
  if (client == null) return List.generate(7, (_) => {'taken': 0, 'missed': 0, 'skipped': 0, 'denied': 0});

  final sevenDaysAgo = DateTime.now()
      .subtract(const Duration(days: 7))
      .toIso8601String();

  final data = await client
      .from('medicine_logs')
      .select('scheduled_time, status')
      .eq('patient_id', user.id)
      .gte('scheduled_time', sevenDaysAgo);

  final List logs = List.from(data);
  final now = DateTime.now();

  return List.generate(7, (i) {
    final day = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: 6 - i));
    final dayLogs = logs.where((l) {
      final ts = DateTime.parse(l['scheduled_time']);
      return ts.year == day.year && ts.month == day.month && ts.day == day.day;
    });
    return {
      'taken': dayLogs.where((l) => l['status'] == 'taken').length.toDouble(),
      'missed': dayLogs.where((l) => l['status'] == 'missed').length.toDouble(),
      'skipped': dayLogs.where((l) => l['status'] == 'skipped').length.toDouble(),
      'denied': dayLogs.where((l) => l['status'] == 'denied').length.toDouble(),
    };
  });
});

final doctorPatientsProvider = FutureProvider<List<AppUser>>((ref) async {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null || user.role != UserRole.doctor) return [];

  final supabase = ref.watch(supabaseServiceProvider);
  final mappings = await supabase.fetchRows(
    'doctor_patient_map',
    column: 'doctor_id',
    value: user.id,
  );

  final List<AppUser> patients = [];
  for (final map in mappings) {
    final patientRows = await supabase.fetchRows(
      'profiles',
      column: 'id',
      value: map['patient_id'],
    );
    if (patientRows.isNotEmpty) {
      patients.add(AppUser.fromMap(patientRows.first));
    }
  }
  return patients;
});

final allPrescriptionItemsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return [];

  final supabase = ref.watch(supabaseServiceProvider);
  final client = supabase.client;
  if (client == null) return [];

  // If doctor, fetch all medicines they've prescribed. If patient, fetch all prescribed to them.
  final isDoctor = user.role == UserRole.doctor;
  if (isDoctor) {
    final prescriptions = await client
        .from('prescriptions')
        .select('id')
        .eq('doctor_id', user.id);
    final pIds = List.from(prescriptions).map((p) => p['id']).toList();
    final data = await client
        .from('prescription_items')
        .select()
        .inFilter('prescription_id', pIds);
    return List<Map<String, dynamic>>.from(data);
  } else {
    final prescriptions = await client
        .from('patient_prescriptions')
        .select('prescription_id')
        .eq('patient_id', user.id)
        .eq('status', 'accepted');
    final pIds = List.from(
      prescriptions,
    ).map((p) => p['prescription_id']).toList();
    
    if (pIds.isEmpty) return [];

    final data = await client
        .from('prescription_items')
        .select()
        .inFilter('prescription_id', pIds);
        
    final items = List<Map<String, dynamic>>.from(data);
    
    // Calculate remaining tablets exactly
    final takenLogs = await client
        .from('medicine_logs')
        .select('prescription_item_id')
        .eq('patient_id', user.id)
        .eq('status', 'taken');
        
    final Map<String, int> takenCounts = {};
    for (var log in takenLogs as List<dynamic>) {
      final id = log['prescription_item_id'] as String;
      takenCounts[id] = (takenCounts[id] ?? 0) + 1;
    }
    
    for (var item in items) {
      final prescribed = item['prescribed_quantity'] as int? ?? 0;
      final taken = takenCounts[item['id']] ?? 0;
      item['tablets_left'] = (prescribed - taken).clamp(0, 99999);
    }
    
    return items;
  }
});

final logsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return [];

  final supabase = ref.watch(supabaseServiceProvider);
  final client = supabase.client;
  if (client == null) return [];

  final data = await client
      .from('medicine_logs')
      .select('*, prescription_items(*)')
      .eq('patient_id', user.id)
      .order('scheduled_time', ascending: false);
  return List<Map<String, dynamic>>.from(data);
});

/// Increment to force inventory re-fetch after an update.
final inventoryRefreshProvider = StateProvider<int>((ref) => 0);

/// Fetches full inventory for the logged-in doctor.
final doctorInventoryProvider =
    FutureProvider<List<DoctorInventoryItem>>((ref) async {
  ref.watch(inventoryRefreshProvider);

  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null || user.role != UserRole.doctor) return [];

  final supabase = ref.watch(supabaseServiceProvider);
  final client = supabase.client;
  if (client == null) return [];

  final data = await client
      .from('doctor_inventory')
      .select()
      .eq('doctor_id', user.id)
      .order('medicine_name', ascending: true);

  return List<Map<String, dynamic>>.from(data)
      .map(DoctorInventoryItem.fromMap)
      .toList();
});

/// For the doctor: alerts for any of their own stock that is ≤ low_stock_threshold.
final doctorLowStockAlertsProvider =
    FutureProvider<List<DoctorInventoryItem>>((ref) async {
  final inventory = await ref.watch(doctorInventoryProvider.future);
  
  final List<DoctorInventoryItem> lowStock = 
      inventory.where((item) => item.isLowStock).toList();

  // Sort most critical first
  lowStock.sort((a, b) => a.currentQuantity.compareTo(b.currentQuantity));

  return lowStock;
});

final patientLowStockAlertsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final items = await ref.watch(allPrescriptionItemsProvider.future);
  return items.where((i) => (i['tablets_left'] as int? ?? 0) <= 5).toList();
});

Future<void> initializeBackends(WidgetRef ref) async {
  debugPrint('Initializing Supabase...');
  try {
    const url = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://pjaskxfemihrqijpqgnw.supabase.co',
    );
    const anon = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBqYXNreGZlbWlocnFpanBxZ253Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzMTQ3OTYsImV4cCI6MjA5MTg5MDc5Nn0.I4YY-AaUq34n2FM76sejFv8M4QvJyddAE8RmTn2ws58',
    );

    await Supabase.initialize(url: url, anonKey: anon);
    debugPrint('Supabase initialized successfully');
    ref.read(supabaseReadyProvider.notifier).state = true;
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
    ref.read(supabaseReadyProvider.notifier).state = false;
  }
}
