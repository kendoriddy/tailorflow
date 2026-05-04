import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});

  final VoidCallback onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _isSignUp = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool get _looksLikeEmail => _identifier.text.trim().contains('@');
  bool get _isPhoneInput => !_looksLikeEmail;

  String? _identifierHintError(String identifier) {
    if (identifier.isEmpty) return 'Enter email or phone number.';
    if (_looksLikeEmail) {
      final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(identifier);
      return ok ? null : 'Enter a valid email address.';
    }
    final digits = identifier.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      return 'Phone is too short. Example: 08012345678';
    }
    return null;
  }

  String? _passwordHintError(String password) {
    if (password.isEmpty) return 'Enter password.';
    if (password.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  String _toE164Phone(String raw) {
    final t = raw.trim();
    if (t.startsWith('+')) return t;
    final digits = t.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('234')) return '+$digits';
    if (digits.startsWith('0') && digits.length == 11) {
      return '+234${digits.substring(1)}';
    }
    if (digits.length == 10) return '+234$digits';
    return '+$digits';
  }

  Future<void> _submit() async {
    final identifier = _identifier.text.trim();
    final password = _password.text;
    final identifierErr = _identifierHintError(identifier);
    final passwordErr = _passwordHintError(password);
    if (identifierErr != null || passwordErr != null) {
      setState(() => _error = identifierErr ?? passwordErr);
      return;
    }
    if (_isSignUp && _confirmPassword.text != password) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });

    final client = Supabase.instance.client;
    try {
      if (_isSignUp) {
        final AuthResponse res;
        if (_looksLikeEmail) {
          res = await client.auth.signUp(email: identifier, password: password);
        } else {
          res = await client.auth.signUp(
            phone: _toE164Phone(identifier),
            password: password,
          );
        }
        if (res.session == null) {
          setState(() {
            _info =
                'Account created. Verify your account if confirmation is enabled, then sign in.';
          });
        } else {
          await client.rpc('bootstrap_current_user_shop');
          widget.onAuthenticated();
        }
      } else {
        if (_looksLikeEmail) {
          await client.auth.signInWithPassword(
            email: identifier,
            password: password,
          );
        } else {
          await client.auth.signInWithPassword(
            phone: _toE164Phone(identifier),
            password: password,
          );
        }
        await client.rpc('bootstrap_current_user_shop');
        widget.onAuthenticated();
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailCtl = TextEditingController(
      text: _looksLikeEmail ? _identifier.text.trim() : '',
    );
    String? dialogError;
    var sending = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> send() async {
              final email = emailCtl.text.trim();
              final okEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
              if (!okEmail) {
                setDialogState(() => dialogError = 'Enter a valid email address.');
                return;
              }
              setDialogState(() {
                sending = true;
                dialogError = null;
              });
              try {
                final client = Supabase.instance.client;
                final redirectTo = kIsWeb ? Uri.base.removeFragment().toString() : null;
                await client.auth.resetPasswordForEmail(
                  email,
                  redirectTo: redirectTo,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop();
                setState(() {
                  _info =
                      'Password reset link sent. Open your email and follow the link.';
                });
              } on AuthException catch (e) {
                setDialogState(() => dialogError = e.message);
              } catch (e) {
                setDialogState(() => dialogError = e.toString());
              } finally {
                if (context.mounted) {
                  setDialogState(() => sending = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Forgot password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter your account email to receive a password reset link.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    onSubmitted: (_) => send(),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      dialogError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: sending ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: sending ? null : send,
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send link'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSignUp ? 'Create account' : 'Sign in';
    final action = _isSignUp ? 'Sign up' : 'Sign in';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 12),
              TextField(
                controller: _identifier,
                keyboardType: _isPhoneInput
                    ? TextInputType.phone
                    : TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                decoration: InputDecoration(
                  labelText: 'Email or phone',
                  hintText: 'name@email.com or 08012345678',
                  helperText: _isPhoneInput
                      ? 'Phone accepts 080..., 234..., or +234...'
                      : 'Use the same email used during sign up.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                  labelText: 'Password',
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (_isSignUp) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPassword,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(action),
              ),
              const SizedBox(height: 8),
              if (!_isSignUp)
                TextButton(
                  onPressed: _busy ? null : _showForgotPasswordDialog,
                  child: const Text('Forgot password?'),
                ),
              if (!_isSignUp) const SizedBox(height: 4),
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {
                          _isSignUp = !_isSignUp;
                          _error = null;
                          _info = null;
                          _confirmPassword.clear();
                        });
                      },
                child: Text(
                  _isSignUp
                      ? 'Already have an account? Sign in'
                      : 'No account yet? Create one',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_info != null) ...[
                const SizedBox(height: 8),
                Text(
                  _info!,
                  style: const TextStyle(color: Colors.green),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
