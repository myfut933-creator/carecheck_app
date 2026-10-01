import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/validators.dart';
import '../widgets/error_banner.dart';

/// Screen 2: Register.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    final ok = await context
        .read<AuthProvider>()
        .register(_name.text, _email.text, _password.text);
    // Account creation signs the user in; AuthGate now shows Home, so remove
    // this screen from the stack.
    if (ok) navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (auth.error != null) ErrorBanner(auth.error!),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                      labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                  validator: Validators.name,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                      labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  validator: Validators.email,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                      labelText: 'Password (6+ characters)',
                      prefixIcon: Icon(Icons.lock_outline)),
                  validator: Validators.password,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                      labelText: 'Confirm password',
                      prefixIcon: Icon(Icons.lock_outline)),
                  validator: (v) =>
                      v != _password.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: auth.busy ? null : _submit,
                  child: auth.busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
