import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/navigation.dart';
import '../../widgets/brand.dart';
import 'register_screen.dart';

/// Demo shortcuts appear in debug builds, or in any build made with
/// --dart-define=DEMO=true (handy for presentations).
const _showDemo = kDebugMode || bool.fromEnvironment('DEMO');

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = AuthService.instance.sessionEndedReason;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.login(_email.text.trim(), _password.text);
      // RootGate swaps to the home screen when the session starts.
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fillDemo(String email) {
    _email.text = email;
    _password.text = 'password123';
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: heroGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LogoMark(size: 60),
                      const SizedBox(height: 22),
                      const Wordmark(size: 34, color: Colors.white),
                      const SizedBox(height: 8),
                      Text(
                        'Reliable technicians and tool rentals,\nall in one place.',
                        style: context.text.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Welcome back', style: context.text.headlineSmall),
                        const SizedBox(height: 4),
                        Text('Log in to continue', style: TextStyle(color: context.palette.muted)),
                        const SizedBox(height: 24),
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.palette.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              Icon(Icons.error_outline_rounded, color: context.palette.danger, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_error!, style: TextStyle(color: context.palette.danger, fontWeight: FontWeight.w600))),
                            ]),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                          validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email',
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'Show password' : 'Hide password',
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
                        ),
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                              : const Text('Log in'),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('New to SureFix?', style: TextStyle(color: context.palette.muted)),
                            TextButton(
                              onPressed: () => push(context, const RegisterScreen()),
                              child: const Text('Create an account'),
                            ),
                          ],
                        ),
                        if (_showDemo) ...[
                          const SizedBox(height: 18),
                          Row(children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Try a demo account',
                                  style: TextStyle(color: context.palette.subtle, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ),
                            const Expanded(child: Divider()),
                          ]),
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final d in const [
                                ('Client', 'client@demo.com', Icons.person_rounded),
                                ('Technician', 'tech@demo.com', Icons.engineering_rounded),
                                ('Supplier', 'supplier@demo.com', Icons.storefront_rounded),
                                ('Admin', 'admin@demo.com', Icons.admin_panel_settings_rounded),
                              ])
                                ActionChip(
                                  avatar: Icon(d.$3, size: 18, color: context.colors.primary),
                                  label: Text(d.$1),
                                  onPressed: _loading ? null : () => _fillDemo(d.$2),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
