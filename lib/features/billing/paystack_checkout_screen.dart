import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/billing/subscription_service.dart';

// WebView is mobile/desktop only; Flutter Web uses the browser tab flow below.
import 'paystack_checkout_webview.dart'
    if (dart.library.html) 'paystack_checkout_web_stub.dart' as webview_checkout;

/// Paystack checkout: in-app WebView on mobile, new browser tab on web.
class PaystackCheckoutScreen extends StatefulWidget {
  const PaystackCheckoutScreen({
    super.key,
    required this.authorizationUrl,
    required this.reference,
    required this.subscriptions,
  });

  final String authorizationUrl;
  final String reference;
  final SubscriptionService subscriptions;

  @override
  State<PaystackCheckoutScreen> createState() => _PaystackCheckoutScreenState();
}

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen> {
  bool _verifying = false;
  String? _error;
  bool _openedBrowser = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openBrowserCheckout());
    }
  }

  Future<void> _openBrowserCheckout() async {
    final uri = Uri.parse(widget.authorizationUrl);
    final ok = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!mounted) return;
    setState(() {
      _openedBrowser = ok;
      if (!ok) {
        _error = 'Could not open Paystack. Allow pop-ups and try again.';
      }
    });
  }

  Future<void> _completeCheckout() async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final verified =
          await widget.subscriptions.verifyCheckout(widget.reference);
      if (!mounted) return;
      Navigator.of(context).pop(verified);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _verifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return webview_checkout.PaystackCheckoutWebView(
        authorizationUrl: widget.authorizationUrl,
        reference: widget.reference,
        subscriptions: widget.subscriptions,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay with Paystack'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.open_in_new, size: 48),
            const SizedBox(height: 16),
            Text(
              _openedBrowser
                  ? 'Paystack opened in a new browser tab.'
                  : 'Opening Paystack…',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Complete payment there, then return here and tap the button below. '
              'Your subscription will activate after we confirm with Paystack.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Reference: ${widget.reference}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _verifying ? null : _completeCheckout,
              icon: _verifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined),
              label: Text(
                _verifying ? 'Confirming payment…' : 'I\'ve completed payment',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _verifying ? null : _openBrowserCheckout,
              child: const Text('Open Paystack again'),
            ),
          ],
        ),
      ),
    );
  }
}
