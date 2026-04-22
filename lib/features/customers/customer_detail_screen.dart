import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency.dart';
import '../../data/data_layer.dart';
import '../../data/models/customer.dart';
import '../../data/models/measurement_profile.dart';
import '../../data/models/order_row.dart';
import '../../data/models/order_status.dart';
import '../whatsapp/whatsapp_launcher.dart';
import '../whatsapp/whatsapp_templates.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({
    super.key,
    required this.layer,
    required this.customerId,
    this.openAddOrder = false,
  });

  final DataLayer layer;
  final String customerId;
  final bool openAddOrder;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Future<_DetailBundle> _future;
  String? _measSig;

  @override
  void initState() {
    super.initState();
    _future = _load();
    if (widget.openAddOrder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openAddOrder();
      });
    }
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<_DetailBundle> _load() async {
    final c = await widget.layer.customers.getById(widget.customerId);
    if (c == null || !c.isActive) {
      return _DetailBundle(customer: null, measurements: null, orders: const []);
    }
    final m = await widget.layer.customers.defaultMeasurements(c.id);
    final orders = await widget.layer.orders.listForCustomer(c.id);
    var totalOwed = 0;
    final balances = <String, int>{};
    for (final o in orders) {
      final b = await widget.layer.orders.balanceForOrder(o.id);
      balances[o.id] = b;
      if (b > 0) totalOwed += b;
    }
    return _DetailBundle(
      customer: c,
      measurements: m,
      orders: orders,
      balances: balances,
      totalOwed: totalOwed,
    );
  }

  Future<void> _openAddOrder() async {
    final title = TextEditingController();
    final fabric = TextEditingController();
    final agreed = TextEditingController();
    DateTime due = DateTime.now().add(const Duration(days: 7));
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('New order'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Style / title'),
                    ),
                    TextField(
                      controller: fabric,
                      decoration: const InputDecoration(labelText: 'Fabric note'),
                    ),
                    TextField(
                      controller: agreed,
                      decoration: const InputDecoration(labelText: 'Agreed price (₦)'),
                      keyboardType: TextInputType.number,
                    ),
                    ListTile(
                      title: const Text('Due date'),
                      subtitle: Text(MaterialLocalizations.of(context).formatMediumDate(due)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: due,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                        );
                        if (picked != null) setLocal(() => due = picked);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true) return;
    final price = int.tryParse(agreed.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (title.text.trim().isEmpty || price <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter style and a valid agreed price.')),
        );
      }
      return;
    }
    await widget.layer.orders.insertOrder(
      customerId: widget.customerId,
      title: title.text,
      fabricNote: fabric.text.trim().isEmpty ? null : fabric.text,
      dueDate: due,
      agreedAmountNgn: price,
    );
    await _reload();
  }

  Future<void> _openPayment(String orderId) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              decoration: const InputDecoration(labelText: 'Amount paid (₦)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final v = int.tryParse(amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (v <= 0) return;
    await widget.layer.payments.insertPayment(orderId: orderId, amountNgn: v, note: note.text);
    await _reload();
  }

  Future<void> _saveMeasurements(MeasurementProfile? existing) async {
    final c = widget.customerId;
    await widget.layer.customers.upsertDefaultMeasurements(
      customerId: c,
      label: existing?.label ?? 'Default',
      chest: _read(_chest),
      waist: _read(_waist),
      length: _read(_length),
      sleeve: _read(_sleeve),
      shoulder: _read(_shoulder),
      neck: _read(_neck),
      inseam: _read(_inseam),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    await _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Measurements saved')),
      );
    }
  }

  double? _read(TextEditingController t) {
    final s = t.text.trim();
    if (s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  final _chest = TextEditingController();
  final _waist = TextEditingController();
  final _length = TextEditingController();
  final _sleeve = TextEditingController();
  final _shoulder = TextEditingController();
  final _neck = TextEditingController();
  final _inseam = TextEditingController();
  final _notes = TextEditingController();

  void _bindMeasurements(MeasurementProfile? m) {
    String f(double? v) => v == null ? '' : v.toString();
    _chest.text = m == null ? '' : f(m.chest);
    _waist.text = m == null ? '' : f(m.waist);
    _length.text = m == null ? '' : f(m.length);
    _sleeve.text = m == null ? '' : f(m.sleeve);
    _shoulder.text = m == null ? '' : f(m.shoulder);
    _neck.text = m == null ? '' : f(m.neck);
    _inseam.text = m == null ? '' : f(m.inseam);
    _notes.text = m?.notes ?? '';
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DetailBundle>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final bundle = snap.data!;
        final c = bundle.customer;
        if (c == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Customer')),
            body: const Center(child: Text('Customer not found.')),
          );
        }
        final sig =
            '${c.id}|${bundle.measurements?.updatedAt.millisecondsSinceEpoch ?? 0}';
        if (sig != _measSig) {
          _measSig = sig;
          _bindMeasurements(bundle.measurements);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(c.name),
            actions: [
              IconButton(
                tooltip: 'Add order',
                onPressed: _openAddOrder,
                icon: const Icon(Icons.add_task),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (bundle.totalOwed > 0)
                  Card(
                    color: AppTheme.oweRed.withOpacity(0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppTheme.oweRed),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Owe ${formatNgn(bundle.totalOwed)}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppTheme.oweRed,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (bundle.totalOwed > 0) const SizedBox(height: 12),
                Text('Measurements', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _measureField(_chest, 'Chest'),
                _measureField(_waist, 'Waist'),
                _measureField(_length, 'Length'),
                _measureField(_sleeve, 'Sleeve'),
                _measureField(_shoulder, 'Shoulder'),
                _measureField(_neck, 'Neck'),
                _measureField(_inseam, 'Inseam'),
                TextField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => _saveMeasurements(bundle.measurements),
                  child: const Text('Save measurements'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Orders', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _openAddOrder,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (bundle.orders.isEmpty)
                  const Text('No orders yet.')
                else
                  ...bundle.orders.map((o) {
                    final bal = bundle.balances[o.id] ?? 0;
                    return _OrderCard(
                      order: o,
                      balance: bal,
                      onStatus: (s) async {
                        await widget.layer.orders.updateOrder(
                          OrderRow(
                            id: o.id,
                            customerId: o.customerId,
                            title: o.title,
                            fabricNote: o.fabricNote,
                            dueDate: o.dueDate,
                            status: s,
                            agreedAmountNgn: o.agreedAmountNgn,
                            createdAt: o.createdAt,
                            updatedAt: o.updatedAt,
                          ),
                        );
                        await _reload();
                      },
                      onPay: () => _openPayment(o.id),
                      onWhatsApp: () async {
                        final msg = WhatsAppTemplates.dressReady(
                          customerName: c.name,
                          styleTitle: o.title,
                        );
                        final ok = await openWhatsAppText(rawPhone: c.phone, message: msg);
                        if (!ok && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Add a phone number to send WhatsApp.')),
                          );
                        }
                      },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _measureField(TextEditingController c, String label) {
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

class _DetailBundle {
  _DetailBundle({
    required this.customer,
    required this.measurements,
    required this.orders,
    this.balances = const {},
    this.totalOwed = 0,
  });

  final Customer? customer;
  final MeasurementProfile? measurements;
  final List<OrderRow> orders;
  final Map<String, int> balances;
  final int totalOwed;
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.balance,
    required this.onStatus,
    required this.onPay,
    required this.onWhatsApp,
  });

  final OrderRow order;
  final int balance;
  final ValueChanged<OrderStatus> onStatus;
  final VoidCallback onPay;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.title, style: Theme.of(context).textTheme.titleSmall),
            if (order.fabricNote?.isNotEmpty == true) Text(order.fabricNote!),
            const SizedBox(height: 6),
            Text(
              'Due: ${MaterialLocalizations.of(context).formatMediumDate(order.dueDate)}',
            ),
            Text('Agreed: ${formatNgn(order.agreedAmountNgn)}'),
            const SizedBox(height: 6),
            if (balance > 0)
              Text(
                'Owe ${formatNgn(balance)}',
                style: const TextStyle(color: AppTheme.oweRed, fontWeight: FontWeight.w800),
              )
            else
              const Text('Fully paid', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<OrderStatus>(
                    value: order.status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: OrderStatus.values
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onStatus(v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onWhatsApp,
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp ready'),
                ),
                FilledButton.tonalIcon(
                  onPressed: balance > 0 ? onPay : null,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Add payment'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
