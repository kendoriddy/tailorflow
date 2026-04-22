import 'package:flutter/material.dart';

import '../../data/data_layer.dart';
import '../../data/models/customer.dart';
import 'customer_detail_screen.dart';

class CustomersTab extends StatefulWidget {
  const CustomersTab({
    super.key,
    required this.layer,
    required this.onRefresh,
    required this.onOpenAddCustomer,
  });

  final DataLayer layer;
  final VoidCallback onRefresh;
  final VoidCallback onOpenAddCustomer;

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  final _controller = TextEditingController();
  String _query = '';
  late Future<List<Customer>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.layer.customers.listActive();
    _controller.addListener(() {
      final q = _controller.text;
      if (q != _query) {
        setState(() {
          _query = q;
          _future = widget.layer.customers.search(q);
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant CustomersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer != widget.layer) {
      _future = widget.layer.customers.search(_query);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Search name or phone',
              prefixIcon: Icon(Icons.search),
            ),
            textInputAction: TextInputAction.search,
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Customer>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = snap.data!;
              if (rows.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 48),
                    const Center(child: Text('No customers yet.')),
                    const SizedBox(height: 16),
                    Center(
                      child: FilledButton.icon(
                        onPressed: widget.onOpenAddCustomer,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Add first customer'),
                      ),
                    ),
                  ],
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _future = widget.layer.customers.search(_query);
                  });
                  widget.onRefresh();
                  await _future;
                },
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = rows[i];
                    return ListTile(
                      title: Text(c.name),
                      subtitle: Text(c.phone?.isNotEmpty == true ? c.phone! : 'No phone'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CustomerDetailScreen(
                              layer: widget.layer,
                              customerId: c.id,
                            ),
                          ),
                        );
                        if (mounted) {
                          setState(() {
                            _future = widget.layer.customers.search(_query);
                          });
                        }
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
