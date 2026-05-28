import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/shopping_lists_provider.dart';

class CreateListScreen extends StatefulWidget {
  const CreateListScreen({super.key});

  @override
  State<CreateListScreen> createState() => _CreateListScreenState();
}

class _CreateListScreenState extends State<CreateListScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create List')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Consumer<ShoppingListsProvider>(
                  builder: (context, shoppingListsProvider, _) {
                    return Column(
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
                            Icons.playlist_add,
                            size: 34,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'New shopping list',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a list to add items and share it with others.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _titleController,
                          enabled: !shoppingListsProvider.isLoading,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'List title',
                            prefixIcon: Icon(Icons.title),
                          ),
                          validator: _validateTitle,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          enabled: !shoppingListsProvider.isLoading,
                          minLines: 3,
                          maxLines: 5,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'Optional',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                        if (shoppingListsProvider.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            shoppingListsProvider.errorMessage!,
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: shoppingListsProvider.isLoading
                              ? null
                              : () => _submit(shoppingListsProvider),
                          child: shoppingListsProvider.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text('Create list'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: shoppingListsProvider.isLoading
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(ShoppingListsProvider shoppingListsProvider) async {
    FocusScope.of(context).unfocus();
    shoppingListsProvider.clearError();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentUser == null) {
      _showSnackBar('You must be signed in to create a shopping list.');
      return;
    }

    await shoppingListsProvider.createList(
      _titleController.text,
      _descriptionController.text,
    );

    if (!mounted) {
      return;
    }

    if (shoppingListsProvider.errorMessage != null) {
      _showSnackBar(shoppingListsProvider.errorMessage!);
      return;
    }

    Navigator.pop(context);
  }

  String? _validateTitle(String? value) {
    final title = value?.trim() ?? '';

    if (title.isEmpty) {
      return 'Title is required.';
    }

    if (title.length < 2) {
      return 'Title must be at least 2 characters.';
    }

    return null;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
