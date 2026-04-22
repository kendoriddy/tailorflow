import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/data_layer.dart';
import '../billing/paywall_screen.dart';
import 'customer_detail_screen.dart';

class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key, required this.layer});

  final DataLayer layer;

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _chest = TextEditingController();
  final _waist = TextEditingController();
  final _length = TextEditingController();
  final _sleeve = TextEditingController();
  final _shoulder = TextEditingController();
  final _neck = TextEditingController();
  final _inseam = TextEditingController();
  final _notes = TextEditingController();

  bool _saveAndOrder = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _chest.dispose();
    _waist.dispose();
    _length.dispose();
    _sleeve.dispose();
    _shoulder.dispose();
    _neck.dispose();
    _inseam.dispose();
    _notes.dispose();
    super.dispose();
  }

  double? _readDouble(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
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

      await widget.layer.customers.upsertDefaultMeasurements(
        customerId: id,
        chest: _readDouble(_chest),
        waist: _readDouble(_waist),
        length: _readDouble(_length),
        sleeve: _readDouble(_sleeve),
        shoulder: _readDouble(_shoulder),
        neck: _readDouble(_neck),
        inseam: _readDouble(_inseam),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );

      if (_saveAndOrder) {
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CustomerDetailScreen(
              layer: widget.layer,
              customerId: id,
              openAddOrder: true,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.of(context).pop(true);
      }
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
            'Keep it fast: name + phone, then the measurements you need.',
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
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          Text('Measurements', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _numField(_chest, 'Chest'),
          _numField(_waist, 'Waist'),
          _numField(_length, 'Length'),
          _numField(_sleeve, 'Sleeve'),
          _numField(_shoulder, 'Shoulder'),
          _numField(_neck, 'Neck'),
          _numField(_inseam, 'Inseam'),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes'),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _saveAndOrder,
            onChanged: (v) => setState(() => _saveAndOrder = v),
            title: const Text('Save & add order'),
            subtitle: const Text('Jump straight to creating an order for this customer'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_saveAndOrder ? 'Save & continue' : 'Save customer'),
          ),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }
}
