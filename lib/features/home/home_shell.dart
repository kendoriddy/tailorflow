import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_layer.dart';
import '../../data/data_layer_provider.dart';
import '../customers/add_customer_screen.dart';
import '../customers/customers_tab.dart';
import '../settings/backup_screen.dart';
import '../settings/settings_screen.dart';
import 'dashboard_tab.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  int _tick = 0;

  void _bump() => setState(() => _tick++);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dataLayerProvider);
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        body: Center(child: Text('Could not open database.\n$e')),
      ),
      data: (layer) {
        return _HomeScaffold(
            reloadTick: _tick,
            layer: layer,
            index: _index,
            onNav: (i) => setState(() => _index = i),
            onRefresh: _bump,
            onOpenAddCustomer: () async {
              final ok = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => AddCustomerScreen(layer: layer),
                ),
              );
              if (ok == true && mounted) _bump();
            },
            onOpenSettings: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SettingsScreen(layer: layer)),
            ),
            onOpenBackup: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BackupScreen(layer: layer)),
            ),
            onSyncNow: () => layer.sync.flushOutbox(),
        );
      },
    );
  }
}

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold({
    required this.reloadTick,
    required this.layer,
    required this.index,
    required this.onNav,
    required this.onRefresh,
    required this.onOpenAddCustomer,
    required this.onOpenSettings,
    required this.onOpenBackup,
    required this.onSyncNow,
  });

  final int reloadTick;
  final DataLayer layer;
  final int index;
  final ValueChanged<int> onNav;
  final VoidCallback onRefresh;
  final VoidCallback onOpenAddCustomer;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenBackup;
  final Future<void> Function() onSyncNow;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TailorFlow NG'),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            onPressed: () async {
              await onSyncNow();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Sync check finished. Pending items remain if cloud backup is not configured.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.cloud_sync_outlined),
          ),
          IconButton(
            tooltip: 'Backup & sync',
            onPressed: onOpenBackup,
            icon: const Icon(Icons.shield_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: [
          DashboardTab(
            key: ValueKey('dash_$reloadTick'),
            layer: layer,
            onRefresh: onRefresh,
          ),
          CustomersTab(
            key: ValueKey('cust_$reloadTick'),
            layer: layer,
            onRefresh: onRefresh,
            onOpenAddCustomer: onOpenAddCustomer,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onOpenAddCustomer,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('New customer'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onNav,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Customers',
          ),
        ],
      ),
    );
  }
}
