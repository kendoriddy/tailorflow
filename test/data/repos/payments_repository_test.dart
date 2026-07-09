import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailorflow_ng/data/db/app_database.dart';
import 'package:tailorflow_ng/data/repos/payments_repository.dart';
import 'package:tailorflow_ng/data/sync/outbox_repository.dart';

void main() {
  late Database rawDb;
  late PaymentsRepository payments;

  setUp(() async {
    sqfliteFfiInit();
    rawDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await rawDb.execute('''
CREATE TABLE customers (
  id TEXT NOT NULL PRIMARY KEY,
  updated_at INTEGER NOT NULL
);
''');
    await rawDb.execute('''
CREATE TABLE orders (
  id TEXT NOT NULL PRIMARY KEY,
  customer_id TEXT NOT NULL
);
''');
    await rawDb.execute('''
CREATE TABLE payments (
  id TEXT NOT NULL PRIMARY KEY,
  order_id TEXT NOT NULL,
  amount_ngn INTEGER NOT NULL,
  paid_at INTEGER NOT NULL,
  note TEXT
);
''');
    await rawDb.execute('''
CREATE TABLE outbox_ops (
  id TEXT NOT NULL PRIMARY KEY,
  op_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  processed_at INTEGER
);
''');

    final db = AppDatabase.forTesting(rawDb);
    payments = PaymentsRepository(db, OutboxRepository(db));

    await rawDb.insert('customers', {
      'id': 'customer-1',
      'updated_at': 100,
    });
    await rawDb.insert('orders', {
      'id': 'order-1',
      'customer_id': 'customer-1',
    });
    await rawDb.insert('payments', {
      'id': 'payment-1',
      'order_id': 'order-1',
      'amount_ngn': 5000,
      'paid_at': 1234,
      'note': 'deposit',
    });
  });

  tearDown(() async {
    await rawDb.close();
  });

  test('deletePayment queues a remote delete outbox op', () async {
    await payments.deletePayment('payment-1');

    final localPayments = await rawDb.query('payments');
    expect(localPayments, isEmpty);

    final customers = await rawDb.query(
      'customers',
      where: 'id = ?',
      whereArgs: ['customer-1'],
    );
    expect(customers.single['updated_at'], isNot(100));

    final ops = await rawDb.query('outbox_ops');
    expect(ops, hasLength(1));
    expect(ops.single['op_type'], 'deletePayment');
    expect(ops.single['entity_id'], 'payment-1');
    expect(jsonDecode(ops.single['payload']! as String), {'id': 'payment-1'});
    expect(ops.single['processed_at'], isNull);
  });
}
