import 'package:flutter/material.dart';

import '../../data/data_layer.dart';
import '../../data/models/in_app_notification.dart';
import '../customers/customer_profile_screen.dart';

enum NotificationListFilter { all, dueOnly }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.layer,
    this.initialFilter = NotificationListFilter.all,
  });

  final DataLayer layer;
  final NotificationListFilter initialFilter;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<InAppNotificationView>> _future;
  late NotificationListFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _future = widget.layer.notifications.listAll(
      dueOnly: _filter == NotificationListFilter.dueOnly,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.layer.notifications.listAll(
        dueOnly: _filter == NotificationListFilter.dueOnly,
      );
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          PopupMenuButton<NotificationListFilter>(
            tooltip: 'Filter notifications',
            initialValue: _filter,
            onSelected: (value) async {
              if (_filter == value) return;
              setState(() => _filter = value);
              await _reload();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: NotificationListFilter.all,
                child: Text('All notifications'),
              ),
              PopupMenuItem(
                value: NotificationListFilter.dueOnly,
                child: Text('Due orders only'),
              ),
            ],
            icon: const Icon(Icons.filter_list),
          ),
          TextButton(
            onPressed: () async {
              await widget.layer.notifications.markAllRead();
              await _reload();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications marked as read.')),
              );
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: FutureBuilder<List<InAppNotificationView>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            final text = _filter == NotificationListFilter.dueOnly
                ? 'No due-order notifications yet.'
                : 'No notifications yet.';
            return Center(child: Text(text));
          }
          return RefreshIndicator(
            onRefresh: () async {
              await widget.layer.notifications.refreshDueReminders();
              await _reload();
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = rows[i];
                final tileColor = n.isUnread
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.06)
                    : null;
                return ListTile(
                  tileColor: tileColor,
                  leading: Icon(
                    n.isUnread
                        ? Icons.mark_email_unread_outlined
                        : Icons.drafts_outlined,
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight:
                          n.isUnread ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  subtitle:
                      Text('${n.body}\n${n.customerName} • ${n.orderTitle}'),
                  isThreeLine: true,
                  trailing: n.isUnread
                      ? const Icon(Icons.fiber_manual_record, size: 10)
                      : const Icon(Icons.done, size: 18),
                  onTap: () async {
                    if (n.isUnread) {
                      await widget.layer.notifications.markRead(n.id);
                    }
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CustomerProfileScreen(
                          layer: widget.layer,
                          customerId: n.customerId,
                        ),
                      ),
                    );
                    await _reload();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
