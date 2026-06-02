import 'package:flutter/material.dart';

import '../../data/billing/subscription_service.dart';

/// Unused on web; satisfies conditional import.
class PaystackCheckoutWebView extends StatelessWidget {
  const PaystackCheckoutWebView({
    super.key,
    required this.authorizationUrl,
    required this.reference,
    required this.subscriptions,
  });

  final String authorizationUrl;
  final String reference;
  final SubscriptionService subscriptions;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
