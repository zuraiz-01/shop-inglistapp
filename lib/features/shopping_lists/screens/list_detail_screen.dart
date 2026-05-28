import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_routes.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/shopping_item_model.dart';
import '../models/shopping_list_model.dart';
import '../providers/shopping_lists_provider.dart';
import '../widgets/add_edit_item_bottom_sheet.dart';

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
      _selectListAfterBuild(args);
      return;
    }

    if (args is String && args.isNotEmpty) {
      _activeListId = args;
      final matchingList = provider.lists
          .where((list) => list.id == args)
          .cast<ShoppingListModel?>()
          .firstWhere((list) => list != null, orElse: () => null);

      if (matchingList != null) {
        _selectListAfterBuild(matchingList);
      } else {
        _listenToItemsAfterBuild(args);
      }
      return;
    }

    final selectedList = provider.selectedList;
    if (selectedList != null) {
      _activeListId = selectedList.id;
      _listenToItemsAfterBuild(selectedList.id);
    }
  }

  void _selectListAfterBuild(ShoppingListModel list) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final provider = context.read<ShoppingListsProvider>();
      provider.selectList(list);
      provider.listenToItems(list.id);
    });
  }

  void _listenToItemsAfterBuild(String listId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<ShoppingListsProvider>().listenToItems(listId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShoppingListsProvider>(
      builder: (context, provider, _) {
        final currentUserId = context.watch<AuthProvider>().currentUser?.uid;
        final list = _currentList(provider);
        final listId = list?.id ?? _activeListId;
        final canEdit = list != null && canEditItems(list, currentUserId);
        final canManage = list != null && canManageMembers(list, currentUserId);
        final canDelete = list != null && canDeleteList(list, currentUserId);

        return Scaffold(
          appBar: AppBar(
            title: Text(list?.title ?? 'Shopping List'),
            actions: [
              if (canManage)
                IconButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.shareList,
                    arguments: list,
                  ),
                  icon: const Icon(Icons.ios_share_outlined),
                  tooltip: 'Share list',
                ),
              IconButton(
                onPressed: list == null
                    ? null
                    : () => Navigator.pushNamed(
                        context,
                        AppRoutes.members,
                        arguments: list,
                      ),
                icon: const Icon(Icons.group_outlined),
                tooltip: 'Members',
              ),
              if (canDelete)
                PopupMenuButton<_ListAction>(
                  onSelected: (action) {
                    if (action == _ListAction.delete) {
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
                    canEditItems: canEdit,
                    onClearError: provider.clearError,
                    onAddItem: () => _showItemSheet(list.id),
                    onEditItem: (item) => _showItemSheet(list.id, item: item),
                    onDeleteItem: (item) =>
                        _confirmDeleteItem(provider, list.id, item),
                    onToggleItem: (item) => provider.toggleItemCompleted(
                      list.id,
                      item.id,
                      item.isCompleted,
                    ),
                  ),
          ),
          floatingActionButton: listId == null || !canEdit
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _showItemSheet(listId),
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

  Future<void> _showItemSheet(String listId, {ShoppingItemModel? item}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return AddEditItemBottomSheet(listId: listId, item: item);
      },
    );
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
    required this.canEditItems,
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
  final bool canEditItems;
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
            child: _EmptyItemsState(
              canEditItems: canEditItems,
              onAddItem: onAddItem,
            ),
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
                  canEdit: canEditItems,
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
    required this.canEdit,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final ShoppingItemModel item;
  final ColorScheme colorScheme;
  final bool canEdit;
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
            Checkbox(
              value: item.isCompleted,
              onChanged: canEdit ? (_) => onToggle() : null,
            ),
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
            if (canEdit)
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
                  PopupMenuItem(
                    value: _ItemAction.delete,
                    child: Text('Delete'),
                  ),
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

class _EmptyItemsState extends StatelessWidget {
  const _EmptyItemsState({required this.canEditItems, required this.onAddItem});

  final bool canEditItems;
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
              canEditItems
                  ? 'Add your first item to start tracking this shopping list.'
                  : 'No items have been added to this shopping list.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (canEditItems) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAddItem,
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ],
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
