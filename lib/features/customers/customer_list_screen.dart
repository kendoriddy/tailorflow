import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_layer.dart';
import '../../data/data_layer_provider.dart';
import '../../data/models/customer_list_item.dart';
import '../notifications/notifications_screen.dart';
import '../settings/backup_screen.dart';
import '../settings/settings_screen.dart';
import 'add_customer_screen.dart';
import 'customer_profile_screen.dart';

enum CustomerListMode { recent, alphabetical, dueFirst }

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _search = TextEditingController();
  String _query = '';
  CustomerListMode _listMode = CustomerListMode.recent;
  bool _didScheduleDueToast = false;

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
        _maybeShowDueToast(layer);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Customers'),
            actions: [
              FutureBuilder<int>(
                future: layer.notifications.unreadCount(),
                builder: (context, snap) {
                  final unread = snap.data ?? 0;
                  return IconButton(
                    tooltip: unread > 0
                        ? 'Notifications ($unread unread)'
                        : 'Notifications',
                    onPressed: () async {
                      await _openNotifications(layer);
                    },
                    icon: _NotificationBadge(unread: unread),
                  );
                },
              ),
              PopupMenuButton<CustomerListMode>(
                tooltip: 'Sort customers',
                icon: const Icon(Icons.filter_list),
                initialValue: _listMode,
                onSelected: (value) => setState(() => _listMode = value),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: CustomerListMode.recent,
                    child: Text('Recently updated'),
                  ),
                  PopupMenuItem(
                    value: CustomerListMode.alphabetical,
                    child: Text('Alphabetical (A-Z)'),
                  ),
                  PopupMenuItem(
                    value: CustomerListMode.dueFirst,
                    child: Text('Due orders first'),
                  ),
                ],
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
                    final rows = _applyListMode(snap.data!);
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (c.hasDueSoonOrder)
                                  Icon(
                                    Icons.schedule,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
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

  List<CustomerListItem> _applyListMode(List<CustomerListItem> input) {
    final rows = [...input];
    switch (_listMode) {
      case CustomerListMode.recent:
        return rows;
      case CustomerListMode.alphabetical:
        rows.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        return rows;
      case CustomerListMode.dueFirst:
        rows.sort((a, b) {
          final aRank = a.hasDueSoonOrder ? 0 : 1;
          final bRank = b.hasDueSoonOrder ? 0 : 1;
          if (aRank != bRank) return aRank.compareTo(bRank);

          final aDueMs = a.nextDueOrderDate?.millisecondsSinceEpoch ??
              DateTime(9999).millisecondsSinceEpoch;
          final bDueMs = b.nextDueOrderDate?.millisecondsSinceEpoch ??
              DateTime(9999).millisecondsSinceEpoch;
          if (aDueMs != bDueMs) return aDueMs.compareTo(bDueMs);

          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return rows;
    }
  }

  Future<void> _openNotifications(
    DataLayer layer, {
    NotificationListFilter initialFilter = NotificationListFilter.all,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            NotificationsScreen(layer: layer, initialFilter: initialFilter),
      ),
    );
    if (mounted) setState(() {});
  }

  void _maybeShowDueToast(DataLayer layer) {
    if (_didScheduleDueToast) return;
    _didScheduleDueToast = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(() async {
        final dueUnread = await layer.notifications.unreadDueCount();
        if (!mounted || dueUnread <= 0) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$dueUnread order notification${dueUnread == 1 ? '' : 's'} due soon.',
            ),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                unawaited(
                  _openNotifications(
                    layer,
                    initialFilter: NotificationListFilter.dueOnly,
                  ),
                );
              },
            ),
          ),
        );
      }());
    });
  }
}

class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_outlined),
        if (unread > 0)
          Positioned(
            right: -7,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(999),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
