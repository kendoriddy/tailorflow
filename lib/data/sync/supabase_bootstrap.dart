import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initializes Supabase when URL and anon key are provided via `--dart-define`.
Future<void> initSupabaseIfConfigured() async {
  const url = String.fromEnvironment('SUPABASE_URL');
  const anon = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (url.isEmpty || anon.isEmpty) {
    if (kDebugMode) {
      debugPrint(
        'TailorFlow: Supabase not configured (optional). '
        'Set SUPABASE_URL and SUPABASE_ANON_KEY to enable cloud sync.',
      );
    }
    return;
  }
  await Supabase.initialize(url: url, anonKey: anon);
}
