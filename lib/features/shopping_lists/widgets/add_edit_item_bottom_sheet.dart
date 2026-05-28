import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/shopping_item_model.dart';
import '../providers/shopping_lists_provider.dart';

class AddEditItemBottomSheet extends StatefulWidget {
  const AddEditItemBottomSheet({required this.listId, this.item, super.key});

  final String listId;
  final ShoppingItemModel? item;

  @override
  State<AddEditItemBottomSheet> createState() => _AddEditItemBottomSheetState();
}

class _AddEditItemBottomSheetState extends State<AddEditItemBottomSheet> {
  static const _units = [
    'piece',
    'kg',
    'gram',
    'liter',
    'ml',
    'pack',
    'bottle',
    'box',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _categoryController;
  late final TextEditingController _notesController;

  late String _selectedUnit;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();

    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _quantityController = TextEditingController(
      text: item == null ? '1' : _formatNumber(item.quantity),
    );
    _priceController = TextEditingController(
      text: item?.price == null ? '' : _formatNumber(item!.price!),
    );
    _categoryController = TextEditingController(text: item?.category ?? '');
    _notesController = TextEditingController(text: item?.notes ?? '');
    _selectedUnit = _units.contains(item?.unit) ? item!.unit : _units.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<ShoppingListsProvider>(
      builder: (context, shoppingListsProvider, _) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isEditing ? 'Edit item' : 'Add item',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: shoppingListsProvider.isLoading
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    enabled: !shoppingListsProvider.isLoading,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Item name',
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                    ),
                    validator: _requiredValidator('Item name is required.'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _quantityController,
                          enabled: !shoppingListsProvider.isLoading,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            prefixIcon: Icon(Icons.scale_outlined),
                          ),
                          validator: _validateQuantity,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            prefixIcon: Icon(Icons.straighten),
                          ),
                          items: _units.map((unit) {
                            return DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            );
                          }).toList(),
                          onChanged: shoppingListsProvider.isLoading
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _selectedUnit = value;
                                  });
                                },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _priceController,
                    enabled: !shoppingListsProvider.isLoading,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      hintText: 'Optional',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    validator: _validateOptionalPrice,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _categoryController,
                    enabled: !shoppingListsProvider.isLoading,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      hintText: 'Optional',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesController,
                    enabled: !shoppingListsProvider.isLoading,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Optional',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  if (shoppingListsProvider.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      shoppingListsProvider.errorMessage!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: shoppingListsProvider.isLoading
                        ? null
                        : () => _save(shoppingListsProvider),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: shoppingListsProvider.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(_isEditing ? 'Save changes' : 'Add item'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save(ShoppingListsProvider shoppingListsProvider) async {
    FocusScope.of(context).unfocus();
    shoppingListsProvider.clearError();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.currentUser?.uid;
    final existingItem = widget.item;

    if (currentUserId == null && existingItem == null) {
      _showSnackBar('You must be signed in to add items.');
      return;
    }

    final now = DateTime.now();
    final item = ShoppingItemModel(
      id: existingItem?.id ?? '',
      listId: widget.listId,
      name: _nameController.text.trim(),
      quantity: double.parse(_quantityController.text.trim()),
      unit: _selectedUnit,
      price: _nullableDouble(_priceController.text),
      category: _emptyToNull(_categoryController.text),
      notes: _emptyToNull(_notesController.text),
      isCompleted: existingItem?.isCompleted ?? false,
      createdBy: existingItem?.createdBy ?? currentUserId ?? '',
      createdAt: existingItem?.createdAt ?? now,
      updatedAt: now,
    );

    if (_isEditing) {
      await shoppingListsProvider.updateItem(widget.listId, item);
    } else {
      await shoppingListsProvider.addItem(widget.listId, item);
    }

    if (!mounted) {
      return;
    }

    if (shoppingListsProvider.errorMessage != null) {
      _showSnackBar(shoppingListsProvider.errorMessage!);
      return;
    }

    Navigator.pop(context);
  }

  String? Function(String?) _requiredValidator(String message) {
    return (value) {
      if ((value?.trim() ?? '').isEmpty) {
        return message;
      }

      return null;
    };
  }

  String? _validateQuantity(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Quantity is required.';
    }

    final quantity = double.tryParse(text);
    if (quantity == null || quantity <= 0) {
      return 'Quantity must be greater than 0.';
    }

    return null;
  }

  String? _validateOptionalPrice(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }

    final price = double.tryParse(text);
    if (price == null || price < 0) {
      return 'Enter a valid price.';
    }

    return null;
  }

  double? _nullableDouble(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }

    return double.parse(text);
  }

  String? _emptyToNull(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  String _formatNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
