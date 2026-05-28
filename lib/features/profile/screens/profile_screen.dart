import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_routes.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _appVersion = 'Version 1.0.0';

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ProfileProvider>(
      builder: (context, authProvider, profileProvider, _) {
        final user = authProvider.currentUser;

        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: SafeArea(
            child: user == null
                ? _SignedOutState(onLogin: () => _goToLogin(context))
                : _ProfileBody(
                    user: user,
                    appVersion: _appVersion,
                    isLoading:
                        authProvider.isLoading || profileProvider.isLoading,
                    errorMessage:
                        profileProvider.errorMessage ??
                        authProvider.errorMessage,
                    onClearError: () {
                      profileProvider.clearError();
                      authProvider.clearError();
                    },
                    onEditProfile: () => _showEditProfileDialog(
                      context: context,
                      user: user,
                      authProvider: authProvider,
                      profileProvider: profileProvider,
                    ),
                    onLogout: () => _logout(context, authProvider),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _showEditProfileDialog({
    required BuildContext context,
    required UserModel user,
    required AuthProvider authProvider,
    required ProfileProvider profileProvider,
  }) async {
    final updatedName = await showDialog<String>(
      context: context,
      builder: (context) => _EditProfileDialog(initialName: user.name),
    );

    if (updatedName == null || updatedName == user.name) {
      return;
    }

    final success = await profileProvider.updateDisplayName(
      uid: user.uid,
      name: updatedName,
    );

    if (!context.mounted) {
      return;
    }

    if (!success) {
      _showSnackBar(
        context,
        profileProvider.errorMessage ?? 'Could not update your profile.',
      );
      return;
    }

    authProvider.updateCurrentUserName(updatedName);
    _showSnackBar(context, 'Profile updated.');
  }

  Future<void> _logout(BuildContext context, AuthProvider authProvider) async {
    await authProvider.logout();

    if (!context.mounted) {
      return;
    }

    if (authProvider.errorMessage != null) {
      _showSnackBar(context, authProvider.errorMessage!);
      return;
    }

    _goToLogin(context);
  }

  void _goToLogin(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Display name',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (value) {
            if ((value?.trim() ?? '').isEmpty) {
              return 'Display name is required.';
            }

            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.user,
    required this.appVersion,
    required this.isLoading,
    required this.errorMessage,
    required this.onClearError,
    required this.onEditProfile,
    required this.onLogout,
  });

  final UserModel user;
  final String appVersion;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onClearError;
  final VoidCallback onEditProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = user.name.trim().isNotEmpty
        ? user.name.trim().characters.first.toUpperCase()
        : '?';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Center(
          child: CircleAvatar(
            radius: 42,
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            child: Text(
              initial,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.name,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        if (errorMessage != null) ...[
          _ErrorBanner(message: errorMessage!, onDismissed: onClearError),
          const SizedBox(height: 16),
        ],
        _ProfileInfoTile(
          icon: Icons.badge_outlined,
          title: 'Display name',
          value: user.name,
        ),
        const SizedBox(height: 10),
        _ProfileInfoTile(
          icon: Icons.mail_outline,
          title: 'Email',
          value: user.email,
        ),
        const SizedBox(height: 10),
        _ProfileInfoTile(
          icon: Icons.info_outline,
          title: 'App version',
          value: appVersion,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: isLoading ? null : onEditProfile,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit Profile'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: isLoading ? null : onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedOutState extends StatelessWidget {
  const _SignedOutState({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 56,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'You are signed out',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onLogin, child: const Text('Go to Login')),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismissed});

  final String message;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
          IconButton(
            onPressed: onDismissed,
            icon: const Icon(Icons.close),
            color: colorScheme.onErrorContainer,
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}
