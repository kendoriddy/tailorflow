import 'package:uuid/uuid.dart';

import '../../core/utils/phone.dart';
import '../db/app_database.dart';
import '../models/customer.dart';
import '../models/customer_list_item.dart';
import '../models/order_status.dart';
import '../models/measurement_profile.dart';
import '../sync/outbox_repository.dart';

class CustomersRepository {
  CustomersRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxRepository _outbox;

  static const _uuid = Uuid();

  Future<List<CustomerListItem>> listSummary({String query = ''}) async {
    final q = query.trim();
    final norm = normalizePhoneDigits(q);

    final rows = await _db.raw.rawQuery('''
SELECT
  c.id AS customer_id,
  c.name AS name,
  c.phone AS phone,
  c.updated_at AS updated_at,
  IFNULL((
    SELECT SUM(
      MAX(
        o.agreed_amount_ngn - IFNULL((SELECT SUM(p.amount_ngn) FROM payments p WHERE p.order_id = o.id), 0),
        0
      )
    )
    FROM orders o
    WHERE o.customer_id = c.id
      AND o.status != ?
  ), 0) AS owed_ngn,
  IFNULL((
    SELECT COUNT(*)
    FROM orders o
    WHERE o.customer_id = c.id
      AND o.status != ?
  ), 0) AS open_orders_count,
  (
    SELECT o.title
    FROM orders o
    WHERE o.customer_id = c.id
    ORDER BY o.updated_at DESC
    LIMIT 1
  ) AS last_order_title,
  (
    SELECT o.due_date
    FROM orders o
    WHERE o.customer_id = c.id
    ORDER BY o.updated_at DESC
    LIMIT 1
  ) AS last_order_due_date,
  (
    SELECT o.status
    FROM orders o
    WHERE o.customer_id = c.id
    ORDER BY o.updated_at DESC
    LIMIT 1
  ) AS last_order_status
FROM customers c
WHERE c.deleted_at IS NULL
ORDER BY c.updated_at DESC
''', [
      OrderStatus.collected.wireName,
      OrderStatus.collected.wireName,
    ]);

    final all = rows.map((m) {
      final dueMs = (m['last_order_due_date'] as int?);
      final rawStatus = m['last_order_status'] as String?;
      return CustomerListItem(
        customerId: m['customer_id']! as String,
        name: m['name']! as String,
        phone: m['phone'] as String?,
        totalOwedNgn: (m['owed_ngn'] as num?)?.toInt() ?? 0,
        openOrdersCount: (m['open_orders_count'] as num?)?.toInt() ?? 0,
        lastOrderTitle: m['last_order_title'] as String?,
        lastOrderDueDate:
            dueMs == null ? null : DateTime.fromMillisecondsSinceEpoch(dueMs),
        lastOrderStatus:
            rawStatus == null ? null : OrderStatus.parse(rawStatus),
      );
    }).toList();
    if (q.isEmpty) return all;
    return all
        .where(
          (c) => _matchesCustomerQuery(
            name: c.name,
            phone: c.phone,
            query: q,
            normalizedQuery: norm,
          ),
        )
        .toList();
  }

