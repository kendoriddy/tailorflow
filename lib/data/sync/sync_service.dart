import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../billing/plan_limits_service.dart';
import '../billing/subscription_service.dart';
import '../db/app_database.dart';
import 'sync_conflict.dart';
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
    PlanLimitsService? planLimits,
    SubscriptionService? subscriptions,
  })  : _db = db,
        _outbox = outbox,
        _connectivity = connectivity,
        _planLimits = planLimits,
        _subscriptions = subscriptions;

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final Connectivity _connectivity;
  final PlanLimitsService? _planLimits;
  final SubscriptionService? _subscriptions;

  static const int _remotePageSize = 1000;

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
      await _planLimits?.refreshFromRemote();
      await _subscriptions?.syncEntitlement();
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

  /// Older outbox rows omitted [created_at] on updates; Supabase requires it on upsert.
  Future<Map<String, dynamic>> _hydrateCreatedAt({
    required String table,
    required Map<String, dynamic> payload,
  }) async {
    if (payload['created_at'] != null) return payload;
    final id = payload['id'] as String?;
    if (id != null) {
      final rows = await _db.raw.query(
        table,
        columns: ['created_at'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isNotEmpty && rows.first['created_at'] != null) {
        return <String, dynamic>{
          ...payload,
          'created_at': rows.first['created_at'],
        };
      }
    }
    final fallback =
        payload['updated_at'] ?? DateTime.now().millisecondsSinceEpoch;
    return <String, dynamic>{...payload, 'created_at': fallback};
  }

  /// Older outbox rows omitted [updated_at] for payments; use the local row or
  /// payment date so conflict checks can still compare against remote state.
  Future<Map<String, dynamic>> _hydrateUpdatedAt({
    required String table,
    required Map<String, dynamic> payload,
    Object? fallbackTimestamp,
  }) async {
    if (payload['updated_at'] != null) return payload;
    final id = payload['id'] as String?;
    if (id != null) {
      final rows = await _db.raw.query(
        table,
        columns: ['updated_at'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isNotEmpty && rows.first['updated_at'] != null) {
        return <String, dynamic>{
          ...payload,
          'updated_at': rows.first['updated_at'],
        };
      }
    }
    final fallback = fallbackTimestamp ?? DateTime.now().millisecondsSinceEpoch;
    return <String, dynamic>{...payload, 'updated_at': fallback};
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
        final hydrated =
            await _hydrateCreatedAt(table: 'customers', payload: payload);
        if (await _remoteHasNewerVersion(
          client,
          table: 'customers',
          id: hydrated['id'],
          localTimestamp: hydrated['updated_at'],
        )) {
          debugPrint('Skipped stale customer sync op for ${hydrated['id']}');
          break;
        }
        await client.from('customers').upsert(
              _payloadWithShop(
                hydrated,
                shopId,
              ),
            );
        break;
      case 'upsertMeasurement':
        if (await _remoteHasNewerVersion(
          client,
          table: 'measurement_profiles',
          id: payload['id'],
          localTimestamp: payload['updated_at'],
        )) {
          debugPrint('Skipped stale measurement sync op for ${payload['id']}');
          break;
        }
        await client
            .from('measurement_profiles')
            .upsert(_payloadWithShop(payload, shopId));
        break;
      case 'upsertOrder':
        final hydrated =
            await _hydrateCreatedAt(table: 'orders', payload: payload);
        if (await _remoteHasNewerVersion(
          client,
          table: 'orders',
          id: hydrated['id'],
          localTimestamp: hydrated['updated_at'],
        )) {
          debugPrint('Skipped stale order sync op for ${hydrated['id']}');
          break;
        }
        await client.from('orders').upsert(
              _payloadWithShop(
                hydrated,
                shopId,
              ),
            );
        break;
      case 'upsertPayment':
        final hydrated = await _hydrateUpdatedAt(
          table: 'payments',
          payload: payload,
          fallbackTimestamp: payload['paid_at'],
        );
        if (await _remoteHasNewerVersion(
          client,
          table: 'payments',
          id: hydrated['id'],
          localTimestamp: hydrated['updated_at'],
        )) {
          debugPrint('Skipped stale payment sync op for ${hydrated['id']}');
          break;
        }
        await client
            .from('payments')
            .upsert(_payloadWithShop(hydrated, shopId));
        break;
      case 'upsertOrderAttachment':
        await client
            .from('order_attachments')
            .upsert(_payloadWithShop(payload, shopId));
        break;
      case 'deleteCustomer':
        final deletedAt = payload['updated_at'] ?? payload['deleted_at'];
        if (await _remoteHasNewerVersion(
          client,
          table: 'customers',
          id: payload['id'],
          localTimestamp: deletedAt,
        )) {
          debugPrint('Skipped stale customer delete for ${payload['id']}');
          break;
        }
        await client
            .from('customers')
            .update({
              'deleted_at': payload['deleted_at'],
              'updated_at': deletedAt,
            })
            .eq('id', payload['id'] as String);
        break;
      default:
        debugPrint('Unknown outbox op: $type');
    }
  }

  Future<bool> _remoteHasNewerVersion(
    SupabaseClient client, {
    required String table,
    required Object? id,
    required Object? localTimestamp,
  }) async {
    final rowId = id as String?;
    if (rowId == null) return false;
    final row = await client
        .from(table)
        .select('updated_at')
        .eq('id', rowId)
        .maybeSingle();
    return remoteTimestampWins(
      remoteTimestamp: row?['updated_at'],
      localTimestamp: localTimestamp,
    );
  }

  Future<int> _pullFromRemote(SupabaseClient client) async {
    var total = 0;
    total += await _pullCustomers(client);
    total += await _pullMeasurementProfiles(client);
    total += await _pullOrders(client);
    total += await _pullPayments(client);
    total += await _pullOrderAttachments(client);
    return total;
  }

  @visibleForTesting
  static Future<List<dynamic>> collectPagedRows({
    required Future<List<dynamic>> Function(int from, int to) fetchPage,
    int pageSize = _remotePageSize,
  }) async {
    if (pageSize <= 0) {
      throw ArgumentError.value(pageSize, 'pageSize', 'must be positive');
    }

    final allRows = <dynamic>[];
    var from = 0;
    while (true) {
      final to = from + pageSize - 1;
      final rows = await fetchPage(from, to);
      allRows.addAll(rows);
      if (rows.length < pageSize) {
        return allRows;
      }
      from += pageSize;
    }
  }

  Future<List<dynamic>> _selectAllRemoteRows(
    SupabaseClient client, {
    required String table,
    required String columns,
  }) {
    return collectPagedRows(
      fetchPage: (from, to) async {
        return (await client
            .from(table)
            .select(columns)
            .order('id')
            .range(from, to)) as List<dynamic>;
      },
    );
  }

  Future<int> _pullCustomers(SupabaseClient client) async {
    final rows = await _selectAllRemoteRows(
      client,
      table: 'customers',
      columns:
          'id, name, phone, phone_norm, birth_day, birth_month, birth_year, birthday_consent, created_at, updated_at, deleted_at',
    );
    for (final row in rows) {
      final m = row as Map<String, dynamic>;
      await _db.raw.insert(
        'customers',
        {
          'id': m['id'],
          'name': m['name'],
          'phone': m['phone'],
          'phone_norm': m['phone_norm'] ?? '',
          'birth_day': m['birth_day'],
          'birth_month': m['birth_month'],
          'birth_year': m['birth_year'],
          'birthday_consent': m['birthday_consent'] ?? 0,
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
    final rows = await _selectAllRemoteRows(
      client,
      table: 'measurement_profiles',
      columns:
          'id, customer_id, label, chest, waist, hip, length, sleeve, shoulder, neck, inseam, notes, updated_at',
    );
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
    final rows = await _selectAllRemoteRows(
      client,
      table: 'orders',
      columns:
          'id, customer_id, title, fabric_note, due_date, status, agreed_amount_ngn, created_at, updated_at',
    );
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
    final rows = await _selectAllRemoteRows(
      client,
      table: 'payments',
      columns: 'id, order_id, amount_ngn, paid_at, updated_at, note',
    );
    for (final row in rows) {
      final m = row as Map<String, dynamic>;
      await _db.raw.insert(
        'payments',
        {
          'id': m['id'],
          'order_id': m['order_id'],
          'amount_ngn': m['amount_ngn'],
          'paid_at': m['paid_at'],
          'updated_at': m['updated_at'] ?? m['paid_at'],
          'note': m['note'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    return rows.length;
  }

  Future<int> _pullOrderAttachments(SupabaseClient client) async {
    final rows = await _selectAllRemoteRows(
      client,
      table: 'order_attachments',
      columns: 'id, order_id, image_base64, mime_type, created_at',
    );
    for (final row in rows) {
      final m = row as Map<String, dynamic>;
      await _db.raw.insert(
        'order_attachments',
        {
          'id': m['id'],
          'order_id': m['order_id'],
          'image_base64': m['image_base64'],
          'mime_type': m['mime_type'] ?? 'image/jpeg',
          'created_at': m['created_at'],
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
