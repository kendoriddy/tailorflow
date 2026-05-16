import 'package:uuid/uuid.dart';

import '../../core/utils/money.dart';
import '../db/app_database.dart';
import '../models/order_attachment.dart';
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
    final orderIds = rows.map((m) => m['id']! as String).toList();
    final attachmentsByOrder = await _attachmentsByOrderIds(orderIds);

    return rows.map((m) {
      final order = _mapOrder(m);
      final orderWithAttachments = OrderRow(
        id: order.id,
        customerId: order.customerId,
        title: order.title,
        fabricNote: order.fabricNote,
        dueDate: order.dueDate,
        status: order.status,
        agreedAmountNgn: order.agreedAmountNgn,
        createdAt: order.createdAt,
        updatedAt: order.updatedAt,
        attachments: attachmentsByOrder[order.id] ?? const <OrderAttachment>[],
      );
      final paid = (m['paid_ngn'] as num?)?.toInt() ?? 0;
      final bal = (m['balance_ngn'] as num?)?.toInt() ??
          clampNonNegativeBalance(
            agreedAmountNgn: order.agreedAmountNgn,
            paidSumNgn: paid,
          );
      return OrderMoneyView(
        order: orderWithAttachments,
        paidNgn: paid,
        balanceNgn: bal,
      );
    }).toList();
  }

  Future<List<OrderRow>> listForCustomer(String customerId) async {
    final rows = await _db.raw.query(
      'orders',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'due_date ASC',
    );
    final orders = rows.map(_mapOrder).toList();
    final attachmentsByOrder =
        await _attachmentsByOrderIds(orders.map((o) => o.id).toList());
    return orders
        .map(
          (o) => OrderRow(
            id: o.id,
            customerId: o.customerId,
            title: o.title,
            fabricNote: o.fabricNote,
            dueDate: o.dueDate,
            status: o.status,
            agreedAmountNgn: o.agreedAmountNgn,
            createdAt: o.createdAt,
            updatedAt: o.updatedAt,
            attachments: attachmentsByOrder[o.id] ?? const <OrderAttachment>[],
          ),
        )
        .toList();
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

  Future<void> addAttachments({
    required String orderId,
    required List<NewOrderAttachmentInput> images,
  }) async {
    if (images.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final image in images) {
      final id = _uuid.v4();
      await _db.raw.insert('order_attachments', {
        'id': id,
        'order_id': orderId,
        'image_base64': image.imageBase64,
        'mime_type': image.mimeType,
        'created_at': now,
      });
      await _outbox.enqueue(
        type: OutboxOpType.upsertOrderAttachment,
        entityId: id,
        payload: {
          'id': id,
          'order_id': orderId,
          'image_base64': image.imageBase64,
          'mime_type': image.mimeType,
          'created_at': now,
        },
      );
    }
    await _bumpCustomerUpdatedAtForOrder(orderId);
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
        'created_at': o.createdAt.millisecondsSinceEpoch,
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

  Future<void> _bumpCustomerUpdatedAtForOrder(String orderId) async {
    final rows = await _db.raw.rawQuery(
      'SELECT customer_id FROM orders WHERE id = ?',
      [orderId],
    );
    if (rows.isEmpty) return;
    final customerId = rows.first['customer_id'] as String?;
    if (customerId == null) return;
    await _bumpCustomerUpdatedAt(customerId);
  }

  Future<Map<String, List<OrderAttachment>>> _attachmentsByOrderIds(
    List<String> orderIds,
  ) async {
    if (orderIds.isEmpty) return const <String, List<OrderAttachment>>{};
    final placeholders = List.filled(orderIds.length, '?').join(', ');
    final rows = await _db.raw.rawQuery(
      '''
SELECT id, order_id, image_base64, mime_type, created_at
FROM order_attachments
WHERE order_id IN ($placeholders)
ORDER BY created_at ASC
''',
      orderIds,
    );

    final map = <String, List<OrderAttachment>>{};
    for (final m in rows) {
      final attachment = OrderAttachment(
        id: m['id']! as String,
        orderId: m['order_id']! as String,
        imageBase64: m['image_base64']! as String,
        mimeType: m['mime_type']! as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
      );
      map.putIfAbsent(attachment.orderId, () => <OrderAttachment>[]).add(
            attachment,
          );
    }
    return map;
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
