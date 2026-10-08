import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/navigation.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AuthService.instance.changePassword(_current.text, _next.text);
      toast('Password changed', kind: ToastKind.success);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password', prefixIcon: Icon(Icons.lock_outline_rounded)),
              validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'New password', helperText: 'At least 6 characters', prefixIcon: Icon(Icons.key_rounded)),
              validator: (v) => (v ?? '').length < 6 ? 'Use at least 6 characters' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.key_rounded)),
              validator: (v) => v != _next.text ? 'Passwords don\'t match' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                  : const Text('Update password'),
            ),
          ],
        ),
      ),
    );
  }
}
