/// Compile-time and runtime flags for pilot vs production behavior.
class RemoteFlags {
  /// When true, Paystack/paywall flow can block after the freemium cap.
  ///
  /// **Store releases (Play / App Store):** leave `false` (default). No upgrade
  /// UI is shown and customer limits are not enforced. Billing code stays in the
  /// repo for a later release with native IAP / Play Billing.
  ///
  /// **Direct APK / sideload:** set `--dart-define=REMOTE_PAYWALL=true` when
  /// Paystack is configured.
  static const paywallEnabled =
      bool.fromEnvironment('REMOTE_PAYWALL', defaultValue: false);
}
