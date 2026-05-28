import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_routes.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return AuthShell(
            title: 'Welcome back',
            subtitle: 'Sign in to manage and share\nyour shopping lists.',
            children: [
              TextFormField(
                controller: _emailController,
                enabled: !authProvider.isLoading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                enabled: !authProvider.isLoading,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                  ),
                ),
                validator: _validatePassword,
                onFieldSubmitted: (_) => _submitLogin(authProvider),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: authProvider.isLoading
                      ? null
                      : () => _resetPassword(authProvider),
                  child: const Text('Forgot password?'),
                ),
              ),
              if (authProvider.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  authProvider.errorMessage!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: authProvider.isLoading
                    ? null
                    : () => _submitLogin(authProvider),
                iconAlignment: IconAlignment.end,
                icon: authProvider.isLoading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.arrow_forward),
                label: authProvider.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Login'),
              ),
              const SizedBox(height: 18),
              const AuthDivider(),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: authProvider.isLoading
                    ? null
                    : () {
                        authProvider.clearError();
                        Navigator.pushNamed(context, AppRoutes.signup);
                      },
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Create account'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitLogin(AuthProvider authProvider) async {
    FocusScope.of(context).unfocus();
    authProvider.clearError();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await authProvider.login(_emailController.text, _passwordController.text);

    if (!mounted) {
      return;
    }

    if (authProvider.isAuthenticated) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
      return;
    }

    if (authProvider.errorMessage != null) {
      _showSnackBar(authProvider.errorMessage!);
    }
  }

  Future<void> _resetPassword(AuthProvider authProvider) async {
    FocusScope.of(context).unfocus();
    authProvider.clearError();

    final emailError = _validateEmail(_emailController.text);
    if (emailError != null) {
      _showSnackBar(emailError);
      return;
    }

    await authProvider.resetPassword(_emailController.text);

    if (!mounted) {
      return;
    }

    if (authProvider.errorMessage != null) {
      _showSnackBar(authProvider.errorMessage!);
      return;
    }

    _showSnackBar('Password reset email sent.');
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Email is required.';
    }

    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Password is required.';
    }

    return null;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
