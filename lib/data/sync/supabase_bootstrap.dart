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
  final client = Supabase.instance.client;

  // Ensures the signed-in user has a shop + membership row for shop-scoped RLS.
  if (client.auth.currentSession == null) {
    if (kDebugMode) {
      debugPrint(
        'TailorFlow: Supabase configured but no signed-in user yet.',
      );
    }
    return;
  }

  try {
    await client.rpc('bootstrap_current_user_shop');
  } catch (e) {
    if (kDebugMode) {
      debugPrint(
        'TailorFlow: could not bootstrap user shop mapping. '
        'Run latest SQL migration. Error: $e',
      );
    }
  }
}
