import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/shopping_item_model.dart';
import '../models/shopping_list_model.dart';
import '../providers/shopping_lists_provider.dart';

class ListDetailScreen extends StatefulWidget {
  const ListDetailScreen({super.key});

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  String? _activeListId;
  bool _didReadArguments = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didReadArguments) {
      return;
    }

    _didReadArguments = true;
    final provider = context.read<ShoppingListsProvider>();
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is ShoppingListModel) {
      _activeListId = args.id;
      provider.selectList(args);
      provider.listenToItems(args.id);
      return;
    }

    if (args is String && args.isNotEmpty) {
      _activeListId = args;
      final matchingList = provider.lists
          .where((list) => list.id == args)
          .cast<ShoppingListModel?>()
          .firstWhere((list) => list != null, orElse: () => null);

      if (matchingList != null) {
        provider.selectList(matchingList);
      }

      provider.listenToItems(args);
      return;
    }

    final selectedList = provider.selectedList;
    if (selectedList != null) {
      _activeListId = selectedList.id;
      provider.listenToItems(selectedList.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShoppingListsProvider>(
      builder: (context, provider, _) {
        final list = _currentList(provider);
        final listId = list?.id ?? _activeListId;

        return Scaffold(
          appBar: AppBar(
            title: Text(list?.title ?? 'Shopping List'),
            actions: [
              IconButton(
                onPressed: list == null
                    ? null
                    : () => _showComingSoon('Share list'),
                icon: const Icon(Icons.ios_share_outlined),
                tooltip: 'Share list',
              ),
              IconButton(
                onPressed: list == null
                    ? null
                    : () => _showComingSoon('Members'),
                icon: const Icon(Icons.group_outlined),
                tooltip: 'Members',
              ),
              PopupMenuButton<_ListAction>(
                onSelected: (action) {
                  if (action == _ListAction.delete && list != null) {
                    _confirmDeleteList(provider, list);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ListAction.delete,
                    child: Text('Delete list'),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: list == null
                ? _MissingListState(onBack: () => Navigator.pop(context))
                : _ListDetailBody(
                    list: list,
                    items: provider.items,
                    isLoading: provider.isLoading,
                    errorMessage: provider.errorMessage,
                    onClearError: provider.clearError,
                    onAddItem: () => _showItemSheet(provider, list.id),
                    onEditItem: (item) =>
                        _showItemSheet(provider, list.id, item: item),
                    onDeleteItem: (item) =>
                        _confirmDeleteItem(provider, list.id, item),
                    onToggleItem: (item) => provider.toggleItemCompleted(
                      list.id,
                      item.id,
                      item.isCompleted,
                    ),
                  ),
          ),
          floatingActionButton: listId == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _showItemSheet(provider, listId),
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
        );
      },
    );
  }

  ShoppingListModel? _currentList(ShoppingListsProvider provider) {
    final selectedList = provider.selectedList;
    if (selectedList != null) {
      return selectedList;
    }

    final listId = _activeListId;
    if (listId == null) {
      return null;
    }

    for (final list in provider.lists) {
      if (list.id == listId) {
        return list;
      }
    }

    return null;
  }

  Future<void> _showItemSheet(
    ShoppingListsProvider provider,
    String listId, {
    ShoppingItemModel? item,
  }) async {
    final authProvider = context.read<AuthProvider>();
    final createdBy = authProvider.currentUser?.uid ?? item?.createdBy ?? '';

    final savedItem = await showModalBottomSheet<ShoppingItemModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _ItemFormSheet(listId: listId, createdBy: createdBy, item: item);
      },
    );

    if (!mounted || savedItem == null) {
      return;
    }

    if (item == null) {
      await provider.addItem(listId, savedItem);
    } else {
      await provider.updateItem(listId, savedItem);
    }

    if (!mounted) {
      return;
    }

    if (provider.errorMessage != null) {
      _showSnackBar(provider.errorMessage!);
    }
  }

  Future<void> _confirmDeleteItem(
    ShoppingListsProvider provider,
    String listId,
    ShoppingItemModel item,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete item?'),
          content: Text('Remove "${item.name}" from this list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await provider.deleteItem(listId, item.id);

    if (!mounted) {
      return;
    }

    if (provider.errorMessage != null) {
      _showSnackBar(provider.errorMessage!);
    }
  }

  Future<void> _confirmDeleteList(
    ShoppingListsProvider provider,
    ShoppingListModel list,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete list?'),
          content: Text('This will remove "${list.title}" and all its items.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await provider.deleteList(list.id);

    if (!mounted) {
      return;
    }

    if (provider.errorMessage != null) {
      _showSnackBar(provider.errorMessage!);
      return;
    }

    Navigator.pop(context);
  }

  void _showComingSoon(String label) {
    _showSnackBar('$label will be added next.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ListDetailBody extends StatelessWidget {
  const _ListDetailBody({
    required this.list,
    required this.items,
    required this.isLoading,
    required this.errorMessage,
    required this.onClearError,
    required this.onAddItem,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.onToggleItem,
  });

  final ShoppingListModel list;
  final List<ShoppingItemModel> items;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onClearError;
  final VoidCallback onAddItem;
  final ValueChanged<ShoppingItemModel> onEditItem;
  final ValueChanged<ShoppingItemModel> onDeleteItem;
  final ValueChanged<ShoppingItemModel> onToggleItem;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          sliver: SliverToBoxAdapter(child: _ListSummary(list: list)),
        ),
        if (errorMessage != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _ErrorBanner(
                message: errorMessage!,
                onDismissed: onClearError,
              ),
            ),
          ),
        if (isLoading && items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyItemsState(onAddItem: onAddItem),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            sliver: SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return _ShoppingItemTile(
                  item: item,
                  colorScheme: colorScheme,
                  onToggle: () => onToggleItem(item),
                  onEdit: () => onEditItem(item),
                  onDelete: () => onDeleteItem(item),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ListSummary extends StatelessWidget {
  const _ListSummary({required this.list});

  final ShoppingListModel list;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = list.totalItems == 0
        ? 0.0
        : (list.completedItems / list.totalItems).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((list.description ?? '').isNotEmpty) ...[
          Text(
            list.description!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${list.completedItems} of ${list.totalItems} items completed',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text('${(progress * 100).round()}%'),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: colorScheme.surface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShoppingItemTile extends StatelessWidget {
  const _ShoppingItemTile({
    required this.item,
    required this.colorScheme,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final ShoppingItemModel item;
  final ColorScheme colorScheme;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: item.isCompleted, onChanged: (_) => onToggle()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _ItemMetaChip(
                          icon: Icons.scale_outlined,
                          label: _formatQuantity(item.quantity, item.unit),
                        ),
                        if (item.price != null)
                          _ItemMetaChip(
                            icon: Icons.attach_money,
                            label: _formatPrice(item.price!),
                          ),
                        if ((item.category ?? '').isNotEmpty)
                          _ItemMetaChip(
                            icon: Icons.category_outlined,
                            label: item.category!,
                          ),
                      ],
                    ),
                    if ((item.notes ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.notes!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            PopupMenuButton<_ItemAction>(
              onSelected: (action) {
                switch (action) {
                  case _ItemAction.edit:
                    onEdit();
                  case _ItemAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: _ItemAction.edit, child: Text('Edit')),
                PopupMenuItem(value: _ItemAction.delete, child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatQuantity(double quantity, String unit) {
    final formatted = quantity % 1 == 0
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(2);
    return unit.trim().isEmpty ? formatted : '$formatted ${unit.trim()}';
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(2);
  }
}

class _ItemMetaChip extends StatelessWidget {
  const _ItemMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemFormSheet extends StatefulWidget {
  const _ItemFormSheet({
    required this.listId,
    required this.createdBy,
    this.item,
  });

  final String listId;
  final String createdBy;
  final ShoppingItemModel? item;

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitController;
  late final TextEditingController _priceController;
  late final TextEditingController _categoryController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();

    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _quantityController = TextEditingController(
      text: item == null ? '1' : _formatNumber(item.quantity),
    );
    _unitController = TextEditingController(text: item?.unit ?? 'pcs');
    _priceController = TextEditingController(
      text: item?.price == null ? '' : _formatNumber(item!.price!),
    );
    _categoryController = TextEditingController(text: item?.category ?? '');
    _notesController = TextEditingController(text: item?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final colorScheme = Theme.of(context).colorScheme;

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
                      widget.item == null ? 'Add item' : 'Edit item',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Item name',
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
                validator: _requiredValidator('Item name is required.'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
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
                    child: TextFormField(
                      controller: _unitController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        prefixIcon: Icon(Icons.straighten),
                      ),
                      validator: _requiredValidator('Unit is required.'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _priceController,
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
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Optional',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(widget.item == null ? 'Add item' : 'Save changes'),
              ),
              const SizedBox(height: 8),
              Text(
                'Quantity and unit are used to keep list totals readable.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final now = DateTime.now();
    final existingItem = widget.item;
    final item = ShoppingItemModel(
      id: existingItem?.id ?? '',
      listId: widget.listId,
      name: _nameController.text.trim(),
      quantity: double.parse(_quantityController.text.trim()),
      unit: _unitController.text.trim(),
      price: _nullableDouble(_priceController.text),
      category: _emptyToNull(_categoryController.text),
      notes: _emptyToNull(_notesController.text),
      isCompleted: existingItem?.isCompleted ?? false,
      createdBy: existingItem?.createdBy ?? widget.createdBy,
      createdAt: existingItem?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.pop(context, item);
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
    final quantity = double.tryParse(value?.trim() ?? '');
    if (quantity == null || quantity <= 0) {
      return 'Enter a valid quantity.';
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
}

class _EmptyItemsState extends StatelessWidget {
  const _EmptyItemsState({required this.onAddItem});

  final VoidCallback onAddItem;

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
              Icons.add_shopping_cart_outlined,
              size: 64,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No items yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first item to start tracking this shopping list.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAddItem,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingListState extends StatelessWidget {
  const _MissingListState({required this.onBack});

  final VoidCallback onBack;

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
              Icons.list_alt_outlined,
              size: 56,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Shopping list not found',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onBack, child: const Text('Back')),
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

enum _ItemAction { edit, delete }

enum _ListAction { delete }
