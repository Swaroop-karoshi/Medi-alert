import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService(this._client);

  final SupabaseClient? _client;

  SupabaseClient? get client => _client;

  bool get isConfigured => _client != null;

  Future<List<Map<String, dynamic>>> fetchRows(
    String table, {
    String? column,
    dynamic value,
  }) async {
    if (_client == null) return [];
    dynamic query = _client.from(table).select();
    if (column != null) query = query.eq(column, value);
    final data = await query;
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> upsert(String table, Map<String, dynamic> data) async {
    if (_client == null) return;
    await _client.from(table).upsert(data);
  }

  Future<void> insert(String table, Map<String, dynamic> data) async {
    if (_client == null) return;
    await _client.from(table).insert(data);
  }

  Future<void> deleteById(String table, String id) async {
    if (_client == null) return;
    await _client.from(table).delete().eq('id', id);
  }
}
