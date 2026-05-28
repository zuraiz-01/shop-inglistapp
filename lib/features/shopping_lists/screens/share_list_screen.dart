import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/shopping_list_model.dart';
import '../providers/shopping_lists_provider.dart';

class ShareListScreen extends StatefulWidget {
  const ShareListScreen({super.key});

  @override
  State<ShareListScreen> createState() => _ShareListScreenState();
}

class _ShareListScreenState extends State<ShareListScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  String _permission = 'viewer';
  bool _didReadArguments = false;
  bool _shareSucceeded = false;
  ShoppingListModel? _list;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didReadArguments) {
      return;
    }

    _didReadArguments = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    final provider = context.read<ShoppingListsProvider>();

    if (args is ShoppingListModel) {
      _list = args;
      return;
    }

    if (args is String && args.isNotEmpty) {
      for (final list in provider.lists) {
        if (list.id == args) {
          _list = list;
          return;
        }
      }
    }

    _list = provider.selectedList;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = context.watch<AuthProvider>().currentUser;
    final list = _list;
    final canShare = list != null && canManageMembers(list, currentUser?.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Share List')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Consumer<ShoppingListsProvider>(
                builder: (context, shoppingListsProvider, _) {
                  if (list == null) {
                    return _MessageState(
                      icon: Icons.list_alt_outlined,
                      title: 'Shopping list not found',
                      message: 'Go back and choose a list to share.',
                    );
                  }

                  if (!canShare) {
                    return _MessageState(
                      icon: Icons.lock_outline,
                      title: 'Owner access required',
                      message: 'Only the list owner can share this list.',
                    );
                  }

                  return Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.ios_share_outlined,
                            size: 34,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Share "${list.title}"',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add an existing app user by email and choose their access.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _emailController,
                          enabled: !shoppingListsProvider.isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'User email',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: _validateEmail,
                          onFieldSubmitted: (_) =>
                              _submit(shoppingListsProvider, list),
                        ),
                        const SizedBox(height: 18),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'viewer',
                              icon: Icon(Icons.visibility_outlined),
                              label: Text('Viewer'),
                            ),
                            ButtonSegment(
                              value: 'editor',
                              icon: Icon(Icons.edit_outlined),
                              label: Text('Editor'),
                            ),
                          ],
                          selected: {_permission},
                          onSelectionChanged: shoppingListsProvider.isLoading
                              ? null
                              : (selection) {
                                  setState(() {
                                    _permission = selection.first;
                                  });
                                },
                        ),
                        if (shoppingListsProvider.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            shoppingListsProvider.errorMessage!,
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                        if (_shareSucceeded) ...[
                          const SizedBox(height: 16),
                          Text(
                            'List shared successfully.',
                            style: TextStyle(color: colorScheme.primary),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: shoppingListsProvider.isLoading
                              ? null
                              : () => _submit(shoppingListsProvider, list),
                          child: shoppingListsProvider.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text('Share list'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: shoppingListsProvider.isLoading
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(
    ShoppingListsProvider shoppingListsProvider,
    ShoppingListModel list,
  ) async {
    FocusScope.of(context).unfocus();
    shoppingListsProvider.clearError();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _shareSucceeded = false;
    });

    await shoppingListsProvider.shareListByEmail(
      listId: list.id,
      email: _emailController.text,
      permission: _permission,
    );

    if (!mounted) {
      return;
    }

    if (shoppingListsProvider.errorMessage != null) {
      _showSnackBar(shoppingListsProvider.errorMessage!);
      return;
    }

    setState(() {
      _shareSucceeded = true;
    });
    _showSnackBar('List shared successfully.');

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      Navigator.pop(context);
    }
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: colorScheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
