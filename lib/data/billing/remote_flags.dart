/// Compile-time and runtime flags for pilot vs production behavior.
class RemoteFlags {
  /// When true, Paystack/paywall flow can block after the freemium cap.
  static const paywallEnabled =
      bool.fromEnvironment('REMOTE_PAYWALL', defaultValue: false);
}
