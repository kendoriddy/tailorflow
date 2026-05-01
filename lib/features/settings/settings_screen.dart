import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _subscribed = widget.layer.settings.isSubscribed();
  }

  Future<void> _reload() async {
    setState(() => _subscribed = widget.layer.settings.isSubscribed());
    await _subscribed;
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
          const ListTile(
            title: Text('Privacy'),
            subtitle: Text('See docs/PRIVACY_PILOT.md in the repository.'),
          ),
        ],
      ),
    );
  }
}
