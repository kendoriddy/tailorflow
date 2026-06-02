import '../db/app_database.dart';
import 'plan_limits_service.dart';

class FreemiumService {
  FreemiumService(this._db, this._plans);

  final AppDatabase _db;
  final PlanLimitsService _plans;

  /// Active customers = not soft-deleted.
  Future<int> activeCustomerCount() async {
    final rows = await _db.raw.rawQuery(
      'SELECT COUNT(*) AS c FROM customers WHERE deleted_at IS NULL',
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<int> freeCustomerLimit() async {
    final config = await _plans.getConfig();
    return config.freeMaxActiveCustomers;
  }

  /// Whether adding another customer would exceed the free tier cap.
  Future<bool> isAtFreeLimit() async {
    final limit = await freeCustomerLimit();
    final c = await activeCustomerCount();
    return c >= limit;
  }
}
