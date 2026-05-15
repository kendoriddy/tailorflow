/// User-facing product name and shared copy.
///
/// **Rename the product:** change [appName] here, then match `appName` in
/// `website/site-config.js`. See `docs/BRANDING.md`.
///
/// Package IDs (`tailorflow_ng`, `ng.tailorflow.*`) can stay until a new store listing.
class Brand {
  Brand._();

  static const String appName = 'TailorFlow';

  static const String tagline =
      'Offline-first app for tailoring shops — customers, orders, payments, and WhatsApp reminders.';

  /// Prefix for feedback email subjects and Supabase rows (easy inbox filtering).
  static const String feedbackSubjectPrefix = '[$appName]';
}
