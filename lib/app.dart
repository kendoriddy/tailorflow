import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/brand.dart';
import 'core/branding_scope.dart';
import 'core/shop_branding.dart';
import 'core/theme/app_theme.dart';
import 'data/data_layer_provider.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/update_password_screen.dart';
import 'features/customers/customer_list_screen.dart';

class TailorFlowApp extends ConsumerStatefulWidget {
  const TailorFlowApp({super.key});

  @override
  ConsumerState<TailorFlowApp> createState() => _TailorFlowAppState();
}

class _TailorFlowAppState extends ConsumerState<TailorFlowApp> {
  int _brandingGeneration = 0;

  void _refreshBranding() => setState(() => _brandingGeneration++);

  @override
  Widget build(BuildContext context) {
    final layerAsync = ref.watch(dataLayerProvider);
    return layerAsync.when(
      loading: () => MaterialApp(
        title: Brand.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => MaterialApp(
        title: Brand.appName,
        home: Scaffold(body: Center(child: Text('Startup error:\n$e'))),
      ),
      data: (layer) => FutureBuilder<ShopBranding>(
        key: ValueKey(_brandingGeneration),
        future: ShopBranding.load(layer.settings),
        builder: (context, snap) {
          final branding = snap.data ??
              const ShopBranding(
                displayName: Brand.appName,
                shopNameForMessages: 'our shop',
                primaryColor: AppTheme.accentGreen,
              );
          return MaterialApp(
            title: branding.displayName,
            debugShowCheckedModeBanner: false,
            theme: branding.toTheme(),
            // Wrap all routes (home + pushed screens), not only [home].
            builder: (context, child) => BrandingScope(
              branding: branding,
              child: child ?? const SizedBox.shrink(),
            ),
            home: _AuthGate(onBrandingChanged: _refreshBranding),
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.onBrandingChanged});

  final VoidCallback onBrandingChanged;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _anon = String.fromEnvironment('SUPABASE_ANON_KEY');

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = _url.isNotEmpty && _anon.isNotEmpty && _client != null;
    if (!configured) {
      return CustomerListScreen(onBrandingChanged: widget.onBrandingChanged);
    }

    final client = _client!;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final event = snapshot.data?.event;
        if (event == AuthChangeEvent.passwordRecovery) {
          return UpdatePasswordScreen(
            onDone: () {
              if (mounted) setState(() {});
            },
          );
        }
        if (client.auth.currentSession == null) {
          return AuthScreen(
            onAuthenticated: () {
              if (mounted) setState(() {});
            },
          );
        }
        return CustomerListScreen(onBrandingChanged: widget.onBrandingChanged);
      },
    );
  }
}
