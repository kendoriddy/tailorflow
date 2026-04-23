import 'package:flutter/material.dart';

import '../../core/utils/currency.dart';
import '../../data/data_layer.dart';
import '../../data/models/order_money_view.dart';

class RecordPaymentScreen extends StatefulWidget {
  const RecordPaymentScreen({
    super.key,
    required this.layer,
    required this.customerId,
    required this.orders,
  });

  final DataLayer layer;
  final String customerId;
  final List<OrderMoneyView> orders;

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _amount = TextEditingController();
  DateTime _date = DateTime.now();
  String? _orderId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _orderId = widget.orders.isEmpty ? null : widget.orders.first.order.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int _int(TextEditingController c) {
    return int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  Future<void> _save() async {
    if (_busy) return;
    final orderId = _orderId;
    final amount = _int(_amount);
    if (orderId == null || amount <= 0) return;

    setState(() => _busy = true);
    try {
      await widget.layer.payments.insertPayment(
        orderId: orderId,
        amountNgn: amount,
        paidAt: _date,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Record Payment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _orderId,
            decoration: const InputDecoration(labelText: 'Order'),
            items: widget.orders
                .map(
                  (o) => DropdownMenuItem(
                    value: o.order.id,
                    child: Text(
                        '${o.order.title} • Balance ${formatNgn(o.balanceNgn)}'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _orderId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            decoration: const InputDecoration(labelText: 'Amount (₦)'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text(l10n.formatMediumDate(_date)),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate:
                    DateTime.now().subtract(const Duration(days: 365 * 5)),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Payment'),
            ),
          ),
        ],
      ),
    );
  }
}
