import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/phone.dart';

Future<bool> openWhatsAppText({
  required String? rawPhone,
  required String message,
}) async {
  final digits = normalizePhoneDigits(rawPhone);
  if (digits.isEmpty) {
    debugPrint('TailorFlow: missing phone for WhatsApp launch');
    return false;
  }
  final uri = Uri.parse(
    'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
  );
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
