import 'package:flutter/material.dart';

import '../../data/data_layer.dart';
import '../../data/models/in_app_notification.dart';
import '../customers/customer_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.layer});

  final DataLayer layer;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<InAppNotificationView>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.layer.notifications.listAll();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.layer.notifications.listAll());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await widget.layer.notifications.markAllRead();
              await _reload();
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
            return const Center(child: Text('No notifications yet.'));
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
                return ListTile(
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
                      ? const Icon(Icons.circle, size: 10)
                      : const SizedBox(width: 10),
                  onTap: () async {
                    await widget.layer.notifications.markRead(n.id);
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
