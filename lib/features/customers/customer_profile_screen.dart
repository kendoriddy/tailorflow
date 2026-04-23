import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency.dart';
import '../../data/data_layer.dart';
import '../../data/models/customer.dart';
import '../../data/models/measurement_profile.dart';
import '../../data/models/order_money_view.dart';
import '../../data/models/order_status.dart';
import '../../data/models/order_row.dart';
import '../../data/models/payment.dart';
import '../whatsapp/whatsapp_launcher.dart';
import '../whatsapp/whatsapp_templates.dart';
import 'add_measurement_screen.dart';
import 'edit_order_screen.dart';
import 'edit_payment_screen.dart';
import 'new_order_screen.dart';
import 'record_payment_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({
    super.key,
    required this.layer,
    required this.customerId,
  });

  final DataLayer layer;
  final String customerId;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  late Future<_Bundle> _future;
  int _tabIndex = 0;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    super.dispose();
  }

  Future<_Bundle> _load() async {
    final c = await widget.layer.customers.getById(widget.customerId);
    if (c == null || !c.isActive) {
      return const _Bundle.missing();
    }
    final meas = await widget.layer.customers.defaultMeasurements(c.id);
    final orders = await widget.layer.orders.listMoneyForCustomer(c.id);
    final pays = await widget.layer.payments.listForCustomer(c.id);
    var totalOwed = 0;
    for (final o in orders) {
      if (o.balanceNgn > 0) totalOwed += o.balanceNgn;
    }
    return _Bundle(
      customer: c,
      measurements: meas,
      orders: orders,
      payments: pays,
      totalOwedNgn: totalOwed,
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _editMeasurementField({
    required MeasurementProfile existing,
    required String label,
    required double currentValue,
  }) async {
    final controller = TextEditingController(text: currentValue.toString());
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Edit $label'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Enter value'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      final v = double.tryParse(controller.text.trim().replaceAll(',', '.'));
      if (v == null) return;

      await widget.layer.customers.upsertDefaultMeasurements(
        customerId: existing.customerId,
        chest: label == 'Chest' ? v : existing.chest,
        waist: label == 'Waist' ? v : existing.waist,
        hip: label == 'Hip' ? v : existing.hip,
        shoulder: label == 'Shoulder' ? v : existing.shoulder,
        sleeve: label == 'Sleeve' ? v : existing.sleeve,
        length: label == 'Length' ? v : existing.length,
        neck: existing.neck,
        inseam: existing.inseam,
        notes: existing.notes,
      );
      await _reload();
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Bundle>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final b = snap.data!;
        final c = b.customer;
        if (c == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Customer')),
            body: const Center(child: Text('Customer not found.')),
          );
        }

        return DefaultTabController(
          length: 3,
          child: Builder(
            builder: (context) {
              final controller = DefaultTabController.of(context);
              if (controller != _tabController) {
                _tabController?.removeListener(_onTabChanged);
                _tabController = controller;
                _tabController!.addListener(_onTabChanged);
              }

              Future<void> onAddForTab() async {
                if (_tabIndex == 0) {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddMeasurementScreen(
                        layer: widget.layer,
                        customerId: c.id,
                        existing: b.measurements,
                      ),
                    ),
                  );
                  await _reload();
                  return;
                }
                if (_tabIndex == 1) {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NewOrderScreen(
                        layer: widget.layer,
                        customerId: c.id,
                      ),
                    ),
                  );
                  await _reload();
                  return;
                }
                if (b.orders.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Create an order first.')),
                  );
                  return;
                }
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecordPaymentScreen(
                      layer: widget.layer,
                      customerId: c.id,
                      orders: b.orders,
                    ),
                  ),
                );
                await _reload();
              }

              return Scaffold(
                appBar: AppBar(
                  title: Text(c.name),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: Row(
                      children: [
                        const Expanded(
                          child: TabBar(
                            tabs: [
                              Tab(text: 'Measurements'),
                              Tab(text: 'Orders'),
                              Tab(text: 'Payments'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                body: Column(
                  children: [
                    _Header(
                      customer: c,
                      totalOwedNgn: b.totalOwedNgn,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: onAddForTab,
                          icon: const Icon(Icons.add),
                          label: Text(
                            _tabIndex == 0
                                ? 'Add Measurement'
                                : _tabIndex == 1
                                    ? 'New Order'
                                    : 'Add Payment',
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _MeasurementsTab(
                            customerId: c.id,
                            measurements: b.measurements,
                            onEditField: (field, currentValue) async {
                              final existing = b.measurements;
                              if (existing == null) return;
                              await _editMeasurementField(
                                existing: existing,
                                label: field,
                                currentValue: currentValue,
                              );
                            },
                          ),
                          _OrdersTab(
                            layer: widget.layer,
                            customer: c,
                            orders: b.orders,
                            onChanged: _reload,
                          ),
                          _PaymentsTab(
                            layer: widget.layer,
                            payments: b.payments,
                            onChanged: _reload,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _onTabChanged() {
    final controller = _tabController;
    if (controller == null) return;
    if (_tabIndex == controller.index) return;
    setState(() => _tabIndex = controller.index);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.customer,
    required this.totalOwedNgn,
  });

  final Customer customer;
  final int totalOwedNgn;

  @override
  Widget build(BuildContext context) {
    final phone = (customer.phone?.trim().isNotEmpty == true)
        ? customer.phone!.trim()
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            customer.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text('Phone: ${phone ?? '—'}'),
          const SizedBox(height: 4),
          Text(
            'Total Owed: ${formatNgn(totalOwedNgn)}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: totalOwedNgn > 0 ? AppTheme.oweRed : AppTheme.accentGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurementsTab extends StatelessWidget {
  const _MeasurementsTab({
    required this.customerId,
    required this.measurements,
    required this.onEditField,
  });

  final String customerId;
  final MeasurementProfile? measurements;
  final Future<void> Function(String field, double currentValue) onEditField;

  @override
  Widget build(BuildContext context) {
    final m = measurements;
    if (m == null) {
      return const Center(child: Text('No measurements yet.'));
    }
    final rows = <(String, double?)>[
      ('Chest', m.chest),
      ('Waist', m.waist),
      ('Hip', m.hip),
      ('Shoulder', m.shoulder),
      ('Sleeve', m.sleeve),
      ('Length', m.length),
    ].where((e) => e.$2 != null).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length + (m.notes?.trim().isNotEmpty == true ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i < rows.length) {
          final r = rows[i];
          return ListTile(
            title: Text(r.$1),
            trailing: Text(r.$2!.toString()),
            onTap: () => onEditField(r.$1, r.$2!),
          );
        }
        return ListTile(
          title: const Text('Notes'),
          subtitle: Text(m.notes!.trim()),
        );
      },
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({
    required this.layer,
    required this.customer,
    required this.orders,
    required this.onChanged,
  });

  final DataLayer layer;
  final Customer customer;
  final List<OrderMoneyView> orders;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(child: Text('No orders yet.'));
    }
    final l10n = MaterialLocalizations.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final o = orders[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${o.order.title} - ${formatNgn(o.order.agreedAmountNgn)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text('Paid: ${formatNgn(o.paidNgn)}'),
                Text(
                  'Balance: ${formatNgn(o.balanceNgn)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: o.balanceNgn > 0
                        ? AppTheme.oweRed
                        : AppTheme.accentGreen,
                  ),
                ),
                Text('Due: ${l10n.formatMediumDate(o.order.dueDate)}'),
                Row(
                  children: [
                    const Text('Status: '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<OrderStatus>(
                        initialValue: o.order.status,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: OrderStatus.values
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) async {
                          if (v == null || v == o.order.status) return;
                          await layer.orders.updateOrder(
                            OrderRow(
                              id: o.order.id,
                              customerId: o.order.customerId,
                              title: o.order.title,
                              fabricNote: o.order.fabricNote,
                              dueDate: o.order.dueDate,
                              status: v,
                              agreedAmountNgn: o.order.agreedAmountNgn,
                              createdAt: o.order.createdAt,
                              updatedAt: o.order.updatedAt,
                            ),
                          );
                          await onChanged();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton(
                      onPressed: () async {
                        final ok = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => EditOrderScreen(
                              layer: layer,
                              order: o.order,
                            ),
                          ),
                        );
                        if (ok == true) await onChanged();
                      },
                      child: const Text('Edit'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final msg = WhatsAppTemplates.dressReady(
                          customerName: customer.name,
                          styleTitle: o.order.title,
                        );
                        final ok = await openWhatsAppText(
                          rawPhone: customer.phone,
                          message: msg,
                        );
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Add a phone number to send WhatsApp.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Order ready'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: o.balanceNgn > 0
                          ? () async {
                              final msg = WhatsAppTemplates.paymentReminder(
                                customerName: customer.name,
                                balanceText: formatNgn(o.balanceNgn),
                              );
                              final ok = await openWhatsAppText(
                                rawPhone: customer.phone,
                                message: msg,
                              );
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Add a phone number to send WhatsApp.',
                                    ),
                                  ),
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Remind payment'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({
    required this.layer,
    required this.payments,
    required this.onChanged,
  });

  final DataLayer layer;
  final List<Payment> payments;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const Center(child: Text('No payments yet.'));
    }
    final l10n = MaterialLocalizations.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = payments[i];
        return ListTile(
          title: Text(
              '${formatNgn(p.amountNgn)} - ${l10n.formatShortDate(p.paidAt)}'),
          subtitle:
              (p.note?.trim().isNotEmpty == true) ? Text(p.note!.trim()) : null,
          trailing: const Icon(Icons.edit_outlined),
          onTap: () async {
            final ok = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => EditPaymentScreen(layer: layer, payment: p),
              ),
            );
            if (ok == true) await onChanged();
          },
        );
      },
    );
  }
}

class _Bundle {
  const _Bundle({
    required this.customer,
    required this.measurements,
    required this.orders,
    required this.payments,
    required this.totalOwedNgn,
  });

  const _Bundle.missing()
      : customer = null,
        measurements = null,
        orders = const [],
        payments = const [],
        totalOwedNgn = 0;

  final Customer? customer;
  final MeasurementProfile? measurements;
  final List<OrderMoneyView> orders;
  final List<Payment> payments;
  final int totalOwedNgn;
}
