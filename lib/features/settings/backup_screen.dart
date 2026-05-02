import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/data_layer.dart';

/// Optional backup/sync entry point.
///
/// Full phone OTP flows are product work; this screen documents the intended
/// behavior and validates that Supabase is configured when dart-defines are set.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.layer});

  final DataLayer layer;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _sendOtpStub() async {
    setState(() => _busy = true);
    try {
      // MVP: no OTP transport wired here. When Supabase Auth is enabled, replace
      // this with signInWithOtp using the E.164 formatted phone number.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final report = await widget.layer.sync.flushOutbox();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'OTP sending is not wired in this MVP build. '
            'Configure Supabase Auth + SMS provider, then call signInWithOtp. '
            '${report.message}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    SupabaseClient? client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      client = null;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & sync')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              'Cloud backup is optional. Without Supabase keys, everything stays on this phone.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Supabase status'),
              subtitle: Text(
                client == null
                    ? 'Not initialized. Pass SUPABASE_URL and SUPABASE_ANON_KEY.'
                    : 'Initialized. Outbox sync will attempt upserts when online.',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(
                labelText: 'Phone (E.164 recommended)',
                hintText: '2348012345678',
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _sendOtpStub,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send OTP (stub)'),
            ),
            const SizedBox(height: 16),
            Text(
              'Next steps for production:\n'
              '• Enable Supabase Auth phone provider.\n'
              '• Map authenticated user to shop_id.\n'
              '• Apply RLS policies from supabase/migrations.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
