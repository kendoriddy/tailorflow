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

  /// Public privacy policy (Play Store + in-app Settings). Keep in sync with `siteUrl` in
  /// `website/site-config.js`.
  static const String privacyPolicyUrl =
      'https://tailorflow.kennyonifade.com/privacy.html';

  /// Contact for privacy / data requests (also shown on the website policy).
  static const String privacyContactEmail = 'onifkay@gmail.com';

  /// Inbox for in-app feedback when Supabase is unavailable (mailto fallback).
  static const String feedbackEmail = privacyContactEmail;
}
