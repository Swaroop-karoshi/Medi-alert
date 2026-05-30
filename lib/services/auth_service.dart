import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'background_service.dart';

class AuthService {
  AuthService(this._supabase);

  final SupabaseClient? _supabase;

  bool get isConfigured => _supabase != null;

  Stream<User?> authStateChanges() {
    if (_supabase == null) return const Stream.empty();
    return _supabase.auth.onAuthStateChange.map((event) => event.session?.user);
  }

  User? get currentUser => _supabase?.auth.currentUser;

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    if (_supabase == null) throw Exception('Supabase unavailable');
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    if (_supabase == null) throw Exception('Supabase unavailable');

    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );
    final user = response.user;

    if (user != null) {
      final shortCode = await _generateUniqueShortCode();
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'role': role,
        'short_code': shortCode,
      });
    }

    return response;
  }

  Future<String> _generateUniqueShortCode() async {
    if (_supabase == null) {
      throw Exception('Supabase unavailable');
    }
    final random = Random();

    for (var i = 0; i < 20; i++) {
      final code = List.generate(6, (_) => random.nextInt(10)).join();
      final exists = await _supabase
          .from('profiles')
          .select('id')
          .eq('short_code', code)
          .maybeSingle();
      if (exists == null) {
        return code;
      }
    }

    throw Exception('Could not generate unique short code');
  }

  Future<void> signOut() async {
    await BackgroundService.stop();
    await _supabase?.auth.signOut();
  }
}
