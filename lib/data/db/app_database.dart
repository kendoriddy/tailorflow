import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static const _name = 'tailorflow.db';
  static const _version = 1;

  static Future<AppDatabase> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _name);
    final db = await openDatabase(
      path,
      version: _version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE customers (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT,
  phone_norm TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);
''');
        await db.execute(
          'CREATE INDEX idx_customers_phone_norm ON customers(phone_norm);',
        );
        await db.execute('CREATE INDEX idx_customers_name ON customers(name);');
        await db.execute('''
CREATE TABLE measurement_profiles (
  id TEXT NOT NULL PRIMARY KEY,
  customer_id TEXT NOT NULL,
  label TEXT NOT NULL,
  chest REAL,
  waist REAL,
  length REAL,
  sleeve REAL,
  shoulder REAL,
  neck REAL,
  inseam REAL,
  notes TEXT,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
);
''');
        await db.execute(
          'CREATE INDEX idx_measurements_customer ON measurement_profiles(customer_id);',
        );
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
        await db.execute('CREATE INDEX idx_orders_due ON orders(due_date);');
        await db.execute('CREATE INDEX idx_orders_customer ON orders(customer_id);');
        await db.execute('''
CREATE TABLE payments (
  id TEXT NOT NULL PRIMARY KEY,
  order_id TEXT NOT NULL,
  amount_ngn INTEGER NOT NULL,
  paid_at INTEGER NOT NULL,
  note TEXT,
  FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
);
''');
        await db.execute('CREATE INDEX idx_payments_order ON payments(order_id);');
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
        await db.execute(
          'CREATE INDEX idx_outbox_pending ON outbox_ops(processed_at);',
        );
        await db.execute('''
CREATE TABLE shop_settings (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);
''');
      },
    );
    return AppDatabase._(db);
  }

  Database get raw => _db;

  Future<void> close() => _db.close();
}
