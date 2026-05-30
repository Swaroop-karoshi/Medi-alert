import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class SyncService {
  SyncService(this._supabase);

  static const _boxName = 'pending_sync_v2';

  final SupabaseService _supabase;
  late Box<Map> _syncBox;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _syncBox = await Hive.openBox<Map>(_boxName);
    _initialized = true;
  }

  Future<void> upsertMedicineLog({
    required String logId,
    required String patientId,
    required String prescriptionItemId,
    required DateTime scheduledTime,
    required String status,
    DateTime? takenTime,
  }) async {
    if (!_initialized) {
      await init();
    }

    final operation = <String, dynamic>{
      'kind': 'upsert_log',
      'log_id': logId,
      'payload': <String, dynamic>{
        'id': logId,
        'patient_id': patientId,
        'prescription_item_id': prescriptionItemId,
        'scheduled_time': scheduledTime.toUtc().toIso8601String(),
        'status': status,
        'taken_time': takenTime?.toUtc().toIso8601String(),
        'deviation_minutes': takenTime?.difference(scheduledTime).inMinutes,
      },
    };

    await _syncBox.put(logId, operation);
    await _executeOperation(operation, removeOnSuccess: true);
  }

  Future<void> syncPending() async {
    if (!_initialized) {
      await init();
    }
    if (_syncBox.isEmpty) return;

    for (final key in _syncBox.keys) {
      final raw = _syncBox.get(key);
      if (raw == null) {
        continue;
      }
      final operation = Map<String, dynamic>.from(raw);
      final success = await _executeOperation(
        operation,
        removeOnSuccess: false,
      );
      if (!success) {
        break;
      }
      await _syncBox.delete(key);
    }
  }

  Future<bool> _executeOperation(
    Map<String, dynamic> operation, {
    required bool removeOnSuccess,
  }) async {
    final client = _supabase.client;
    if (client == null) return false;

    try {
      final kind = operation['kind'] as String? ?? '';
      if (kind != 'upsert_log') return true;

      final payload = Map<String, dynamic>.from(operation['payload'] as Map);
      await client.from('medicine_logs').upsert(payload, onConflict: 'id');
      if (removeOnSuccess) {
        await _syncBox.delete(operation['log_id']);
      }
      return true;
    } on PostgrestException catch (e) {
      debugPrint('Sync failed (Postgrest): ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Sync failed: $e');
      return false;
    }
  }

  bool get hasPending => _initialized && _syncBox.isNotEmpty;
}
