import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/data_layer.dart';
import '../billing/paywall_screen.dart';
import 'customer_profile_screen.dart';

class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key, required this.layer});

  final DataLayer layer;

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final allowed = await PaywallScreen.ensureCanAddCustomer(
        context: context,
        layer: widget.layer,
      );
      if (!allowed || !mounted) return;

      final id = await widget.layer.customers.insertCustomer(
        name: _name.text,
        phone: _phone.text.trim().isEmpty ? null : _phone.text,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CustomerProfileScreen(
            layer: widget.layer,
            customerId: id,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New customer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Fast: name + phone. Save & continue.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(labelText: 'Phone (recommended)'),
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
            ],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
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
                  : const Text('Save & Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
