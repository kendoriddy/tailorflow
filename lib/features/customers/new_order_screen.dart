import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/currency.dart';
import '../../data/data_layer.dart';
import '../../data/models/order_attachment.dart';

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
  final _picker = ImagePicker();
  DateTime _due = DateTime.now().add(const Duration(days: 7));
  final List<NewOrderAttachmentInput> _attachments = [];

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

  String _guessMimeType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _pickFromCamera() async {
    final f = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (!mounted) return;
    setState(() {
      _attachments.add(
        NewOrderAttachmentInput(
          imageBase64: base64Encode(bytes),
          mimeType: _guessMimeType(f.name),
        ),
      );
    });
  }

  Future<void> _pickFromGallery() async {
    final files = await _picker.pickMultiImage(imageQuality: 75);
    if (files.isEmpty) return;
    final additions = <NewOrderAttachmentInput>[];
    for (final f in files) {
      final bytes = await f.readAsBytes();
      additions.add(
        NewOrderAttachmentInput(
          imageBase64: base64Encode(bytes),
          mimeType: _guessMimeType(f.name),
        ),
      );
    }
    if (!mounted) return;
    setState(() => _attachments.addAll(additions));
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
      if (_attachments.isNotEmpty) {
        await widget.layer.orders.addAttachments(
          orderId: orderId,
          images: _attachments,
        );
      }
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickFromCamera,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Snap fabric/style'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Add from gallery'),
                ),
              ),
            ],
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _attachments.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final bytes = base64Decode(_attachments[i].imageBase64);
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          bytes,
                          width: 90,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _busy
                              ? null
                              : () => setState(() => _attachments.removeAt(i)),
                          child: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
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
