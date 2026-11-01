import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers.dart';
import '../theme/app_theme.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _signUp = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final repo = ref.read(repoProvider);
      if (_signUp) {
        final hasSession = await repo.signUp(
            _email.text.trim(), _password.text, _name.text.trim());
        if (!hasSession) {
          messenger.showSnackBar(const SnackBar(
              content: Text('Te enviamos un correo para confirmar tu cuenta.')));
        }
      } else {
        await repo.signIn(_email.text.trim(), _password.text);
      }
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.record_voice_over,
                    size: 56, color: AppColors.primary),
                const SizedBox(height: 16),
                Text('SpeakRead Pro',
                    textAlign: TextAlign.center,
                    style: text.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Inglés profesional leyendo en voz alta',
                    textAlign: TextAlign.center, style: text.bodyLarge),
                const SizedBox(height: 32),
                if (_signUp) ...[
                  TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                          labelText: 'Tu nombre',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                      labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                      labelText: 'Contraseña (mínimo 6 caracteres)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_signUp ? 'Crear cuenta' : 'Entrar'),
                ),
                TextButton(
                  onPressed: () => setState(() => _signUp = !_signUp),
                  child: Text(_signUp
                      ? '¿Ya tenés cuenta? Entrá'
                      : '¿Primera vez? Creá tu cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
