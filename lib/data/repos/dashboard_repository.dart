import '../db/app_database.dart';
import '../models/order_row.dart';
import '../models/order_status.dart';

/// Dashboard aggregates.
///
/// **Total owed this month** (per MVP spec): sum of positive balances for orders
/// whose [dueDate] falls in the **current local calendar month**, excluding
/// [OrderStatus.collected], and only for active customers.
class DashboardRepository {
  DashboardRepository(this._db);

  final AppDatabase _db;

  DateTime _monthStart(DateTime d) => DateTime(d.year, d.month);
  DateTime _monthEnd(DateTime d) => DateTime(d.year, d.month + 1, 1)
      .subtract(const Duration(milliseconds: 1));

  Future<List<OrderDueView>> dueToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end =
        DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
            .millisecondsSinceEpoch;

    final rows = await _db.raw.rawQuery('''
SELECT o.*, c.name AS customer_name,
  (o.agreed_amount_ngn - IFNULL((SELECT SUM(p.amount_ngn) FROM payments p WHERE p.order_id = o.id), 0)) AS balance_ngn
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE c.deleted_at IS NULL
  AND o.due_date BETWEEN ? AND ?
  AND o.status != ?
ORDER BY o.due_date ASC, balance_ngn DESC
''', [start, end, OrderStatus.collected.wireName]);

    return rows.map(_mapDueView).toList();
  }

  /// Sum of outstanding balances for orders due this calendar month (local).
  Future<int> totalOwedThisMonth() async {
    final now = DateTime.now();
    final msStart = _monthStart(now).millisecondsSinceEpoch;
    final msEnd = _monthEnd(now).millisecondsSinceEpoch;

    final rows = await _db.raw.rawQuery('''
SELECT o.id, o.agreed_amount_ngn,
  IFNULL((SELECT SUM(p.amount_ngn) FROM payments p WHERE p.order_id = o.id), 0) AS paid
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE c.deleted_at IS NULL
  AND o.due_date BETWEEN ? AND ?
  AND o.status != ?
''', [msStart, msEnd, OrderStatus.collected.wireName]);

    var sum = 0;
    for (final r in rows) {
      final agreed = r['agreed_amount_ngn']! as int;
      final paid = (r['paid'] as int?) ?? 0;
      final bal = (agreed - paid).clamp(0, 1 << 62);
      sum += bal;
    }
    return sum;
  }

  OrderDueView _mapDueView(Map<String, Object?> m) {
    final o = OrderRow(
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
    return OrderDueView(
      id: o.id,
      customerId: o.customerId,
      title: o.title,
      fabricNote: o.fabricNote,
      dueDate: o.dueDate,
      status: o.status,
      agreedAmountNgn: o.agreedAmountNgn,
      createdAt: o.createdAt,
      updatedAt: o.updatedAt,
      customerName: m['customer_name']! as String,
      balanceNgn: (m['balance_ngn'] as num?)?.toInt() ?? 0,
    );
  }
}
