import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailorflow_ng/data/db/app_database.dart';
import 'package:tailorflow_ng/data/models/order_attachment.dart';
import 'package:tailorflow_ng/data/repos/orders_repository.dart';
import 'package:tailorflow_ng/data/sync/outbox_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database rawDb;
  late OrdersRepository orders;

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
    orders = OrdersRepository(appDb, OutboxRepository(appDb));
    await _insertCustomer(rawDb);
  });

  tearDown(() async {
    await rawDb.close();
  });

  test('createOrderWithInitialPayment saves payment and outbox rows', () async {
    final orderId = await orders.createOrderWithInitialPayment(
      customerId: 'customer-1',
      title: 'Agbada',
      dueDate: DateTime(2026, 8, 10),
      agreedAmountNgn: 50000,
      initialPaymentNgn: 20000,
      paidAt: DateTime(2026, 8, 1),
      attachments: const [
        NewOrderAttachmentInput(
          imageBase64: 'ZmFrZS1pbWFnZQ==',
          mimeType: 'image/jpeg',
        ),
      ],
    );

    final money = await orders.listMoneyForCustomer('customer-1');
    expect(money, hasLength(1));
    expect(money.single.order.id, orderId);
    expect(money.single.paidNgn, 20000);
    expect(money.single.balanceNgn, 30000);
    expect(money.single.order.attachments, hasLength(1));

    final opRows = await rawDb.query(
      'outbox_ops',
      orderBy: 'created_at ASC, rowid ASC',
    );
    expect(
      opRows.map((row) => row['op_type']),
      orderedEquals([
        'upsertOrder',
        'upsertOrderAttachment',
        'upsertPayment',
      ]),
    );
  });

  test(
    'createOrderWithInitialPayment rolls back on late outbox failure',
    () async {
      await rawDb.execute('''
CREATE TRIGGER fail_payment_outbox
BEFORE INSERT ON outbox_ops
WHEN NEW.op_type = 'upsertPayment'
BEGIN
  SELECT RAISE(ABORT, 'fail payment outbox');
END;
''');

      await expectLater(
        orders.createOrderWithInitialPayment(
          customerId: 'customer-1',
          title: 'Agbada',
          dueDate: DateTime(2026, 8, 10),
          agreedAmountNgn: 50000,
          initialPaymentNgn: 20000,
          paidAt: DateTime(2026, 8, 1),
          attachments: const [
            NewOrderAttachmentInput(
              imageBase64: 'ZmFrZS1pbWFnZQ==',
              mimeType: 'image/jpeg',
            ),
          ],
        ),
        throwsA(isA<DatabaseException>()),
      );

      expect(await _rowCount(rawDb, 'orders'), 0);
      expect(await _rowCount(rawDb, 'order_attachments'), 0);
      expect(await _rowCount(rawDb, 'payments'), 0);
      expect(await _rowCount(rawDb, 'outbox_ops'), 0);
    },
  );
}

Future<void> _createSchema(DatabaseExecutor db) async {
  await db.execute('''
CREATE TABLE customers (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT,
  phone_norm TEXT NOT NULL DEFAULT '',
  birth_day INTEGER,
  birth_month INTEGER,
  birth_year INTEGER,
  birthday_consent INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);
''');
  await db.execute('''
CREATE TABLE orders (
  id TEXT NOT NULL PRIMARY KEY,
  customer_id TEXT NOT NULL,
  title TEXT NOT NULL,
  fabric_note TEXT,
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
CREATE TABLE order_attachments (
  id TEXT NOT NULL PRIMARY KEY,
  order_id TEXT NOT NULL,
  image_base64 TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  created_at INTEGER NOT NULL,
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

Future<void> _insertCustomer(DatabaseExecutor db) async {
  await db.insert('customers', {
    'id': 'customer-1',
    'name': 'Ada Tailor',
    'phone_norm': '',
    'birthday_consent': 0,
    'created_at': 1,
    'updated_at': 1,
  });
}

Future<int> _rowCount(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
  return rows.single['c']! as int;
}
