import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/list_member_model.dart';
import '../models/shopping_list_model.dart';
import '../providers/shopping_lists_provider.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  bool _didLoad = false;
  ShoppingListModel? _list;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didLoad) {
      return;
    }

    _didLoad = true;
    final provider = context.read<ShoppingListsProvider>();
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is ShoppingListModel) {
      _list = args;
    } else if (args is String && args.isNotEmpty) {
      for (final list in provider.lists) {
        if (list.id == args) {
          _list = list;
          break;
        }
      }
    } else {
      _list = provider.selectedList;
    }

    final list = _list;
    if (list != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ShoppingListsProvider>().loadMembers(list);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final list = _list;
    final canManage = list != null && canManageMembers(list, currentUser?.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: SafeArea(
        child: Consumer<ShoppingListsProvider>(
          builder: (context, provider, _) {
            if (list == null) {
              return const _MessageState(
                icon: Icons.group_outlined,
                title: 'No list selected',
                message: 'Go back and choose a shopping list.',
              );
            }

            if (provider.isLoading && provider.members.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.errorMessage != null && provider.members.isEmpty) {
              return _MessageState(
                icon: Icons.error_outline,
                title: 'Could not load members',
                message: provider.errorMessage!,
              );
            }

            if (provider.members.isEmpty) {
              return const _MessageState(
                icon: Icons.group_outlined,
                title: 'No members yet',
                message: 'Shared members will appear here.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemBuilder: (context, index) {
                final member = provider.members[index];
                return _MemberCard(
                  member: member,
                  canManage: canManage && !member.isOwner,
                  isBusy: provider.isLoading,
                  onRoleChanged: (role) => _changeRole(
                    provider: provider,
                    listId: list.id,
                    member: member,
                    role: role,
                  ),
                  onRemove: () => _confirmRemove(
                    provider: provider,
                    listId: list.id,
                    member: member,
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemCount: provider.members.length,
            );
          },
        ),
      ),
    );
  }

  Future<void> _changeRole({
    required ShoppingListsProvider provider,
    required String listId,
    required ListMemberModel member,
    required String role,
  }) async {
    await provider.changeMemberPermission(
      listId: listId,
      memberId: member.uid,
      role: role,
    );

    if (!mounted) {
      return;
    }

    if (provider.errorMessage != null) {
      _showSnackBar(provider.errorMessage!);
    }
  }

  Future<void> _confirmRemove({
    required ShoppingListsProvider provider,
    required String listId,
    required ListMemberModel member,
  }) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove member?'),
          content: Text('Remove ${member.name} from this shopping list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true) {
      return;
    }

    await provider.removeMember(listId: listId, memberId: member.uid);

    if (!mounted) {
      return;
    }

    if (provider.errorMessage != null) {
      _showSnackBar(provider.errorMessage!);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.canManage,
    required this.isBusy,
    required this.onRoleChanged,
    required this.onRemove,
  });

  final ListMemberModel member;
  final bool canManage;
  final bool isBusy;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = member.name.isNotEmpty
        ? member.name.characters.first.toUpperCase()
        : '?';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: Text(initial),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.email.isEmpty ? member.uid : member.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (member.isOwner)
                    const _RoleBadge(label: 'Owner')
                  else if (canManage)
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'viewer', label: Text('Viewer')),
                        ButtonSegment(value: 'editor', label: Text('Editor')),
                      ],
                      selected: {member.role},
                      onSelectionChanged: isBusy
                          ? null
                          : (selection) => onRoleChanged(selection.first),
                    )
                  else
                    _RoleBadge(label: _formatRole(member.role)),
                ],
              ),
            ),
            if (canManage)
              IconButton(
                onPressed: isBusy ? null : onRemove,
                icon: const Icon(Icons.person_remove_outlined),
                tooltip: 'Remove member',
              ),
          ],
        ),
      ),
    );
  }

  String _formatRole(String role) {
    return role == 'editor' ? 'Editor' : 'Viewer';
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
