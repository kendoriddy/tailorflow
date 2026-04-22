import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<String?> get(String key) async {
    final rows = await _db.raw.query(
      'shop_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    await _db.raw.insert('shop_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> isSubscribed() async {
    final v = await get('subscribed');
    return v == 'true';
  }

  Future<void> setSubscribed(bool v) => set('subscribed', v ? 'true' : 'false');
}
