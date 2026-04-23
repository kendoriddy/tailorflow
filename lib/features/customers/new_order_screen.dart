import 'package:flutter/material.dart';

import '../../core/utils/currency.dart';
import '../../data/data_layer.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({
    super.key,
    required this.layer,
    required this.customerId,
  });

  final DataLayer layer;
  final String customerId;

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final _style = TextEditingController();
  final _price = TextEditingController();
  final _paid = TextEditingController();
  DateTime _due = DateTime.now().add(const Duration(days: 7));

  bool _busy = false;

  @override
  void dispose() {
    _style.dispose();
    _price.dispose();
    _paid.dispose();
    super.dispose();
  }

  int _int(TextEditingController c) {
    return int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  int get _balance {
    final bal = _int(_price) - _int(_paid);
    return bal < 0 ? 0 : bal;
  }

  Future<void> _save() async {
    if (_busy) return;
    final style = _style.text.trim();
    final price = _int(_price);
    final paid = _int(_paid);
    if (style.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter style and a valid price.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final orderId = await widget.layer.orders.insertOrder(
        customerId: widget.customerId,
        title: style,
        dueDate: _due,
        agreedAmountNgn: price,
      );
      if (paid > 0) {
        await widget.layer.payments.insertPayment(
          orderId: orderId,
          amountNgn: paid,
          paidAt: DateTime.now(),
        );
      }
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
      appBar: AppBar(title: const Text('New Order')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _style,
            decoration: const InputDecoration(
              labelText: 'Style',
              hintText: 'Agbada, Gown, Trouser…',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            decoration: const InputDecoration(labelText: 'Price (₦)'),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _paid,
            decoration: const InputDecoration(labelText: 'Amount Paid (₦)'),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Due Date'),
            subtitle: Text(l10n.formatMediumDate(_due)),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _due,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              );
              if (picked != null) setState(() => _due = picked);
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Balance = ${formatNgn(_balance)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
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
                  : const Text('Save Order'),
            ),
          ),
        ],
      ),
    );
  }
}
