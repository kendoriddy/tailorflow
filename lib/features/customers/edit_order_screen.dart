import 'package:flutter/material.dart';

import '../../data/data_layer.dart';
import '../../data/models/order_row.dart';
import '../../data/models/order_status.dart';

class EditOrderScreen extends StatefulWidget {
  const EditOrderScreen({
    super.key,
    required this.layer,
    required this.order,
  });

  final DataLayer layer;
  final OrderRow order;

  @override
  State<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends State<EditOrderScreen> {
  late final TextEditingController _style;
  late final TextEditingController _price;
  late DateTime _due;
  late OrderStatus _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _style = TextEditingController(text: widget.order.title);
    _price =
        TextEditingController(text: widget.order.agreedAmountNgn.toString());
    _due = widget.order.dueDate;
    _status = widget.order.status;
  }

  @override
  void dispose() {
    _style.dispose();
    _price.dispose();
    super.dispose();
  }

  int _int(TextEditingController c) =>
      int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  Future<void> _save() async {
    if (_busy) return;
    final title = _style.text.trim();
    final price = _int(_price);
    if (title.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter style and a valid price.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.layer.orders.updateOrder(
        OrderRow(
          id: widget.order.id,
          customerId: widget.order.customerId,
          title: title,
          fabricNote: widget.order.fabricNote,
          dueDate: _due,
          status: _status,
          agreedAmountNgn: price,
          createdAt: widget.order.createdAt,
          updatedAt: widget.order.updatedAt,
        ),
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
      appBar: AppBar(title: const Text('Edit Order')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _style,
            decoration: const InputDecoration(labelText: 'Style'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            decoration: const InputDecoration(labelText: 'Price (₦)'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<OrderStatus>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: OrderStatus.values
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.name),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? _status),
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
                firstDate:
                    DateTime.now().subtract(const Duration(days: 365 * 5)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              );
              if (picked != null) setState(() => _due = picked);
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
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
