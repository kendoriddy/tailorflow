import 'package:uuid/uuid.dart';

import '../../core/utils/phone.dart';
import '../db/app_database.dart';
import '../models/customer.dart';
import '../models/measurement_profile.dart';
import '../sync/outbox_repository.dart';

class CustomersRepository {
  CustomersRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxRepository _outbox;

  static const _uuid = Uuid();

  Future<List<Customer>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      return listActive();
    }
    final norm = normalizePhoneDigits(q);
    final like = '%${q.replaceAll('%', '\\%')}%';
    final rows = await _db.raw.query(
      'customers',
      where: 'deleted_at IS NULL AND (name LIKE ? OR phone_norm LIKE ?)',
      whereArgs: [like, '%$norm%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(_mapCustomer).toList();
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
    final rows = await _db.raw.query('customers', where: 'id = ?', whereArgs: [id]);
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
      length: (m['length'] as num?)?.toDouble(),
      sleeve: (m['sleeve'] as num?)?.toDouble(),
      shoulder: (m['shoulder'] as num?)?.toDouble(),
      neck: (m['neck'] as num?)?.toDouble(),
      inseam: (m['inseam'] as num?)?.toDouble(),
      notes: m['notes'] as String?,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at']! as int),
    );
  }
}
