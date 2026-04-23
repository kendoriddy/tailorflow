import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/payment.dart';
import '../sync/outbox_repository.dart';

class PaymentsRepository {
  PaymentsRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxRepository _outbox;

  static const _uuid = Uuid();

  Future<Payment?> getById(String id) async {
    final rows =
        await _db.raw.query('payments', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final m = rows.first;
    return Payment(
      id: m['id']! as String,
      orderId: m['order_id']! as String,
      amountNgn: m['amount_ngn']! as int,
      paidAt: DateTime.fromMillisecondsSinceEpoch(m['paid_at']! as int),
      note: m['note'] as String?,
    );
  }

  Future<List<Payment>> listForCustomer(String customerId) async {
    final rows = await _db.raw.rawQuery('''
SELECT p.*
FROM payments p
JOIN orders o ON o.id = p.order_id
WHERE o.customer_id = ?
ORDER BY p.paid_at DESC
''', [customerId]);

    return rows
        .map(
          (m) => Payment(
            id: m['id']! as String,
            orderId: m['order_id']! as String,
            amountNgn: m['amount_ngn']! as int,
            paidAt: DateTime.fromMillisecondsSinceEpoch(m['paid_at']! as int),
            note: m['note'] as String?,
          ),
        )
        .toList();
  }

  Future<List<Payment>> listForOrder(String orderId) async {
    final rows = await _db.raw.query(
      'payments',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'paid_at DESC',
    );
    return rows
        .map(
          (m) => Payment(
            id: m['id']! as String,
            orderId: m['order_id']! as String,
            amountNgn: m['amount_ngn']! as int,
            paidAt: DateTime.fromMillisecondsSinceEpoch(m['paid_at']! as int),
            note: m['note'] as String?,
          ),
        )
        .toList();
  }

  Future<void> insertPayment({
    required String orderId,
    required int amountNgn,
    DateTime? paidAt,
    String? note,
  }) async {
    final id = _uuid.v4();
    final ts = (paidAt ?? DateTime.now()).millisecondsSinceEpoch;
    await _db.raw.insert('payments', {
      'id': id,
      'order_id': orderId,
      'amount_ngn': amountNgn,
      'paid_at': ts,
      'note': note?.trim(),
    });
    await _bumpCustomerUpdatedAtForOrder(orderId);
    await _outbox.enqueue(
      type: OutboxOpType.upsertPayment,
      entityId: id,
      payload: {
        'id': id,
        'order_id': orderId,
        'amount_ngn': amountNgn,
        'paid_at': ts,
        'note': note?.trim(),
      },
    );
  }

  Future<void> updatePayment(Payment p) async {
    await _db.raw.update(
      'payments',
      {
        'amount_ngn': p.amountNgn,
        'paid_at': p.paidAt.millisecondsSinceEpoch,
        'note': p.note?.trim(),
      },
      where: 'id = ?',
      whereArgs: [p.id],
    );
    await _bumpCustomerUpdatedAtForOrder(p.orderId);
    await _outbox.enqueue(
      type: OutboxOpType.upsertPayment,
      entityId: p.id,
      payload: {
        'id': p.id,
        'order_id': p.orderId,
        'amount_ngn': p.amountNgn,
        'paid_at': p.paidAt.millisecondsSinceEpoch,
        'note': p.note?.trim(),
      },
    );
  }

  Future<void> deletePayment(String id) async {
    final existing = await getById(id);
    if (existing == null) return;
    await _db.raw.delete('payments', where: 'id = ?', whereArgs: [id]);
    await _bumpCustomerUpdatedAtForOrder(existing.orderId);
    // v1 core flow is offline-first; deletes are local only for now.
  }

  Future<void> _bumpCustomerUpdatedAtForOrder(String orderId) async {
    final rows = await _db.raw.rawQuery(
      'SELECT customer_id FROM orders WHERE id = ?',
      [orderId],
    );
    if (rows.isEmpty) return;
    final customerId = rows.first['customer_id'] as String?;
    if (customerId == null) return;
    await _db.raw.update(
      'customers',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }
}
