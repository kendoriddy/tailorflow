import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';

enum OutboxOpType {
  upsertCustomer,
  upsertMeasurement,
  upsertOrder,
  upsertPayment,
  deleteCustomer,
}

class OutboxRepository {
  OutboxRepository(this._db);

  final AppDatabase _db;

  static const _uuid = Uuid();

  Future<void> enqueue({
    required OutboxOpType type,
    required String entityId,
    required Map<String, Object?> payload,
  }) async {
    final id = _uuid.v4();
    await _db.raw.insert('outbox_ops', {
      'id': id,
      'op_type': type.name,
      'entity_id': entityId,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'processed_at': null,
    });
  }

  Future<List<Map<String, Object?>>> pendingOps() async {
    return _db.raw.query(
      'outbox_ops',
      where: 'processed_at IS NULL',
      orderBy: 'created_at ASC',
    );
  }

  Future<void> markProcessed(String id) async {
    await _db.raw.update(
      'outbox_ops',
      {'processed_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
