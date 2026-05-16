import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/brand.dart';
import '../../data/billing/remote_flags.dart';
import '../../data/data_layer.dart';
import 'backup_screen.dart';
import 'feedback_screen.dart';

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

  Future<void> _syncNow() async {
    final report = await widget.layer.sync.flushOutbox();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(report.message)),
    );
    await _reload();
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
        message: 'Cloud backup is not configured for this build.',
      );
    }

    final user = client.auth.currentUser;
    if (user == null) {
      return const _SyncIdentity(
        configured: true,
        userId: null,
        shopId: null,
        message: 'Sign in to sync across devices.',
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
            ? 'Signed in, but your shop is not linked yet.'
            : 'Your data can sync to the cloud.',
      );
    } catch (e) {
      return _SyncIdentity(
        configured: true,
        userId: user.id,
        shopId: null,
        message: 'Could not verify shop link: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SettingsSectionHeader('Help & feedback'),
          Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ListTile(
              leading: Icon(
                Icons.feedback_outlined,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Send feedback'),
              subtitle: const Text('Bugs, ideas, and requests for the team'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openFeedbackScreen(context),
            ),
          ),
          const _SettingsSectionHeader('Cloud sync'),
          FutureBuilder<_SyncIdentity>(
            future: _syncIdentity,
            builder: (context, snap) {
              final info = snap.data;
              if (info == null) {
                return const ListTile(
                  title: Text('Sync status'),
                  subtitle: Text('Checking…'),
                  trailing: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final ok =
                  info.configured && info.userId != null && info.shopId != null;
              final chipLabel = ok ? 'Connected' : 'Attention';
              final chipColor = ok ? Colors.green : Colors.orange;
              final subtitle = kDebugMode
                  ? [
                      info.message,
                      if (info.userId != null) 'User: ${info.userId}',
                      if (info.shopId != null) 'Shop: ${info.shopId}',
                    ].join('\n')
                  : info.message;
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
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('Sync now'),
            subtitle: const Text('Upload pending changes when you are online'),
            onTap: _syncNow,
          ),
          const _SettingsSectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            subtitle: const Text('Sign out from this device'),
            onTap: () async {
              try {
                final client = Supabase.instance.client;
                await client.auth.signOut();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out.')),
                );
                await _reload();
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Cloud sign-in is not configured for this build.',
                    ),
                  ),
                );
              }
            },
          ),
          const _SettingsSectionHeader('Legal'),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('Privacy policy'),
            subtitle: const Text('How we handle customer and shop data'),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: () async {
              final uri = Uri.parse(Brand.privacyPolicyUrl);
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Could not open privacy policy. Visit ${Brand.privacyPolicyUrl}',
                    ),
                  ),
                );
              }
            },
          ),
          if (kDebugMode) ...[
            const _SettingsSectionHeader('Developer'),
            const ListTile(
              title: Text('Paywall flag (compile-time)'),
              subtitle: Text(
                RemoteFlags.paywallEnabled
                    ? 'REMOTE_PAYWALL=true at build time'
                    : 'REMOTE_PAYWALL=false (default)',
              ),
            ),
            FutureBuilder<bool>(
              future: _subscribed,
              builder: (context, snap) {
                final v = snap.data ?? false;
                return SwitchListTile(
                  title: const Text('Subscribed (local stub)'),
                  subtitle: const Text(
                    'Pilot testing only — production uses Paystack webhooks.',
                  ),
                  value: v,
                  onChanged: (nv) async {
                    await widget.layer.settings.setSubscribed(nv);
                    await _reload();
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backup & sync diagnostics'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => BackupScreen(layer: widget.layer),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
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
