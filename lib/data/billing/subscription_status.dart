import 'subscription_pricing.dart';

class ShopSubscriptionStatus {
  const ShopSubscriptionStatus({
    required this.isActive,
    required this.status,
    this.plan,
    this.periodEnd,
  });

  final bool isActive;
  final String status;
  final SubscriptionPlan? plan;
  final DateTime? periodEnd;

  static const inactive = ShopSubscriptionStatus(
    isActive: false,
    status: 'free',
  );
}
