import 'package:uuid/uuid.dart';

import '../../core/utils/money.dart';
import '../db/app_database.dart';
import '../models/order_money_view.dart';
import '../models/order_row.dart';
import '../models/order_status.dart';
import '../sync/outbox_repository.dart';

class OrdersRepository {
  OrdersRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxRepository _outbox;

  static const _uuid = Uuid();

  Future<List<OrderMoneyView>> listMoneyForCustomer(String customerId) async {
    final rows = await _db.raw.rawQuery('''
SELECT o.*,
  IFNULL((SELECT SUM(p.amount_ngn) FROM payments p WHERE p.order_id = o.id), 0) AS paid_ngn,
  MAX(
    o.agreed_amount_ngn - IFNULL((SELECT SUM(p.amount_ngn) FROM payments p WHERE p.order_id = o.id), 0),
    0
  ) AS balance_ngn
FROM orders o
WHERE o.customer_id = ?
ORDER BY o.due_date ASC
''', [customerId]);

    return rows.map((m) {
      final order = _mapOrder(m);
      final paid = (m['paid_ngn'] as num?)?.toInt() ?? 0;
      final bal = (m['balance_ngn'] as num?)?.toInt() ??
          clampNonNegativeBalance(
            agreedAmountNgn: order.agreedAmountNgn,
            paidSumNgn: paid,
          );
      return OrderMoneyView(order: order, paidNgn: paid, balanceNgn: bal);
    }).toList();
  }

  Future<List<OrderRow>> listForCustomer(String customerId) async {
    final rows = await _db.raw.query(
      'orders',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'due_date ASC',
    );
    return rows.map(_mapOrder).toList();
  }

  Future<int> balanceForOrder(String orderId) async {
    final orderRows = await _db.raw.query(
      'orders',
      columns: ['agreed_amount_ngn'],
      where: 'id = ?',
      whereArgs: [orderId],
    );
    if (orderRows.isEmpty) return 0;
    final agreed = orderRows.first['agreed_amount_ngn']! as int;
    final payRows = await _db.raw.rawQuery(
      'SELECT IFNULL(SUM(amount_ngn),0) AS s FROM payments WHERE order_id = ?',
      [orderId],
    );
    final paid = (payRows.first['s'] as int?) ?? 0;
    return clampNonNegativeBalance(agreedAmountNgn: agreed, paidSumNgn: paid);
  }

  Future<String> insertOrder({
    required String customerId,
    required String title,
    String? fabricNote,
    required DateTime dueDate,
    OrderStatus status = OrderStatus.booked,
    required int agreedAmountNgn,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.raw.insert('orders', {
      'id': id,
      'customer_id': customerId,
      'title': title.trim(),
      'fabric_note': fabricNote?.trim(),
      'due_date': dueDate.millisecondsSinceEpoch,
      'status': status.wireName,
      'agreed_amount_ngn': agreedAmountNgn,
      'created_at': now,
      'updated_at': now,
    });
    await _bumpCustomerUpdatedAt(customerId);
    await _outbox.enqueue(
      type: OutboxOpType.upsertOrder,
      entityId: id,
      payload: {
        'id': id,
        'customer_id': customerId,
        'title': title.trim(),
        'fabric_note': fabricNote?.trim(),
        'due_date': dueDate.millisecondsSinceEpoch,
        'status': status.wireName,
        'agreed_amount_ngn': agreedAmountNgn,
        'created_at': now,
        'updated_at': now,
      },
    );
    return id;
  }

  Future<void> updateOrder(OrderRow o) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.raw.update(
      'orders',
      {
        'title': o.title.trim(),
        'fabric_note': o.fabricNote?.trim(),
        'due_date': o.dueDate.millisecondsSinceEpoch,
        'status': o.status.wireName,
        'agreed_amount_ngn': o.agreedAmountNgn,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [o.id],
    );
    await _bumpCustomerUpdatedAt(o.customerId);
    await _outbox.enqueue(
      type: OutboxOpType.upsertOrder,
      entityId: o.id,
      payload: {
        'id': o.id,
        'customer_id': o.customerId,
        'title': o.title.trim(),
        'fabric_note': o.fabricNote?.trim(),
        'due_date': o.dueDate.millisecondsSinceEpoch,
        'status': o.status.wireName,
        'agreed_amount_ngn': o.agreedAmountNgn,
        'updated_at': now,
      },
    );
  }

  Future<void> _bumpCustomerUpdatedAt(String customerId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.raw.update(
      'customers',
      {'updated_at': now},
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  OrderRow _mapOrder(Map<String, Object?> m) {
    return OrderRow(
      id: m['id']! as String,
      customerId: m['customer_id']! as String,
      title: m['title']! as String,
      fabricNote: m['fabric_note'] as String?,
      dueDate: DateTime.fromMillisecondsSinceEpoch(m['due_date']! as int),
      status: OrderStatus.parse(m['status']! as String),
      agreedAmountNgn: m['agreed_amount_ngn']! as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at']! as int),
    );
  }
}
