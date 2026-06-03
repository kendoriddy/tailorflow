import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/billing/subscription_service.dart';

/// In-app Paystack checkout for Android, iOS, and desktop (not web).
class PaystackCheckoutWebView extends StatefulWidget {
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
  State<PaystackCheckoutWebView> createState() => _PaystackCheckoutWebViewState();
}

class _PaystackCheckoutWebViewState extends State<PaystackCheckoutWebView> {
  late final WebViewController _controller;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigation,
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final url = request.url;
    if (url.contains('paystack-return') ||
        url.contains('reference=') ||
        url.contains('trxref=')) {
      final ref = _extractReference(url) ?? widget.reference;
      _completeCheckout(ref);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  String? _extractReference(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    return uri.queryParameters['reference'] ?? uri.queryParameters['trxref'];
  }

  Future<void> _completeCheckout(String reference) async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final ok = await widget.subscriptions.verifyCheckout(reference);
      if (!mounted) return;
      Navigator.of(context).pop(ok);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay with Paystack'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_verifying)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Confirming payment…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_error != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
