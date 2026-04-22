import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/app_database.dart';
import 'outbox_repository.dart';

/// Flushes local outbox when connectivity returns. Remote sink is optional
/// (Supabase) and degrades gracefully when not configured.
class SyncService {
  SyncService({
    required AppDatabase db,
    required OutboxRepository outbox,
    required Connectivity connectivity,
  }) : _db = db,
       _outbox = outbox,
       _connectivity = connectivity;

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _flushing = false;

  void start() {
    _sub?.cancel();
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) {
        unawaited(flushOutbox());
      }
    });
    unawaited(flushOutbox());
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Exposed for UI "Sync now" without waiting on connectivity changes.
  Future<void> flushOutbox() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final client = _maybeSupabase();
      if (client == null) {
        // Keep outbox pending until Supabase is configured; avoids dropping events.
        return;
      }
      final ops = await _outbox.pendingOps();
      for (final op in ops) {
        final id = op['id']! as String;
        try {
          await _applyRemote(client, op);
          await _outbox.markProcessed(id);
        } catch (e, st) {
          debugPrint('TailorFlow sync failed: $e\n$st');
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  SupabaseClient? _maybeSupabase() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Minimal example mapping: requires matching tables in Supabase project.
  Future<void> _applyRemote(SupabaseClient client, Map<String, Object?> op) async {
    final type = op['op_type']! as String;
    final payload =
        jsonDecode(op['payload']! as String) as Map<String, dynamic>;

    switch (type) {
      case 'upsertCustomer':
        await client.from('customers').upsert(payload);
        break;
      case 'upsertMeasurement':
        await client.from('measurement_profiles').upsert(payload);
        break;
      case 'upsertOrder':
        await client.from('orders').upsert(payload);
        break;
      case 'upsertPayment':
        await client.from('payments').upsert(payload);
        break;
      case 'deleteCustomer':
        await client
            .from('customers')
            .update({'deleted_at': payload['deleted_at']})
            .eq('id', payload['id'] as String);
        break;
      default:
        debugPrint('Unknown outbox op: $type');
    }
  }
}
