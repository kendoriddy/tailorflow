import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/update_password_screen.dart';
import 'features/customers/customer_list_screen.dart';

class TailorFlowApp extends ConsumerWidget {
  const TailorFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'TailorFlow NG',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

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
      return const CustomerListScreen();
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
        return const CustomerListScreen();
      },
    );
  }
}
