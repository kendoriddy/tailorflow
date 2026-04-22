import 'package:connectivity_plus/connectivity_plus.dart';

import 'billing/freemium_service.dart';
import 'db/app_database.dart';
import 'repos/customers_repository.dart';
import 'repos/dashboard_repository.dart';
import 'repos/orders_repository.dart';
import 'repos/payments_repository.dart';
import 'repos/settings_repository.dart';
import 'sync/outbox_repository.dart';
import 'sync/sync_service.dart';

class DataLayer {
  DataLayer._({
    required this.db,
    required this.outbox,
    required this.customers,
    required this.orders,
    required this.payments,
    required this.dashboard,
    required this.freemium,
    required this.settings,
    required this.sync,
  });

  final AppDatabase db;
  final OutboxRepository outbox;
  final CustomersRepository customers;
  final OrdersRepository orders;
  final PaymentsRepository payments;
  final DashboardRepository dashboard;
  final FreemiumService freemium;
  final SettingsRepository settings;
  final SyncService sync;

  static Future<DataLayer> open() async {
    final db = await AppDatabase.open();
    final outbox = OutboxRepository(db);
    final customers = CustomersRepository(db, outbox);
    final orders = OrdersRepository(db, outbox);
    final payments = PaymentsRepository(db, outbox);
    final dashboard = DashboardRepository(db);
    final freemium = FreemiumService(db);
    final settings = SettingsRepository(db);
    final sync = SyncService(
      db: db,
      outbox: outbox,
      connectivity: Connectivity(),
    );
    return DataLayer._(
      db: db,
      outbox: outbox,
      customers: customers,
      orders: orders,
      payments: payments,
      dashboard: dashboard,
      freemium: freemium,
      settings: settings,
      sync: sync,
    );
  }

  Future<void> close() => db.close();
}
