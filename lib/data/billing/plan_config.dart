/// Subscription / freemium limits (defaults; admin overrides via Supabase).
class PlanConfig {
  const PlanConfig({
    required this.freeMaxActiveCustomers,
    required this.freeWhatsAppMonthlyLimit,
  });

  /// Active customers allowed on the free tier before paywall.
  final int freeMaxActiveCustomers;

  /// WhatsApp handoffs per calendar month on free tier.
  /// `-1` means unlimited for free users.
  final int freeWhatsAppMonthlyLimit;

  static const defaults = PlanConfig(
    freeMaxActiveCustomers: 50,
    freeWhatsAppMonthlyLimit: 10,
  );

  bool get freeWhatsAppUnlimited => freeWhatsAppMonthlyLimit < 0;

  PlanConfig copyWith({
    int? freeMaxActiveCustomers,
    int? freeWhatsAppMonthlyLimit,
  }) {
    return PlanConfig(
      freeMaxActiveCustomers:
          freeMaxActiveCustomers ?? this.freeMaxActiveCustomers,
      freeWhatsAppMonthlyLimit:
          freeWhatsAppMonthlyLimit ?? this.freeWhatsAppMonthlyLimit,
    );
  }

  static PlanConfig fromJson(Map<String, dynamic> json) {
    return PlanConfig(
      freeMaxActiveCustomers: _parseInt(
        json['freeMaxActiveCustomers'],
        defaults.freeMaxActiveCustomers,
      ),
      freeWhatsAppMonthlyLimit: _parseInt(
        json['freeWhatsAppMonthlyLimit'],
        defaults.freeWhatsAppMonthlyLimit,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'freeMaxActiveCustomers': freeMaxActiveCustomers,
        'freeWhatsAppMonthlyLimit': freeWhatsAppMonthlyLimit,
      };

  static int _parseInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

/// Keys in Supabase `platform_config` (and cached locally).
abstract final class PlanConfigKeys {
  static const freeMaxActiveCustomers = 'free_tier_max_customers';
  static const freeWhatsAppMonthlyLimit = 'free_tier_whatsapp_monthly_limit';
}
