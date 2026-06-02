import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repos/settings_repository.dart';
import 'plan_config.dart';

/// Loads plan limits from local cache, then refreshes from Supabase when online.
class PlanLimitsService {
  PlanLimitsService(this._settings);

  final SettingsRepository _settings;

  static const _cacheKey = 'plan_config_json';

  Future<PlanConfig> getConfig() async {
    final raw = await _settings.get(_cacheKey);
    if (raw == null || raw.isEmpty) return PlanConfig.defaults;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return PlanConfig.fromJson(map);
    } catch (e) {
      debugPrint('TailorFlow: invalid plan_config_json: $e');
      return PlanConfig.defaults;
    }
  }

  Future<void> _cache(PlanConfig config) async {
    await _settings.set(_cacheKey, jsonEncode(config.toJson()));
  }

  /// Pulls global limits from `platform_config` (admin-editable in Supabase).
  Future<bool> refreshFromRemote() async {
    SupabaseClient? client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      return false;
    }
    if (client.auth.currentUser == null) return false;

    try {
      final rows = (await client.from('platform_config').select('key, value'))
          as List<dynamic>;
      if (rows.isEmpty) return false;

      var config = await getConfig();
      for (final row in rows) {
        final m = row as Map<String, dynamic>;
        final key = m['key'] as String?;
        final value = m['value'] as String?;
        if (key == null || value == null) continue;
        switch (key) {
          case PlanConfigKeys.freeMaxActiveCustomers:
            final n = int.tryParse(value);
            if (n != null && n > 0) {
              config = config.copyWith(freeMaxActiveCustomers: n);
            }
          case PlanConfigKeys.freeWhatsAppMonthlyLimit:
            final n = int.tryParse(value);
            if (n != null) {
              config = config.copyWith(freeWhatsAppMonthlyLimit: n);
            }
        }
      }
      await _cache(config);
      return true;
    } catch (e) {
      debugPrint('TailorFlow: platform_config fetch failed: $e');
      return false;
    }
  }
}
