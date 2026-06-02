import 'package:flutter/material.dart';

import 'shop_branding.dart';

/// Inherited widget so screens can read the shop display name and logo.
class BrandingScope extends InheritedWidget {
  const BrandingScope({
    super.key,
    required this.branding,
    required super.child,
  });

  final ShopBranding branding;

  static ShopBranding of(BuildContext context) {
    final branding = maybeOf(context);
    assert(branding != null, 'BrandingScope not found');
    return branding!;
  }

  /// Returns null when [BrandingScope] is not an ancestor (should not happen).
  static ShopBranding? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<BrandingScope>()
        ?.branding;
  }

  @override
  bool updateShouldNotify(BrandingScope oldWidget) {
    return branding.displayName != oldWidget.branding.displayName ||
        branding.primaryColor != oldWidget.branding.primaryColor ||
        branding.logoFile?.path != oldWidget.branding.logoFile?.path;
  }
}
