/// Normalizes Nigerian-style phone numbers for search and wa.me links.
String normalizePhoneDigits(String? raw) {
  if (raw == null) return '';
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('234') && digits.length >= 12) {
    return digits;
  }
  if (digits.startsWith('0') && digits.length == 11) {
    return '234${digits.substring(1)}';
  }
  if (digits.length == 10 && !digits.startsWith('0')) {
    return '234$digits';
  }
  return digits;
}
