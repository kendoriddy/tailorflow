import 'package:flutter/material.dart';

import '../../data/data_layer.dart';
import '../../data/models/payment.dart';

class EditPaymentScreen extends StatefulWidget {
  const EditPaymentScreen({
    super.key,
    required this.layer,
    required this.payment,
  });

  final DataLayer layer;
  final Payment payment;

  @override
  State<EditPaymentScreen> createState() => _EditPaymentScreenState();
}

class _EditPaymentScreenState extends State<EditPaymentScreen> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: widget.payment.amountNgn.toString());
    _note = TextEditingController(text: widget.payment.note ?? '');
    _date = widget.payment.paidAt;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  int _int(TextEditingController c) =>
      int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  Future<void> _save() async {
    if (_busy) return;
    final amount = _int(_amount);
    if (amount <= 0) return;
    setState(() => _busy = true);
    try {
      await widget.layer.payments.updatePayment(
        Payment(
          id: widget.payment.id,
          orderId: widget.payment.orderId,
          amountNgn: amount,
          paidAt: _date,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete payment?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.layer.payments.deletePayment(widget.payment.id);
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
      appBar: AppBar(
        title: const Text('Edit Payment'),
        actions: [
          IconButton(
            tooltip: 'Delete',
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
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
