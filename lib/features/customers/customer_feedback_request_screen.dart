import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/data_layer.dart';
import '../../data/feedback/customer_feedback_remote.dart';
import '../../data/models/customer.dart';
import '../../data/models/order_money_view.dart';
import '../whatsapp/whatsapp_launcher.dart';
import '../whatsapp/whatsapp_templates.dart';

class CustomerFeedbackRequestScreen extends StatefulWidget {
  const CustomerFeedbackRequestScreen({
    super.key,
    required this.layer,
    required this.customer,
    this.order,
  });

  final DataLayer layer;
  final Customer customer;
  final OrderMoneyView? order;

  @override
  State<CustomerFeedbackRequestScreen> createState() =>
      _CustomerFeedbackRequestScreenState();
}

class _CustomerFeedbackRequestScreenState
    extends State<CustomerFeedbackRequestScreen> {
  final _comment = TextEditingController();
  final _day = TextEditingController();
  final _month = TextEditingController();
  final _year = TextEditingController();
  int _rating = 5;
  bool _birthdayConsent = true;
  bool _sending = false;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _day.text = widget.customer.birthDay?.toString() ?? '';
    _month.text = widget.customer.birthMonth?.toString() ?? '';
    _year.text = widget.customer.birthYear?.toString() ?? '';
    _birthdayConsent = widget.customer.birthdayConsent;
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _packageInfo = info);
    } catch (_) {}
  }

  @override
  void dispose() {
    _comment.dispose();
    _day.dispose();
    _month.dispose();
    _year.dispose();
    super.dispose();
  }

  String _platformLabel() {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  int? _parseInRange(TextEditingController c, int min, int max) {
    final v = int.tryParse(c.text.trim());
    if (v == null) return null;
    if (v < min || v > max) return null;
    return v;
  }

  Future<void> _sendRequestWhatsApp() async {
    final orderTitle = widget.order?.order.title;
    final ok = await openWhatsAppText(
      rawPhone: widget.customer.phone,
      message: WhatsAppTemplates.feedbackAndBirthdayRequest(
        customerName: widget.customer.name,
        orderTitle: orderTitle,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Feedback request opened in WhatsApp.'
              : 'Add a valid phone number to send request on WhatsApp.',
        ),
      ),
    );
  }

  Future<void> _saveResponse() async {
    if (_sending) return;
    final day = _parseInRange(_day, 1, 31);
    final month = _parseInRange(_month, 1, 12);
    final yearText = _year.text.trim();
    final year = yearText.isEmpty ? null : int.tryParse(yearText);

    if (day == null || month == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Birthday day and month are required and must be valid.'),
        ),
      );
      return;
    }
    if (yearText.isNotEmpty && (year == null || year < 1900 || year > 2100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Year is optional, but must be valid.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await widget.layer.customers.upsertBirthdayDetails(
        customerId: widget.customer.id,
        birthDay: day,
        birthMonth: month,
        birthYear: year,
        consent: _birthdayConsent,
      );

      final remoteOk = await CustomerFeedbackRemote.trySubmit(
        customerId: widget.customer.id,
        customerName: widget.customer.name,
        orderId: widget.order?.order.id,
        orderTitle: widget.order?.order.title,
        rating: _rating,
        comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
        birthDay: day,
        birthMonth: month,
        birthYear: year,
        birthdayConsent: _birthdayConsent,
        platform: _platformLabel(),
        appVersion: _packageInfo?.version,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            remoteOk
                ? 'Customer feedback saved and sent to backend.'
                : 'Saved locally. Backend submit failed; retry sync later.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Feedback')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Send a thank-you + feedback request to the customer, then record their response here.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _sendRequestWhatsApp,
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Send feedback request on WhatsApp'),
          ),
          const SizedBox(height: 20),
          Text('Rating', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _rating,
            items: [1, 2, 3, 4, 5]
                .map(
                  (r) => DropdownMenuItem<int>(
                    value: r,
                    child: Text('$r star${r == 1 ? '' : 's'}'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _rating = v ?? _rating),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            decoration: const InputDecoration(
              labelText: 'Feedback comment (optional)',
              border: OutlineInputBorder(),
            ),
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 20),
          Text(
            'Birthday details',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell the customer we ask this to celebrate them on their birthday and offer discounts.',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _day,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Day *'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _month,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Month *'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _year,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Year (optional)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: _birthdayConsent,
            onChanged: (v) => setState(() => _birthdayConsent = v),
            contentPadding: EdgeInsets.zero,
            title: const Text('Customer agreed to birthday messages/offers'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _sending ? null : _saveResponse,
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save feedback response'),
            ),
          ),
        ],
      ),
    );
  }
}
