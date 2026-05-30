import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/glass_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../models/app_user.dart';
import '../../../services/auth_service.dart';
import '../../../providers/app_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  
  bool _isLogin = true;
  UserRole _selectedRole = UserRole.patient;
  String? _error;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SizedBox.expand(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: GlassCard(
                borderRadius: 24,
                padding: const EdgeInsets.all(32),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.medication_liquid, size: 64, color: theme.colorScheme.primary)
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .scale(delay: 200.ms),
                      const SizedBox(height: 16),
                      Text(
                        'Medialert',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin ? 'Welcome Back' : 'Join the Platform',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 32),
                      if (!_isLogin) 
                        _textField(_name, 'Full Name', Icons.person)
                            .animate().fadeIn().moveY(begin: 10, end: 0),
                      const SizedBox(height: 16),
                      _textField(_email, 'Email Address', Icons.email),
                      const SizedBox(height: 16),
                      _textField(_password, 'Password', Icons.lock, obscure: true),
                      if (!_isLogin) ...[
                        const SizedBox(height: 24),
                        Text('I am a:', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        SegmentedButton<UserRole>(
                          style: SegmentedButton.styleFrom(
                            backgroundColor: theme.colorScheme.surface,
                            selectedBackgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                            selectedForegroundColor: theme.colorScheme.primary,
                          ),
                          segments: const [
                            ButtonSegment(value: UserRole.patient, label: Text('Patient')),
                            ButtonSegment(value: UserRole.doctor, label: Text('Doctor')),
                          ],
                          selected: {_selectedRole},
                          onSelectionChanged: (val) => setState(() => _selectedRole = val.first),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: 32),
                      if (_isLoading)
                        CircularProgressIndicator(color: theme.colorScheme.primary)
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () => _handleSubmit(authService),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(_isLogin ? 'Sign In' : 'Create Account', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => setState(() => _isLogin = !_isLogin),
                        child: Text(
                          _isLogin ? "Don't have an account? Sign Up" : "Already have an account? Sign In",
                          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    );
  }

  Widget _textField(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        labelText: label,
        labelStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2))),
      ),
    );
  }

  Future<void> _handleSubmit(AuthService authService) async {
    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        await authService.signInWithEmail(_email.text.trim(), _password.text.trim());
      } else {
        await authService.signUpWithEmail(
          email: _email.text.trim(),
          password: _password.text.trim(),
          name: _name.text.trim(),
          role: _selectedRole.name,
        );
        ref.invalidate(currentUserProfileProvider);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
