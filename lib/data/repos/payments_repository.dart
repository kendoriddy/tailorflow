import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/payment.dart';
import '../sync/outbox_repository.dart';

class PaymentsRepository {
  PaymentsRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxRepository _outbox;

  static const _uuid = Uuid();

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
}
