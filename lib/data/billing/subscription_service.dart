import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repos/settings_repository.dart';
import 'subscription_pricing.dart';
import 'subscription_status.dart';

class SubscriptionCheckout {
  const SubscriptionCheckout({
    required this.authorizationUrl,
    required this.reference,
    required this.plan,
  });

  final String authorizationUrl;
  final String reference;
  final SubscriptionPlan plan;
}

/// Paystack subscriptions via Supabase Edge Functions.
class SubscriptionService {
  SubscriptionService(this._settings);

  final SettingsRepository _settings;

  static const _keyStatus = 'subscription_status';
  static const _keyPlan = 'subscription_plan';
  static const _keyPeriodEnd = 'subscription_period_end';

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isConfigured {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anon = String.fromEnvironment('SUPABASE_ANON_KEY');
    return url.isNotEmpty && anon.isNotEmpty && _client != null;
  }

  Future<bool> isSignedIn() async {
    final client = _client;
    return client?.auth.currentSession != null;
  }

  /// Local + cached period check (works offline after last sync).
  Future<bool> isActive() async {
    final status = await _settings.get(_keyStatus);
    if (status != 'active') {
      return await _settings.isSubscribed();
    }
    final endRaw = await _settings.get(_keyPeriodEnd);
    if (endRaw == null || endRaw.isEmpty) return true;
    final end = DateTime.tryParse(endRaw);
    if (end == null) return true;
    if (end.isAfter(DateTime.now())) return true;
    return false;
  }

  Future<ShopSubscriptionStatus> fetchStatus() async {
    if (!isConfigured || !await isSignedIn()) {
      final active = await isActive();
      if (!active) return ShopSubscriptionStatus.inactive;
      return ShopSubscriptionStatus(
        isActive: true,
        status: 'active',
        plan: _planFromSettings(await _settings.get(_keyPlan)),
        periodEnd: DateTime.tryParse(
          (await _settings.get(_keyPeriodEnd)) ?? '',
        ),
      );
    }

    final client = _client!;
    try {
      await client.rpc('bootstrap_current_user_shop');
      final shopId = await _currentShopId(client);
      if (shopId == null) return ShopSubscriptionStatus.inactive;

      final rows = (await client
          .from('shops')
          .select(
            'subscription_status, subscription_plan, subscription_period_end',
          )
          .eq('id', shopId)
          .limit(1)) as List<dynamic>;

      if (rows.isEmpty) return ShopSubscriptionStatus.inactive;
      final row = rows.first as Map<String, dynamic>;
      final status = '${row['subscription_status'] ?? 'free'}';
      final plan = _planFromSettings(row['subscription_plan'] as String?);
      final periodEnd = _parsePeriodEnd(row['subscription_period_end']);

      final active = status == 'active' &&
          (periodEnd == null || periodEnd.isAfter(DateTime.now()));

      await _cacheLocally(
        active: active,
        status: status,
        plan: plan,
        periodEnd: periodEnd,
      );

      return ShopSubscriptionStatus(
        isActive: active,
        status: status,
        plan: plan,
        periodEnd: periodEnd,
      );
    } catch (e) {
      debugPrint('TailorFlow subscription fetch: $e');
      final active = await isActive();
      return ShopSubscriptionStatus(
        isActive: active,
        status: active ? 'active' : 'free',
        plan: _planFromSettings(await _settings.get(_keyPlan)),
        periodEnd: DateTime.tryParse(
          (await _settings.get(_keyPeriodEnd)) ?? '',
        ),
      );
    }
  }

  Future<void> syncEntitlement() async {
    final status = await fetchStatus();
    await _settings.setSubscribed(status.isActive);
  }

  Future<SubscriptionCheckout> startCheckout(SubscriptionPlan plan) async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) {
      throw StateError('Sign in with cloud backup to subscribe.');
    }

    final res = await client.functions.invoke(
      'paystack-initialize',
      body: {'plan': plan.apiValue},
    );

    if (res.status != 200) {
      final err = res.data is Map ? (res.data as Map)['error'] : res.data;
      throw Exception(err ?? 'Could not start Paystack checkout');
    }

    final data = res.data as Map<String, dynamic>;
    return SubscriptionCheckout(
      authorizationUrl: data['authorization_url'] as String,
      reference: data['reference'] as String,
      plan: plan,
    );
  }

  Future<bool> verifyCheckout(String reference) async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) {
      throw StateError('Sign in to verify payment.');
    }

    final res = await client.functions.invoke(
      'paystack-verify',
      body: {'reference': reference},
    );

    final data = res.data;
    if (res.status != 200) {
      final err = data is Map ? data['error'] : data;
      throw Exception(err ?? 'Payment verification failed');
    }

    final active = (data is Map && data['active'] == true);
    if (active) {
      await _cacheLocally(
        active: true,
        status: 'active',
        plan: _planFromSettings(data['plan'] as String?),
        periodEnd: null,
      );
      await _settings.setSubscribed(true);
    }
    return active;
  }

  Future<String?> _currentShopId(SupabaseClient client) async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final rows = (await client
        .from('shop_memberships')
        .select('shop_id')
        .eq('user_id', user.id)
        .limit(1)) as List<dynamic>;
    if (rows.isEmpty) return null;
    return '${(rows.first as Map<String, dynamic>)['shop_id']}';
  }

  SubscriptionPlan? _planFromSettings(String? raw) {
    if (raw == 'monthly') return SubscriptionPlan.monthly;
    if (raw == 'yearly') return SubscriptionPlan.yearly;
    return null;
  }

  DateTime? _parsePeriodEnd(Object? raw) {
    if (raw == null) return null;
    if (raw is String) return DateTime.tryParse(raw);
    return DateTime.tryParse('$raw');
  }

  Future<void> _cacheLocally({
    required bool active,
    required String status,
    SubscriptionPlan? plan,
    DateTime? periodEnd,
  }) async {
    await _settings.set(_keyStatus, status);
    await _settings.setSubscribed(active);
    if (plan != null) {
      await _settings.set(_keyPlan, plan.apiValue);
    }
    if (periodEnd != null) {
      await _settings.set(_keyPeriodEnd, periodEnd.toUtc().toIso8601String());
    }
  }
}
