import 'package:connectivity_plus/connectivity_plus.dart';

import 'billing/freemium_service.dart';
import 'billing/plan_limits_service.dart';
import 'billing/subscription_service.dart';
import 'billing/whatsapp_quota_service.dart';
import 'whatsapp/whatsapp_service.dart';
import 'db/app_database.dart';
import 'repos/customers_repository.dart';
import 'repos/notifications_repository.dart';
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
    required this.notifications,
    required this.freemium,
    required this.planLimits,
    required this.whatsappQuota,
    required this.whatsapp,
    required this.subscriptions,
    required this.settings,
    required this.sync,
  });

  final AppDatabase db;
  final OutboxRepository outbox;
  final CustomersRepository customers;
  final OrdersRepository orders;
  final PaymentsRepository payments;
  final NotificationsRepository notifications;
  final FreemiumService freemium;
  final PlanLimitsService planLimits;
  final WhatsAppQuotaService whatsappQuota;
  final WhatsAppService whatsapp;
  final SubscriptionService subscriptions;
  final SettingsRepository settings;
  final SyncService sync;

  static Future<DataLayer> open() async {
    final db = await AppDatabase.open();
    final outbox = OutboxRepository(db);
    final customers = CustomersRepository(db, outbox);
    final orders = OrdersRepository(db, outbox);
    final payments = PaymentsRepository(db, outbox);
    final notifications = NotificationsRepository(db);
    final settings = SettingsRepository(db);
    final subscriptions = SubscriptionService(settings);
    final planLimits = PlanLimitsService(settings);
    final freemium = FreemiumService(db, planLimits);
    final whatsappQuota = WhatsAppQuotaService(settings, planLimits);
    final whatsapp = WhatsAppService(
      subscriptions: subscriptions,
      quota: whatsappQuota,
    );
    final sync = SyncService(
      db: db,
      outbox: outbox,
      connectivity: Connectivity(),
      planLimits: planLimits,
      subscriptions: subscriptions,
    );
    final layer = DataLayer._(
      db: db,
      outbox: outbox,
      customers: customers,
      orders: orders,
      payments: payments,
      notifications: notifications,
      freemium: freemium,
      planLimits: planLimits,
      whatsappQuota: whatsappQuota,
      whatsapp: whatsapp,
      subscriptions: subscriptions,
      settings: settings,
      sync: sync,
    );
    await layer.subscriptions.syncEntitlement();
    await layer.planLimits.refreshFromRemote();
    await layer.notifications.refreshDueReminders();
    return layer;
  }

  Future<void> clearLocalData() => db.clearLocalData();

  Future<void> close() => db.close();
}
