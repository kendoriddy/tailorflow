import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerFeedbackRemote {
  CustomerFeedbackRemote._();

  static Future<bool> trySubmit({
    required String customerId,
    required String customerName,
    required String? orderId,
    required String? orderTitle,
    required int rating,
    required String? comment,
    required int birthDay,
    required int birthMonth,
    int? birthYear,
    required bool birthdayConsent,
    required String platform,
    String? appVersion,
  }) async {
    SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      return false;
    }
    final user = client.auth.currentUser;
    if (user == null) return false;

    final summary = StringBuffer()
      ..writeln('Customer feedback captured from delivery follow-up.')
      ..writeln('Customer ID: $customerId')
      ..writeln('Customer: $customerName')
      ..writeln('Order ID: ${orderId ?? '-'}')
      ..writeln('Order: ${orderTitle ?? '-'}')
      ..writeln('Rating: $rating/5')
      ..writeln('Birthday: $birthDay/$birthMonth/${birthYear ?? '(year omitted)'}')
      ..writeln('Birthday offers consent: ${birthdayConsent ? 'yes' : 'no'}')
      ..writeln('Comment: ${comment?.trim().isNotEmpty == true ? comment!.trim() : '-'}');

    try {
      await client.from('app_feedback').insert(<String, dynamic>{
        'category': 'customer_feedback',
        'subject': '[TailorFlow NG] Customer Feedback $rating/5',
        'message': comment?.trim().isNotEmpty == true
            ? comment!.trim()
            : 'No additional comment',
        'body_context': summary.toString(),
        if (appVersion != null && appVersion.isNotEmpty) 'app_version': appVersion,
        'platform': platform,
      });
      return true;
    } catch (e, st) {
      debugPrint('TailorFlow customer feedback insert failed: $e\n$st');
      return false;
    }
  }
}
