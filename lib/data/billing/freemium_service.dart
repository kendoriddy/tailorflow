import '../db/app_database.dart';

const kFreemiumCustomerLimit = 10;

class FreemiumService {
  FreemiumService(this._db);

  final AppDatabase _db;

  /// Active customers = not soft-deleted.
  Future<int> activeCustomerCount() async {
    final rows = await _db.raw.rawQuery(
      'SELECT COUNT(*) AS c FROM customers WHERE deleted_at IS NULL',
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Whether adding another customer would exceed the free tier cap.
  Future<bool> isAtFreeLimit() async {
    final c = await activeCustomerCount();
    return c >= kFreemiumCustomerLimit;
  }
}
