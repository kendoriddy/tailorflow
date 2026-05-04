import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists feedback to Supabase when the project is configured and the user is signed in.
class FeedbackRemote {
  FeedbackRemote._();

  /// Returns true if a row was inserted.
  static Future<bool> trySubmit({
    required String category,
    required String subject,
    required String message,
    required String bodyContext,
    String? appVersion,
    String? platform,
  }) async {
    SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      return false;
    }

    if (client.auth.currentUser == null) return false;

    try {
      await client.from('app_feedback').insert(<String, dynamic>{
        'category': category,
        'subject': subject,
        'message': message,
        'body_context': bodyContext,
        if (appVersion != null && appVersion.isNotEmpty)
          'app_version': appVersion,
        if (platform != null && platform.isNotEmpty) 'platform': platform,
      });
      return true;
    } catch (e, st) {
      debugPrint('TailorFlow feedback insert failed: $e\n$st');
      return false;
    }
  }
}
