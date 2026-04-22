import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/data_layer.dart';
import '../../data/billing/freemium_service.dart';
import '../../data/billing/remote_flags.dart';

/// Shown when freemium cap is hit and [RemoteFlags.paywallEnabled] is true.
///
/// Paystack wiring is intentionally stubbed: launch docs for integration.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key, required this.layer});

  final DataLayer layer;

  /// Returns true if the app may create another active customer.
  static Future<bool> ensureCanAddCustomer({
    required BuildContext context,
    required DataLayer layer,
  }) async {
    if (!RemoteFlags.paywallEnabled) return true;
    if (await layer.settings.isSubscribed()) return true;
    final count = await layer.freemium.activeCustomerCount();
    if (count < kFreemiumCustomerLimit) return true;
    if (!context.mounted) return false;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => PaywallScreen(layer: layer),
      ),
    );
    if (!context.mounted) return false;
    return await layer.settings.isSubscribed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade TailorFlow')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have reached the free limit (${kFreemiumCustomerLimit} active customers).',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Pilot builds can keep working by turning the paywall off at build time. '
              'Production will charge around ₦1,000–₦2,000/month via Paystack.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                final uri = Uri.parse('https://paystack.com/docs/payments/subscriptions');
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: const Text('Open Paystack subscription docs'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                await layer.settings.setSubscribed(true);
                if (context.mounted) Navigator.of(context).pop(true);
              },
              child: const Text('Dev: mark as subscribed'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
