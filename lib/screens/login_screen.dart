import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/validators.dart';
import '../widgets/error_banner.dart';
import 'register_screen.dart';

/// Screen 1: Login.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    // AuthGate switches to Home automatically when sign-in succeeds.
    await context.read<AuthProvider>().signIn(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.verified_user,
                        size: 64, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 8),
                    Text('CareCheck',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    const Text('Verified visits. Safer care.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    if (auth.error != null) ErrorBanner(auth.error!),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                          labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                      validator: Validators.password,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: auth.busy ? null : _submit,
                      child: auth.busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: auth.busy
                          ? null
                          : () {
                              context.read<AuthProvider>().clearError();
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const RegisterScreen()));
                            },
                      child: const Text('New here? Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
