import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/branding_scope.dart';
import '../../data/billing/remote_flags.dart';
import '../../data/billing/subscription_pricing.dart';
import '../../data/data_layer.dart';
import 'paystack_checkout_screen.dart';

/// Shown when freemium cap is hit and [RemoteFlags.paywallEnabled] is true.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key, required this.layer});

  final DataLayer layer;

  static Future<bool> ensureCanAddCustomer({
    required BuildContext context,
    required DataLayer layer,
  }) async {
    if (!RemoteFlags.paywallEnabled) return true;
    if (await layer.subscriptions.isActive()) return true;
    final limit = await layer.freemium.freeCustomerLimit();
    final count = await layer.freemium.activeCustomerCount();
    if (count < limit) return true;
    if (!context.mounted) return false;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => PaywallScreen(layer: layer),
      ),
    );
    if (!context.mounted) return false;
    return layer.subscriptions.isActive();
  }

  Future<void> _subscribe(
    BuildContext context,
    SubscriptionPlan plan,
  ) async {
    final subs = layer.subscriptions;
    if (!subs.isConfigured) {
      _showError(context, 'Cloud backup is not configured for this build.');
      return;
    }
    if (!await subs.isSignedIn()) {
      _showError(
        context,
        'Sign in under Settings → Cloud sync before subscribing.',
      );
      return;
    }

    try {
      final checkout = await subs.startCheckout(plan);
      if (!context.mounted) return;
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => PaystackCheckoutScreen(
            authorizationUrl: checkout.authorizationUrl,
            reference: checkout.reference,
            subscriptions: subs,
          ),
        ),
      );
      if (ok == true) {
        await subs.syncEntitlement();
        if (context.mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (context.mounted) _showError(context, '$e');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appName = BrandingScope.of(context).displayName;
    return Scaffold(
      appBar: AppBar(title: Text('Upgrade $appName')),
      body: FutureBuilder<int>(
        future: layer.freemium.freeCustomerLimit(),
        builder: (context, snap) {
          final limit = snap.data ?? 50;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'You have reached the free limit ($limit active customers).',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Subscribe for unlimited customers and WhatsApp messages. '
                'Payments are processed securely by Paystack.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _PlanCard(
                title: 'Monthly',
                price: SubscriptionPricing.labelMonthly(),
                subtitle: 'Billed every month',
                onTap: () => _subscribe(context, SubscriptionPlan.monthly),
              ),
              const SizedBox(height: 12),
              _PlanCard(
                title: 'Yearly',
                price: SubscriptionPricing.labelYearly(),
                subtitle: 'Save vs paying monthly',
                highlighted: true,
                onTap: () => _subscribe(context, SubscriptionPlan.yearly),
              ),
              const SizedBox(height: 20),
              FutureBuilder<bool>(
                future: layer.subscriptions.isSignedIn(),
                builder: (context, signedIn) {
                  if (signedIn.data != false) return const SizedBox.shrink();
                  return Text(
                    'Sign in with your cloud account to subscribe.',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                },
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 24),
                const Divider(),
                OutlinedButton(
                  onPressed: () async {
                    await layer.settings.setSubscribed(true);
                    if (context.mounted) Navigator.of(context).pop(true);
                  },
                  child: const Text('Dev: mark as subscribed (local only)'),
                ),
              ],
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final String title;
  final String price;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: highlighted ? 2 : 0,
      color: highlighted
          ? Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.35)
          : null,
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('$price\n$subtitle'),
        isThreeLine: true,
        trailing: FilledButton(
          onPressed: onTap,
          child: const Text('Subscribe'),
        ),
      ),
    );
  }
}
