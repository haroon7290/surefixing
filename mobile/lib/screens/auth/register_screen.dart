import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/auth_service.dart';

class _Role {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _Role(this.key, this.title, this.subtitle, this.icon, this.color);
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _roles = [
    _Role('client', 'I need repairs', 'Hire technicians and rent tools', Icons.home_repair_service_rounded, Color(0xFF2F54EB)),
    _Role('technician', 'I fix things', 'Get jobs and grow your business', Icons.engineering_rounded, Color(0xFF12B76A)),
    _Role('supplier', 'I rent out tools', 'List equipment and earn from rentals', Icons.storefront_rounded, Color(0xFFFF8A00)),
  ];

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _password = TextEditingController();
  String _role = 'client';
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _city, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.register(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        role: _role,
        phone: _phone.text.trim(),
        city: _city.text.trim(),
      );
      // The app root pops back to the new user's home automatically.
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text('How will you use SureFix?', style: context.text.titleMedium),
                  const SizedBox(height: 12),
                  for (final r in _roles) ...[
                    _RoleCard(role: r, selected: _role == r.key, onTap: () => setState(() => _role = r.key)),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 14),
                  Text('Your details', style: context.text.titleMedium),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: _role == 'supplier' ? 'Business or full name' : 'Full name',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                    validator: (v) => RegExp(r'^\S+@\S+\.\S+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _city,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(Icons.location_city_outlined)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      helperText: 'At least 6 characters',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v ?? '').length < 6 ? 'Use at least 6 characters' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: TextStyle(color: context.palette.danger, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : const Text('Create account'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _role == 'client'
                        ? 'You can start posting jobs right away.'
                        : 'Tip: complete your profile and verify your ID to rank higher and earn trust.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.palette.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final _Role role;
  final bool selected;
  final VoidCallback onTap;
  const _RoleCard({required this.role, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? role.color.withValues(alpha: 0.08) : context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? role.color : context.palette.border, width: selected ? 1.8 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: role.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(role.icon, color: role.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role.title, style: context.text.titleSmall?.copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(role.subtitle, style: TextStyle(color: context.palette.muted, fontSize: 13)),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  key: ValueKey(selected),
                  color: selected ? role.color : context.palette.subtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
