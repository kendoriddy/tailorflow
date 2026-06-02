import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/repos/settings_repository.dart';
import 'brand.dart';
import '../core/theme/app_theme.dart';

/// Per-shop white-label settings stored in [shop_settings].
class ShopBranding {
  const ShopBranding({
    required this.displayName,
    required this.shopNameForMessages,
    required this.primaryColor,
    this.logoFile,
  });

  final String displayName;
  final String shopNameForMessages;
  final Color primaryColor;
  final File? logoFile;

  static const _keyDisplayName = 'brand_display_name';
  static const _keyShopName = 'brand_shop_name';
  static const _keyPrimaryColor = 'brand_primary_color';
  static const _logoFileName = 'brand_logo.png';

  static Future<ShopBranding> load(SettingsRepository settings) async {
    final display = await settings.get(_keyDisplayName);
    final shop = await settings.get(_keyShopName);
    final colorHex = await settings.get(_keyPrimaryColor);

    File? logo;
    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File(p.join(dir.path, _logoFileName));
        if (await file.exists()) logo = file;
      } catch (_) {}
    }

    return ShopBranding(
      displayName: (display?.trim().isNotEmpty == true)
          ? display!.trim()
          : Brand.appName,
      shopNameForMessages: (shop?.trim().isNotEmpty == true)
          ? shop!.trim()
          : ((display?.trim().isNotEmpty == true)
              ? display!.trim()
              : 'our shop'),
      primaryColor: _parseColor(colorHex) ?? AppTheme.accentGreen,
      logoFile: logo,
    );
  }

  static Future<void> saveDisplayName(
    SettingsRepository settings,
    String name,
  ) async {
    await settings.set(_keyDisplayName, name.trim());
  }

  static Future<void> saveShopName(
    SettingsRepository settings,
    String name,
  ) async {
    await settings.set(_keyShopName, name.trim());
  }

  static Future<void> savePrimaryColor(
    SettingsRepository settings,
    Color color,
  ) async {
    final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
    await settings.set(_keyPrimaryColor, '#$hex');
  }

  static Future<File> logoTargetPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _logoFileName));
  }

  static Future<void> saveLogoFromPath(String sourcePath) async {
    final target = await logoTargetPath();
    await File(sourcePath).copy(target.path);
  }

  static Future<void> clearLogo() async {
    final target = await logoTargetPath();
    if (await target.exists()) await target.delete();
  }

  static Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var s = hex.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    final value = int.tryParse(s, radix: 16);
    if (value == null) return null;
    return Color(value);
  }

  ThemeData toTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        error: AppTheme.oweRed,
      ),
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: false,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: const Color(0xFF1A1A1A),
        displayColor: const Color(0xFF1A1A1A),
      ),
    );
  }
}
