import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/branding_scope.dart';
import '../../data/billing/remote_flags.dart';
import '../../data/data_layer.dart';
import '../../data/models/customer_list_item.dart';
import '../../data/whatsapp/whatsapp_service.dart';
import '../whatsapp/whatsapp_templates.dart';

enum PromoDiscountKind { percent, fixedNgn }

bool promoWhatsAppQuotaWouldBlock({
  required bool paywallEnabled,
  required bool subscribed,
  required bool freeWhatsAppUnlimited,
  required int monthlyLimit,
  required int usedThisMonth,
  required int targetCount,
}) {
  if (!paywallEnabled || subscribed || freeWhatsAppUnlimited) {
    return false;
  }
  return monthlyLimit - usedThisMonth < targetCount;
}

class PromoCampaignScreen extends StatefulWidget {
  const PromoCampaignScreen({super.key, required this.layer});

  final DataLayer layer;

  @override
  State<PromoCampaignScreen> createState() => _PromoCampaignScreenState();
}

class _PromoCampaignScreenState extends State<PromoCampaignScreen> {
  PromoDiscountKind _kind = PromoDiscountKind.percent;
  final _amount = TextEditingController(text: '10');
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 14));
  final _selected = <String>{};
  bool _selectAll = false;
  List<CustomerListItem>? _customers;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final rows = await widget.layer.customers.listSummary();
    if (!mounted) return;
    setState(() => _customers = rows);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _offerDescription() {
    final value = _amount.text.trim();
    switch (_kind) {
      case PromoDiscountKind.percent:
        return '$value% off';
      case PromoDiscountKind.fixedNgn:
        final n = int.tryParse(value.replaceAll(',', '')) ?? 0;
        return '₦${NumberFormat('#,###').format(n)} off your next order';
    }
  }

  String _validThroughText() {
    final fmt = DateFormat('d MMM yyyy');
    return '${fmt.format(_start)} – ${fmt.format(_end)}';
  }

  List<CustomerListItem> get _targets {
    final all = _customers ?? [];
    if (_selectAll) {
      return all.where((c) => c.phone?.trim().isNotEmpty == true).toList();
    }
    return all.where((c) => _selected.contains(c.customerId)).toList();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _startSendQueue() async {
    final targets = _targets;
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select at least one customer with a phone number.')),
      );
      return;
    }

    final subscribed = await widget.layer.subscriptions.isActive();
    if (!subscribed && RemoteFlags.paywallEnabled) {
      final config = await widget.layer.planLimits.getConfig();
      final used = await widget.layer.whatsappQuota.usedThisMonth();
      final needed = targets.length;
      final left = config.freeWhatsAppMonthlyLimit - used;
      if (promoWhatsAppQuotaWouldBlock(
        paywallEnabled: RemoteFlags.paywallEnabled,
        subscribed: subscribed,
        freeWhatsAppUnlimited: config.freeWhatsAppUnlimited,
        monthlyLimit: config.freeWhatsAppMonthlyLimit,
        usedThisMonth: used,
        targetCount: needed,
      )) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This promo needs $needed WhatsApp sends but you have $left left '
              'this month on the free plan.',
            ),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    final shopName = BrandingScope.of(context).shopNameForMessages;
    final offer = _offerDescription();
    final valid = _validThroughText();

    setState(() => _sending = true);

    for (var i = 0; i < targets.length; i++) {
      if (!mounted) return;
      final c = targets[i];
      final msg = WhatsAppTemplates.promo(
        customerName: c.name,
        shopName: shopName,
        offerDescription: offer,
        validThrough: valid,
      );
      final result = await widget.layer.whatsapp.sendText(
        rawPhone: c.phone,
        message: msg,
      );
      if (result == WhatsAppSendResult.quotaExceeded) {
        if (!mounted) return;
        final config = await widget.layer.planLimits.getConfig();
        final used = await widget.layer.whatsappQuota.usedThisMonth();
        if (mounted) {
          WhatsAppService.showResultSnackBar(
            context,
            result,
            limit: config.freeWhatsAppMonthlyLimit,
            used: used,
          );
        }
        break;
      }
      if (!mounted) return;
      final continueNext = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text('WhatsApp (${i + 1} of ${targets.length})'),
          content: Text(
            result == WhatsAppSendResult.sent
                ? 'WhatsApp opened for ${c.name}. Tap Send in WhatsApp, then continue to the next customer.'
                : 'Could not open WhatsApp for ${c.name}. Skip and continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stop'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(i + 1 < targets.length ? 'Next customer' : 'Done'),
            ),
          ],
        ),
      );
      if (continueNext != true) break;
    }

    if (mounted) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promo send queue finished.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = _customers;
    return Scaffold(
      appBar: AppBar(title: const Text('Promo campaign')),
      body: customers == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Send a discount offer via WhatsApp. The app opens WhatsApp for each '
                  'customer with a prefilled message — you tap Send in WhatsApp for each one.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                SegmentedButton<PromoDiscountKind>(
                  segments: const [
                    ButtonSegment(
                      value: PromoDiscountKind.percent,
                      label: Text('% off'),
                    ),
                    ButtonSegment(
                      value: PromoDiscountKind.fixedNgn,
                      label: Text('₦ off'),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _kind == PromoDiscountKind.percent
                        ? 'Discount percent'
                        : 'Amount in Naira',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start date'),
                  subtitle: Text(DateFormat.yMMMd().format(_start)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(isStart: true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('End date'),
                  subtitle: Text(DateFormat.yMMMd().format(_end)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(isStart: false),
                ),
                const SizedBox(height: 8),
                Text('Preview', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      WhatsAppTemplates.promo(
                        customerName: 'Customer',
                        shopName: BrandingScope.of(context).shopNameForMessages,
                        offerDescription: _offerDescription(),
                        validThrough: _validThroughText(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All customers with phone numbers'),
                  value: _selectAll,
                  onChanged: (v) => setState(() {
                    _selectAll = v;
                    if (v) _selected.clear();
                  }),
                ),
                if (!_selectAll) ...[
                  Text(
                    'Select customers',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  ...customers.map((c) {
                    final hasPhone = c.phone?.trim().isNotEmpty == true;
                    return CheckboxListTile(
                      value: _selected.contains(c.customerId),
                      onChanged: hasPhone
                          ? (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(c.customerId);
                                } else {
                                  _selected.remove(c.customerId);
                                }
                              });
                            }
                          : null,
                      title: Text(c.name),
                      subtitle: Text(
                        hasPhone ? (c.phone ?? '') : 'No phone — cannot send',
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _sending ? null : _startSendQueue,
                  icon: const Icon(Icons.campaign_outlined),
                  label: Text(
                    _sending
                        ? 'Sending…'
                        : 'Send to ${_targets.length} customer(s)',
                  ),
                ),
              ],
            ),
    );
  }
}
