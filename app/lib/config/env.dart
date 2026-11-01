/// Configuración leída al compilar con:
///   flutter run --dart-define-from-file=env.json
/// Nunca pongas aquí claves de Azure u OpenAI: esas viven en Supabase.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
