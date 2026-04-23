import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_layer_provider.dart';
import '../../data/models/customer_list_item.dart';
import '../notifications/notifications_screen.dart';
import '../settings/backup_screen.dart';
import '../settings/settings_screen.dart';
import 'add_customer_screen.dart';
import 'customer_profile_screen.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      final q = _search.text;
      if (q != _query) setState(() => _query = q);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dataLayerProvider);
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Could not open database.\n$e')),
      ),
      data: (layer) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Customers'),
            actions: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(layer: layer),
                  ),
                ),
                icon: const Icon(Icons.notifications_outlined),
              ),
              IconButton(
                tooltip: 'Sync now',
                onPressed: () async {
                  await layer.sync.flushOutbox();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Sync check finished. Pending items remain if cloud backup is not configured.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.cloud_sync_outlined),
              ),
              IconButton(
                tooltip: 'Backup & sync',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => BackupScreen(layer: layer)),
                ),
                icon: const Icon(Icons.shield_outlined),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => SettingsScreen(layer: layer)),
                ),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'Search name or phone…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  textInputAction: TextInputAction.search,
                ),
              ),
              Expanded(
                child: FutureBuilder<List<CustomerListItem>>(
                  future: layer.customers.listSummary(query: _query),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final rows = snap.data!;
                    if (rows.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 48),
                          Center(child: Text('No customers yet.')),
                          SizedBox(height: 12),
                          Center(child: Text('Tap “New Customer” to add one.')),
                        ],
                      );
                    }
                    final l10n = MaterialLocalizations.of(context);
                    return RefreshIndicator(
                      onRefresh: () async => setState(() {}),
                      child: ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final c = rows[i];
                          final color =
                              c.statusColor(Theme.of(context).colorScheme);
                          return ListTile(
                            leading: Container(
                              width: 10,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            title: Text(
                              c.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              c.subtitleText(l10n),
                              maxLines: 2,
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CustomerProfileScreen(
                                    layer: layer,
                                    customerId: c.customerId,
                                  ),
                                ),
                              );
                              if (mounted) setState(() {});
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final ok = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => AddCustomerScreen(layer: layer),
                          ),
                        );
                        if (ok == true && mounted) setState(() {});
                      },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('+ New Customer'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
