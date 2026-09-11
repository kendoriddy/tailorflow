import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailorflow_ng/data/db/app_database.dart';
import 'package:tailorflow_ng/data/models/payment.dart';
import 'package:tailorflow_ng/data/repos/payments_repository.dart';
import 'package:tailorflow_ng/data/sync/outbox_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database rawDb;
  late PaymentsRepository payments;

  setUp(() async {
    rawDb = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await _createSchema(db);
      },
    );
    final appDb = AppDatabase.forTesting(rawDb);
    payments = PaymentsRepository(appDb, OutboxRepository(appDb));
    await _insertCustomerAndOrder(rawDb);
  });

  tearDown(() async {
    await rawDb.close();
  });

  test('insertPayment stores updated_at in row and outbox payload', () async {
    final before = DateTime.now().millisecondsSinceEpoch;

    await payments.insertPayment(
      orderId: 'order-1',
      amountNgn: 2500,
      paidAt: DateTime.fromMillisecondsSinceEpoch(1000),
      note: '  deposit  ',
    );

    final paymentRows = await rawDb.query('payments');
    expect(paymentRows, hasLength(1));
    final payment = paymentRows.single;
    expect(payment['paid_at'], 1000);
    expect(payment['note'], 'deposit');
    expect(payment['updated_at'], isA<int>());
    expect(payment['updated_at']! as int, greaterThanOrEqualTo(before));

    final payload = await _singleOutboxPayload(rawDb);
    expect(payload['id'], payment['id']);
    expect(payload['updated_at'], payment['updated_at']);
  });

  test('updatePayment refreshes updated_at in row and outbox payload', () async {
    await payments.insertPayment(
      orderId: 'order-1',
      amountNgn: 2500,
      paidAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    final inserted = (await rawDb.query('payments')).single;
    final id = inserted['id']! as String;
    await rawDb.delete('outbox_ops');
    await rawDb.update(
      'payments',
      {'updated_at': 1},
      where: 'id = ?',
      whereArgs: [id],
    );

    await payments.updatePayment(
      Payment(
        id: id,
        orderId: 'order-1',
        amountNgn: 4000,
        paidAt: DateTime.fromMillisecondsSinceEpoch(2000),
        note: 'balance',
      ),
    );

    final payment = (await rawDb.query('payments')).single;
    expect(payment['amount_ngn'], 4000);
    expect(payment['paid_at'], 2000);
    expect(payment['updated_at']! as int, greaterThan(1));

    final payload = await _singleOutboxPayload(rawDb);
    expect(payload['id'], id);
    expect(payload['amount_ngn'], 4000);
    expect(payload['updated_at'], payment['updated_at']);
  });
}

Future<void> _createSchema(DatabaseExecutor db) async {
  await db.execute('''
CREATE TABLE customers (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  phone_norm TEXT NOT NULL DEFAULT '',
  birthday_consent INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''');
  await db.execute('''
CREATE TABLE orders (
  id TEXT NOT NULL PRIMARY KEY,
  customer_id TEXT NOT NULL,
  title TEXT NOT NULL,
  due_date INTEGER NOT NULL,
  status TEXT NOT NULL,
  agreed_amount_ngn INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
);
''');
  await db.execute('''
CREATE TABLE payments (
  id TEXT NOT NULL PRIMARY KEY,
  order_id TEXT NOT NULL,
  amount_ngn INTEGER NOT NULL,
  paid_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  note TEXT,
  FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
);
''');
  await db.execute('''
CREATE TABLE outbox_ops (
  id TEXT NOT NULL PRIMARY KEY,
  op_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  processed_at INTEGER
);
''');
}

Future<void> _insertCustomerAndOrder(DatabaseExecutor db) async {
  await db.insert('customers', {
    'id': 'customer-1',
    'name': 'Ada Tailor',
    'phone_norm': '',
    'birthday_consent': 0,
    'created_at': 1,
    'updated_at': 1,
  });
  await db.insert('orders', {
    'id': 'order-1',
    'customer_id': 'customer-1',
    'title': 'Agbada',
    'due_date': 1,
    'status': 'booked',
    'agreed_amount_ngn': 10000,
    'created_at': 1,
    'updated_at': 1,
  });
}

Future<Map<String, dynamic>> _singleOutboxPayload(Database db) async {
  final opRows = await db.query('outbox_ops');
  expect(opRows, hasLength(1));
  return jsonDecode(opRows.single['payload']! as String)
      as Map<String, dynamic>;
}
