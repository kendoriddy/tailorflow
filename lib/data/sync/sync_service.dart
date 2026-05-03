import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/app_database.dart';
import 'outbox_repository.dart';

class SyncReport {
  const SyncReport({
    required this.success,
    required this.message,
    this.pushed = 0,
    this.pulled = 0,
    this.pending = 0,
  });

  final bool success;
  final String message;
  final int pushed;
  final int pulled;
  final int pending;
}

/// Flushes local outbox when connectivity returns. Remote sink is optional
/// (Supabase) and degrades gracefully when not configured.
class SyncService {
  SyncService({
    required AppDatabase db,
    required OutboxRepository outbox,
    required Connectivity connectivity,
  })  : _db = db,
        _outbox = outbox,
        _connectivity = connectivity;

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _timer;
  bool _flushing = false;

  void start() {
    _timer?.cancel();
    _sub?.cancel();
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) {
        unawaited(flushOutbox());
      }
    });
    _timer = Timer.periodic(const Duration(minutes: 2), (_) {
      unawaited(flushOutbox());
    });
    unawaited(flushOutbox());
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _sub?.cancel();
    _sub = null;
  }

  /// Exposed for UI "Sync now" without waiting on connectivity changes.
  Future<SyncReport> flushOutbox() async {
    if (_flushing) {
      final pending = (await _outbox.pendingOps()).length;
      return SyncReport(
        success: true,
        message: 'Sync already in progress.',
        pending: pending,
      );
    }
    final connectivity = await _connectivity.checkConnectivity();
    final isOnline = connectivity.any((r) => r != ConnectivityResult.none);
    if (!isOnline) {
      final pending = (await _outbox.pendingOps()).length;
      return SyncReport(
        success: false,
        message: 'No network. Pending sync items: $pending.',
        pending: pending,
      );
    }

    _flushing = true;
    try {
      final client = _maybeSupabase();
      if (client == null) {
        // Keep outbox pending until Supabase is configured; avoids dropping events.
        final pending = (await _outbox.pendingOps()).length;
        return SyncReport(
          success: false,
          message:
              'Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY.',
          pending: pending,
        );
      }
      final shopId = await _resolveShopIdForSync(client);
      if (shopId == null) {
        final pending = (await _outbox.pendingOps()).length;
        return SyncReport(
          success: false,
          message: 'Sync failed: no shop linked to this account. '
              'In Supabase: enable Anonymous sign-in, apply migrations, '
              'and ensure RPC bootstrap_current_user_shop runs (open the app after a fresh install).',
          pending: pending,
        );
      }

      final ops = await _outbox.pendingOps();
      var pushed = 0;
      for (final op in ops) {
        final id = op['id']! as String;
        try {
          await _applyRemote(client, op, shopId);
          await _outbox.markProcessed(id);
          pushed++;
        } catch (e, st) {
          debugPrint('TailorFlow sync failed: $e\n$st');
          final pending = (await _outbox.pendingOps()).length;
          return SyncReport(
            success: false,
            message: 'Sync failed: ${_toReadableError(e)}',
            pushed: pushed,
            pending: pending,
          );
        }
      }
      final pulled = await _pullFromRemote(client);
      final pending = (await _outbox.pendingOps()).length;
      return SyncReport(
        success: true,
        message:
            'Sync complete. Uploaded $pushed change${pushed == 1 ? '' : 's'}, downloaded $pulled row${pulled == 1 ? '' : 's'}.',
        pushed: pushed,
        pulled: pulled,
        pending: pending,
      );
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

  /// Ensures [shop_memberships] has a row, then returns that [shop_id] for RLS-safe upserts.
  ///
  /// Outbox payloads omit [shop_id] (local SQLite has no tenant column). PostgREST upserts
  /// still must satisfy `with check` on [customers] and related tables — supplying [shop_id]
  /// explicitly avoids "new row violates row-level security policy" when defaults or conflict
  /// updates do not line up with the signed-in user's shop.
  Future<String?> _resolveShopIdForSync(SupabaseClient client) async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    try {
      await client.rpc('bootstrap_current_user_shop');
    } catch (e) {
      debugPrint('TailorFlow bootstrap_current_user_shop: $e');
    }
    try {
      final rows = (await client
          .from('shop_memberships')
          .select('shop_id')
          .eq('user_id', user.id)
          .limit(1)) as List<dynamic>;
      if (rows.isEmpty) return null;
      final raw = (rows.first as Map<String, dynamic>)['shop_id'];
      if (raw == null) return null;
      return '$raw';
    } catch (e) {
      debugPrint('TailorFlow resolve shop_id: $e');
      return null;
    }
  }

  Map<String, dynamic> _payloadWithShop(
    Map<String, dynamic> payload,
    String shopId,
  ) {
    return <String, dynamic>{...payload, 'shop_id': shopId};
  }

  /// Minimal example mapping: requires matching tables in Supabase project.
  Future<void> _applyRemote(
    SupabaseClient client,
    Map<String, Object?> op,
    String shopId,
  ) async {
    final type = op['op_type']! as String;
    final payload =
        jsonDecode(op['payload']! as String) as Map<String, dynamic>;

    switch (type) {
      case 'upsertCustomer':
        await client
            .from('customers')
            .upsert(_payloadWithShop(payload, shopId));
        break;
      case 'upsertMeasurement':
        await client
            .from('measurement_profiles')
            .upsert(_payloadWithShop(payload, shopId));
        break;
      case 'upsertOrder':
        await client.from('orders').upsert(_payloadWithShop(payload, shopId));
        break;
      case 'upsertPayment':
        await client.from('payments').upsert(_payloadWithShop(payload, shopId));
        break;
      case 'deleteCustomer':
        await client
            .from('customers')
            .update({'deleted_at': payload['deleted_at']}).eq(
                'id', payload['id'] as String);
        break;
      default:
        debugPrint('Unknown outbox op: $type');
    }
  }

  Future<int> _pullFromRemote(SupabaseClient client) async {
    var total = 0;
    total += await _pullCustomers(client);
    total += await _pullMeasurementProfiles(client);
    total += await _pullOrders(client);
    total += await _pullPayments(client);
    return total;
  }

  Future<int> _pullCustomers(SupabaseClient client) async {
    final rows = (await client.from('customers').select(
          'id, name, phone, phone_norm, created_at, updated_at, deleted_at',
        )) as List<dynamic>;
    for (final row in rows) {
      final m = row as Map<String, dynamic>;
      await _db.raw.insert(
        'customers',
        {
          'id': m['id'],
          'name': m['name'],
          'phone': m['phone'],
          'phone_norm': m['phone_norm'] ?? '',
          'created_at': m['created_at'],
          'updated_at': m['updated_at'],
          'deleted_at': m['deleted_at'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    return rows.length;
  }

  Future<int> _pullMeasurementProfiles(SupabaseClient client) async {
    final rows = (await client.from('measurement_profiles').select(
          'id, customer_id, label, chest, waist, hip, length, sleeve, shoulder, neck, inseam, notes, updated_at',
        )) as List<dynamic>;
    for (final row in rows) {
      final m = row as Map<String, dynamic>;
      await _db.raw.insert(
        'measurement_profiles',
        {
          'id': m['id'],
          'customer_id': m['customer_id'],
          'label': m['label'],
          'chest': m['chest'],
          'waist': m['waist'],
          'hip': m['hip'],
          'length': m['length'],
          'sleeve': m['sleeve'],
          'shoulder': m['shoulder'],
          'neck': m['neck'],
          'inseam': m['inseam'],
          'notes': m['notes'],
          'updated_at': m['updated_at'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    return rows.length;
  }

  Future<int> _pullOrders(SupabaseClient client) async {
    final rows = (await client.from('orders').select(
          'id, customer_id, title, fabric_note, due_date, status, agreed_amount_ngn, created_at, updated_at',
        )) as List<dynamic>;
    for (final row in rows) {
      final m = row as Map<String, dynamic>;
      await _db.raw.insert(
        'orders',
        {
          'id': m['id'],
          'customer_id': m['customer_id'],
          'title': m['title'],
          'fabric_note': m['fabric_note'],
          'due_date': m['due_date'],
          'status': m['status'],
          'agreed_amount_ngn': m['agreed_amount_ngn'],
          'created_at': m['created_at'],
          'updated_at': m['updated_at'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    return rows.length;
  }

  Future<int> _pullPayments(SupabaseClient client) async {
    final rows = (await client.from('payments').select(
          'id, order_id, amount_ngn, paid_at, note',
        )) as List<dynamic>;
    for (final row in rows) {
      final m = row as Map<String, dynamic>;
      await _db.raw.insert(
        'payments',
        {
          'id': m['id'],
          'order_id': m['order_id'],
          'amount_ngn': m['amount_ngn'],
          'paid_at': m['paid_at'],
          'note': m['note'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    return rows.length;
  }

  String _toReadableError(Object error) {
    if (error is PostgrestException) {
      return error.message;
    }
    final text = error.toString().trim();
    return text.isEmpty ? 'unknown error' : text;
  }
}
