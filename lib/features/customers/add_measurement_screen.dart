import 'package:flutter/material.dart';

import '../../data/data_layer.dart';
import '../../data/models/measurement_profile.dart';

class AddMeasurementScreen extends StatefulWidget {
  const AddMeasurementScreen({
    super.key,
    required this.layer,
    required this.customerId,
    this.existing,
  });

  final DataLayer layer;
  final String customerId;
  final MeasurementProfile? existing;

  @override
  State<AddMeasurementScreen> createState() => _AddMeasurementScreenState();
}

class _AddMeasurementScreenState extends State<AddMeasurementScreen> {
  final _chest = TextEditingController();
  final _waist = TextEditingController();
  final _hip = TextEditingController();
  final _shoulder = TextEditingController();
  final _sleeve = TextEditingController();
  final _length = TextEditingController();
  final _custom = TextEditingController();

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    String f(double? v) => v == null ? '' : v.toString();
    _chest.text = f(m?.chest);
    _waist.text = f(m?.waist);
    _hip.text = f(m?.hip);
    _shoulder.text = f(m?.shoulder);
    _sleeve.text = f(m?.sleeve);
    _length.text = f(m?.length);
    _custom.text = m?.notes ?? '';
  }

  @override
  void dispose() {
    _chest.dispose();
    _waist.dispose();
    _hip.dispose();
    _shoulder.dispose();
    _sleeve.dispose();
    _length.dispose();
    _custom.dispose();
    super.dispose();
  }

  double? _d(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.layer.customers.upsertDefaultMeasurements(
        customerId: widget.customerId,
        chest: _d(_chest),
        waist: _d(_waist),
        hip: _d(_hip),
        shoulder: _d(_shoulder),
        sleeve: _d(_sleeve),
        length: _d(_length),
        notes: _custom.text.trim().isEmpty ? null : _custom.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Measurement')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _num(_chest, 'Chest'),
          _num(_waist, 'Waist'),
          _num(_hip, 'Hip'),
          _num(_shoulder, 'Shoulder'),
          _num(_sleeve, 'Sleeve'),
          _num(_length, 'Length'),
          const SizedBox(height: 8),
          TextField(
            controller: _custom,
            decoration: const InputDecoration(
              labelText: 'Add custom (optional)',
              hintText: 'e.g. Round sleeve: 14',
            ),
            minLines: 2,
            maxLines: 4,
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

  Widget _num(TextEditingController c, String label) {
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
