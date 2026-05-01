import 'package:uuid/uuid.dart';

import '../../core/utils/currency.dart';
import '../db/app_database.dart';
import '../models/in_app_notification.dart';
import '../models/order_status.dart';

class NotificationsRepository {
  NotificationsRepository(this._db);

  final AppDatabase _db;

  static const _uuid = Uuid();

  Future<int> unreadCount() async {
    final rows = await _db.raw.rawQuery(
      'SELECT COUNT(*) AS c FROM notifications WHERE read_at IS NULL',
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<int> unreadDueCount() async {
    final rows = await _db.raw.rawQuery(
      "SELECT COUNT(*) AS c FROM notifications WHERE read_at IS NULL AND kind LIKE 'due_%'",
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<List<InAppNotificationView>> listAll({bool dueOnly = false}) async {
    final dueClause = dueOnly ? " AND n.kind LIKE 'due_%'" : '';
    final rows = await _db.raw.rawQuery('''
SELECT n.*,
  c.name AS customer_name,
  o.title AS order_title
FROM notifications n
JOIN customers c ON c.id = n.customer_id
JOIN orders o ON o.id = n.order_id
WHERE c.deleted_at IS NULL
$dueClause
ORDER BY (n.read_at IS NOT NULL) ASC, n.fire_on DESC
''');

    return rows.map((m) {
      DateTime? dtOrNull(Object? v) =>
          v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);
      return InAppNotificationView(
        id: m['id']! as String,
        orderId: m['order_id']! as String,
        customerId: m['customer_id']! as String,
        kind: m['kind']! as String,
        dueDate: DateTime.fromMillisecondsSinceEpoch(m['due_date']! as int),
        fireOn: DateTime.fromMillisecondsSinceEpoch(m['fire_on']! as int),
        title: m['title']! as String,
        body: m['body']! as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
        readAt: dtOrNull(m['read_at']),
        customerName: m['customer_name']! as String,
        orderTitle: m['order_title']! as String,
      );
    }).toList();
  }

  Future<void> markRead(String id) async {
    await _db.raw.update(
      'notifications',
      {'read_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllRead() async {
    await _db.raw.update(
      'notifications',
      {'read_at': DateTime.now().millisecondsSinceEpoch},
      where: 'read_at IS NULL',
    );
  }

  /// Generates reminders for orders due in 3 days through today.
  ///
  /// - Only for orders not collected.
  /// - Deduped by UNIQUE(order_id, kind, fire_on).
  Future<void> refreshDueReminders() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end =
        start.add(const Duration(days: 3, hours: 23, minutes: 59, seconds: 59));

    final rows = await _db.raw.rawQuery('''
SELECT o.id AS order_id,
  o.customer_id AS customer_id,
  o.title AS order_title,
  o.due_date AS due_date,
  o.status AS status,
  c.name AS customer_name,
  IFNULL((SELECT SUM(p.amount_ngn) FROM payments p WHERE p.order_id = o.id), 0) AS paid_ngn,
  o.agreed_amount_ngn AS agreed_ngn
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE c.deleted_at IS NULL
  AND o.status != ?
  AND o.due_date BETWEEN ? AND ?
''', [
      OrderStatus.collected.wireName,
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    ]);

    for (final m in rows) {
      final orderId = m['order_id']! as String;
      final customerId = m['customer_id']! as String;
      final orderTitle = m['order_title']! as String;
      final customerName = m['customer_name']! as String;
      final due = DateTime.fromMillisecondsSinceEpoch(m['due_date']! as int);
      final agreed = m['agreed_ngn']! as int;
      final paid = (m['paid_ngn'] as num?)?.toInt() ?? 0;
      final balance = (agreed - paid).clamp(0, 1 << 62);

      final daysLeft =
          _daysBetween(start, DateTime(due.year, due.month, due.day));
      if (daysLeft < 0 || daysLeft > 3) continue;

      final kind = 'due_${daysLeft}d';
      final title = daysLeft == 0
          ? 'Due today: $customerName'
          : 'Due in $daysLeft day${daysLeft == 1 ? '' : 's'}: $customerName';
      final body = balance > 0
          ? '$orderTitle • Balance ${formatNgn(balance)}'
          : '$orderTitle • Fully paid';

      await _insertIfMissing(
        orderId: orderId,
        customerId: customerId,
        kind: kind,
        dueDate: due,
        fireOn: start, // fire date = today; shown immediately in-app
        title: title,
        body: body,
      );
    }
  }

  int _daysBetween(DateTime a, DateTime b) {
    final aa = DateTime(a.year, a.month, a.day);
    final bb = DateTime(b.year, b.month, b.day);
    return bb.difference(aa).inDays;
  }

  Future<void> _insertIfMissing({
    required String orderId,
    required String customerId,
    required String kind,
    required DateTime dueDate,
    required DateTime fireOn,
    required String title,
    required String body,
  }) async {
    try {
      await _db.raw.insert('notifications', {
        'id': _uuid.v4(),
        'order_id': orderId,
        'customer_id': customerId,
        'kind': kind,
        'due_date': dueDate.millisecondsSinceEpoch,
        'fire_on': fireOn.millisecondsSinceEpoch,
        'title': title,
        'body': body,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'read_at': null,
      });
    } catch (_) {
      // Unique constraint hit -> already exists.
    }
  }
}
