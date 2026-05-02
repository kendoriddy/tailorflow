import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/billing/remote_flags.dart';
import '../../data/data_layer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.layer});

  final DataLayer layer;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<bool> _subscribed;
  late Future<_SyncIdentity> _syncIdentity;

  @override
  void initState() {
    super.initState();
    _subscribed = widget.layer.settings.isSubscribed();
    _syncIdentity = _loadSyncIdentity();
  }

  Future<void> _reload() async {
    setState(() {
      _subscribed = widget.layer.settings.isSubscribed();
      _syncIdentity = _loadSyncIdentity();
    });
    await _subscribed;
  }

  Future<_SyncIdentity> _loadSyncIdentity() async {
    SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      return const _SyncIdentity(
        configured: false,
        userId: null,
        shopId: null,
        message: 'Supabase not configured',
      );
    }

    final user = client.auth.currentUser;
    if (user == null) {
      return const _SyncIdentity(
        configured: true,
        userId: null,
        shopId: null,
        message: 'No signed-in user',
      );
    }

    try {
      final rows = (await client
          .from('shop_memberships')
          .select('shop_id')
          .eq('user_id', user.id)
          .limit(1)) as List<dynamic>;
      String? shopId;
      if (rows.isNotEmpty) {
        final first = rows.first as Map<String, dynamic>;
        final raw = first['shop_id'];
        if (raw != null) shopId = '$raw';
      }
      return _SyncIdentity(
        configured: true,
        userId: user.id,
        shopId: shopId,
        message: shopId == null
            ? 'Signed in, but no shop mapping found'
            : 'Sync identity is active',
      );
    } catch (e) {
      return _SyncIdentity(
        configured: true,
        userId: user.id,
        shopId: null,
        message: 'Could not read shop mapping: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Paywall flag (compile-time)'),
            subtitle: Text(
              RemoteFlags.paywallEnabled
                  ? 'REMOTE_PAYWALL=true at build time'
                  : 'REMOTE_PAYWALL=false (default)',
            ),
          ),
          const Divider(),
          FutureBuilder<bool>(
            future: _subscribed,
            builder: (context, snap) {
              final v = snap.data ?? false;
              return SwitchListTile(
                title: const Text('Subscribed (local stub)'),
                subtitle: const Text(
                  'Used for pilot testing when the paywall is enabled. '
                  'Production should set this from Paystack webhooks.',
                ),
                value: v,
                onChanged: (nv) async {
                  await widget.layer.settings.setSubscribed(nv);
                  await _reload();
                },
              );
            },
          ),
          const Divider(),
          FutureBuilder<_SyncIdentity>(
            future: _syncIdentity,
            builder: (context, snap) {
              final info = snap.data;
              if (info == null) {
                return const ListTile(
                  title: Text('Sync status'),
                  subtitle: Text('Checking Supabase identity...'),
                  trailing: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final ok = info.configured &&
                  info.userId != null &&
                  info.shopId != null;
              final chipLabel = ok ? 'Connected' : 'Attention';
              final chipColor = ok ? Colors.green : Colors.orange;
              final subtitle = [
                info.message,
                if (info.userId != null) 'User: ${info.userId}',
                if (info.shopId != null) 'Shop: ${info.shopId}',
              ].join('\n');
              return ListTile(
                title: const Text('Sync status'),
                subtitle: Text(subtitle),
                trailing: Chip(
                  label: Text(chipLabel),
                  backgroundColor: chipColor.withOpacity(0.15),
                  side: BorderSide(color: chipColor.withOpacity(0.5)),
                  labelStyle: TextStyle(color: chipColor.shade700),
                ),
              );
            },
          ),
          const Divider(),
          const ListTile(
            title: Text('Privacy'),
            subtitle: Text('See docs/PRIVACY_PILOT.md in the repository.'),
          ),
        ],
      ),
    );
  }
}

class _SyncIdentity {
  const _SyncIdentity({
    required this.configured,
    required this.userId,
    required this.shopId,
    required this.message,
  });

  final bool configured;
  final String? userId;
  final String? shopId;
  final String message;
}