  Future<List<Customer>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      return listActive();
    }
    final norm = normalizePhoneDigits(q);
    final rows = await _db.raw.query(
      'customers',
      where: 'deleted_at IS NULL',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    final all = rows.map(_mapCustomer).toList();
    return all
        .where(
          (c) => _matchesCustomerQuery(
            name: c.name,
            phone: c.phone,
            query: q,
            normalizedQuery: norm,
          ),
        )
        .toList();
  }

  Future<List<Customer>> listActive() async {
    final rows = await _db.raw.query(
      'customers',
      where: 'deleted_at IS NULL',
      orderBy: 'updated_at DESC',
    );
    return rows.map(_mapCustomer).toList();
  }

  Future<Customer?> getById(String id) async {
    final rows =
        await _db.raw.query('customers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _mapCustomer(rows.first);
  }

  Future<String> insertCustomer({
    required String name,
    String? phone,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final norm = normalizePhoneDigits(phone);
    await _db.raw.insert('customers', {
      'id': id,
      'name': name.trim(),
      'phone': phone?.trim(),
      'phone_norm': norm,
      'created_at': now,
      'updated_at': now,
      'deleted_at': null,
    });
    await _outbox.enqueue(
      type: OutboxOpType.upsertCustomer,
      entityId: id,
      payload: {
        'id': id,
        'name': name.trim(),
        'phone': phone?.trim(),
        'phone_norm': norm,
        'created_at': now,
        'updated_at': now,
      },
    );
    return id;
  }

  Future<void> updateCustomer(Customer c) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.raw.update(
      'customers',
      {
        'name': c.name.trim(),
        'phone': c.phone?.trim(),
        'phone_norm': normalizePhoneDigits(c.phone),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [c.id],
    );
    await _outbox.enqueue(
      type: OutboxOpType.upsertCustomer,
      entityId: c.id,
      payload: {
        'id': c.id,
        'name': c.name.trim(),
        'phone': c.phone?.trim(),
        'phone_norm': normalizePhoneDigits(c.phone),
        'updated_at': now,
      },
    );
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.raw.update(
      'customers',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _outbox.enqueue(
      type: OutboxOpType.deleteCustomer,
      entityId: id,
      payload: {'id': id, 'deleted_at': now},
    );
  }

  Future<MeasurementProfile?> defaultMeasurements(String customerId) async {
    final rows = await _db.raw.query(
      'measurement_profiles',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapMeasurement(rows.first);
  }

  Future<void> upsertDefaultMeasurements({
    required String customerId,
    String label = 'Default',
    double? chest,
    double? waist,
    double? hip,
    double? length,
    double? sleeve,
    double? shoulder,
    double? neck,
    double? inseam,
    String? notes,
  }) async {
    final existing = await defaultMeasurements(customerId);
    final id = existing?.id ?? _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (existing == null) {
      await _db.raw.insert('measurement_profiles', {
        'id': id,
        'customer_id': customerId,
        'label': label,
        'chest': chest,
        'waist': waist,
        'hip': hip,
        'length': length,
        'sleeve': sleeve,
        'shoulder': shoulder,
        'neck': neck,
        'inseam': inseam,
        'notes': notes,
        'updated_at': now,
      });
    } else {
      await _db.raw.update(
        'measurement_profiles',
        {
          'label': label,
          'chest': chest,
          'waist': waist,
          'hip': hip,
          'length': length,
          'sleeve': sleeve,
          'shoulder': shoulder,
          'neck': neck,
          'inseam': inseam,
          'notes': notes,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await _outbox.enqueue(
      type: OutboxOpType.upsertMeasurement,
      entityId: id,
      payload: {
        'id': id,
        'customer_id': customerId,
        'label': label,
        'chest': chest,
        'waist': waist,
        'hip': hip,
        'length': length,
        'sleeve': sleeve,
        'shoulder': shoulder,
        'neck': neck,
        'inseam': inseam,
        'notes': notes,
        'updated_at': now,
      },
    );
  }

  Customer _mapCustomer(Map<String, Object?> m) {
    return Customer(
      id: m['id']! as String,
      name: m['name']! as String,
      phone: m['phone'] as String?,
      phoneNorm: (m['phone_norm'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at']! as int),
      deletedAt: m['deleted_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(m['deleted_at']! as int),
    );
  }

  MeasurementProfile _mapMeasurement(Map<String, Object?> m) {
    return MeasurementProfile(
      id: m['id']! as String,
      customerId: m['customer_id']! as String,
      label: m['label']! as String,
      chest: (m['chest'] as num?)?.toDouble(),
      waist: (m['waist'] as num?)?.toDouble(),
      hip: (m['hip'] as num?)?.toDouble(),
      length: (m['length'] as num?)?.toDouble(),
      sleeve: (m['sleeve'] as num?)?.toDouble(),
      shoulder: (m['shoulder'] as num?)?.toDouble(),
      neck: (m['neck'] as num?)?.toDouble(),
      inseam: (m['inseam'] as num?)?.toDouble(),
      notes: m['notes'] as String?,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at']! as int),
    );
  }

  bool _matchesCustomerQuery({
    required String name,
    required String? phone,
    required String query,
    required String normalizedQuery,
  }) {
    if (name.toLowerCase().contains(query.toLowerCase())) {
      return true;
    }
    final queryDigits = query.replaceAll(RegExp(r'\D'), '');
    if (queryDigits.isEmpty) {
      return false;
    }
    final phoneDigits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.isEmpty) {
      return false;
    }

    final phoneNormalized = normalizePhoneDigits(phone);
    final phoneVariants = <String>{
      phoneDigits,
      phoneNormalized,
    };
    if (phoneNormalized.startsWith('234') && phoneNormalized.length > 3) {
      phoneVariants.add('0${phoneNormalized.substring(3)}');
    }

    final queryVariants = <String>{queryDigits};
    if (normalizedQuery.isNotEmpty) {
      queryVariants.add(normalizedQuery);
      if (normalizedQuery.startsWith('234') && normalizedQuery.length > 3) {
        queryVariants.add('0${normalizedQuery.substring(3)}');
      }
    }
    if (queryDigits.startsWith('0') && queryDigits.length > 1) {
      queryVariants.add('234${queryDigits.substring(1)}');
    }
    if (queryDigits.startsWith('234') && queryDigits.length > 3) {
      queryVariants.add('0${queryDigits.substring(3)}');
    }

    for (final needle in queryVariants) {
      if (needle.isEmpty) continue;
      for (final haystack in phoneVariants) {
        if (haystack.contains(needle)) {
          return true;
        }
      }
    }
    return false;
  }
}
