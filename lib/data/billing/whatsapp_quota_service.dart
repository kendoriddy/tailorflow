import 'dart:convert';

import '../repos/settings_repository.dart';
import 'plan_limits_service.dart';

/// Tracks WhatsApp handoffs per calendar month for free-tier enforcement.
class WhatsAppQuotaService {
  WhatsAppQuotaService(this._settings, this._plans);

  final SettingsRepository _settings;
  final PlanLimitsService _plans;

  static const _usageKey = 'whatsapp_usage_json';

  static String _periodKey(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}';

  Future<int> usedThisMonth() async {
    final raw = await _settings.get(_usageKey);
    if (raw == null || raw.isEmpty) return 0;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final period = map['period'] as String?;
      if (period != _periodKey(DateTime.now())) return 0;
      return (map['count'] as int?) ?? int.tryParse('${map['count']}') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> recordSend() async {
    final period = _periodKey(DateTime.now());
    final used = await usedThisMonth();
    await _settings.set(
      _usageKey,
      jsonEncode({'period': period, 'count': used + 1}),
    );
  }

  /// `null` when subscribed or unlimited; otherwise remaining sends.
  Future<int?> remainingForFreeTier({required bool subscribed}) async {
    if (subscribed) return null;
    final config = await _plans.getConfig();
    if (config.freeWhatsAppUnlimited) return null;
    final used = await usedThisMonth();
    final left = config.freeWhatsAppMonthlyLimit - used;
    return left < 0 ? 0 : left;
  }

  Future<bool> canSend({required bool subscribed}) async {
    if (subscribed) return true;
    final config = await _plans.getConfig();
    if (config.freeWhatsAppUnlimited) return true;
    final used = await usedThisMonth();
    return used < config.freeWhatsAppMonthlyLimit;
  }
}
