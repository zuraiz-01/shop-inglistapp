import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../auth/models/user_model.dart';
import '../models/list_member_model.dart';
import '../models/shopping_item_model.dart';
import '../models/shopping_list_model.dart';
import '../services/shopping_list_service.dart';

class ShoppingListsProvider extends ChangeNotifier {
  ShoppingListsProvider({ShoppingListService? shoppingListService})
    : _shoppingListService = shoppingListService ?? ShoppingListService();

  final ShoppingListService _shoppingListService;

  StreamSubscription<List<ShoppingListModel>>? _listsSubscription;
  StreamSubscription<List<ShoppingItemModel>>? _itemsSubscription;

  UserModel? _currentUser;
  List<ShoppingListModel> _lists = const [];
  ShoppingListModel? _selectedList;
  List<ShoppingItemModel> _items = const [];
  List<ListMemberModel> _members = const [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDisposed = false;

  List<ShoppingListModel> get lists => List.unmodifiable(_lists);
  ShoppingListModel? get selectedList => _selectedList;
  List<ShoppingItemModel> get items => List.unmodifiable(_items);
  List<ListMemberModel> get members => List.unmodifiable(_members);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void updateCurrentUser(UserModel? user) {
    if (_currentUser?.uid == user?.uid) {
      _currentUser = user;
      return;
    }

    _currentUser = user;

    if (user == null) {
      _listsSubscription?.cancel();
      _itemsSubscription?.cancel();
      _lists = const [];
      _selectedList = null;
      _items = const [];
      _members = const [];
      _safeNotifyListeners();
    }
  }

  Future<void> createList(String title, String? description) async {
    await _runAction(() async {
      final user = _requireCurrentUser();

      final list = await _shoppingListService.createShoppingList(
        title: title,
        description: description,
        ownerId: user.uid,
        ownerName: user.name,
      );

      if (!_lists.any((existing) => existing.id == list.id)) {
        _lists = [list, ..._lists];
      }
    });
  }

  Future<void> loadUserLists(String uid) async {
    await _runAction(() async {
      _lists = await _shoppingListService.getUserLists(uid);
      _syncSelectedList();
    });
  }

  void listenToUserLists(String uid) {
    _listsSubscription?.cancel();
    _setLoading(true);
    _errorMessage = null;

    _listsSubscription = _shoppingListService
        .streamUserLists(uid)
        .listen(
          (lists) {
            _lists = lists;
            _syncSelectedList();
            _finishStreamUpdate();
          },
          onError: (Object error) {
            _errorMessage = _messageFromError(error);
            _finishStreamUpdate();
          },
        );
  }

  void selectList(ShoppingListModel? list) {
    _selectedList = list;

    if (list == null) {
      _itemsSubscription?.cancel();
      _items = const [];
    }

    _safeNotifyListeners();
  }

  void listenToItems(String listId) {
    _itemsSubscription?.cancel();
    _setLoading(true);
    _errorMessage = null;

    _itemsSubscription = _shoppingListService
        .streamItems(listId)
        .listen(
          (items) {
            _items = items;
            _finishStreamUpdate();
          },
          onError: (Object error) {
            _errorMessage = _messageFromError(error);
            _finishStreamUpdate();
          },
        );
  }

  Future<void> addItem(String listId, ShoppingItemModel item) async {
    await _runAction(() async {
      final user = _requireCurrentUser();
      final createdBy = item.createdBy.isNotEmpty ? item.createdBy : user.uid;

      final newItem = await _shoppingListService.addItemToList(
        listId: listId,
        currentUserId: user.uid,
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        createdBy: createdBy,
        price: item.price,
        category: item.category,
        notes: item.notes,
        isCompleted: item.isCompleted,
      );

      if (!_items.any((existing) => existing.id == newItem.id)) {
        _items = [..._items, newItem];
      }
    });
  }

  Future<void> updateItem(String listId, ShoppingItemModel item) async {
    await _runAction(() async {
      final user = _requireCurrentUser();

      await _shoppingListService.updateItem(
        listId: listId,
        currentUserId: user.uid,
        itemId: item.id,
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        price: item.price,
        category: item.category,
        notes: item.notes,
        isCompleted: item.isCompleted,
      );

      _items = _items
          .map((existing) => existing.id == item.id ? item : existing)
          .toList();
    });
  }

  Future<void> toggleItemCompleted(
    String listId,
    String itemId,
    bool currentValue,
  ) async {
    await _runAction(() async {
      final user = _requireCurrentUser();
      final nextValue = !currentValue;

      await _shoppingListService.updateItem(
        listId: listId,
        currentUserId: user.uid,
        itemId: itemId,
        isCompleted: nextValue,
      );

      _items = _items.map((item) {
        if (item.id != itemId) {
          return item;
        }

        return ShoppingItemModel(
          id: item.id,
          listId: item.listId,
          name: item.name,
          quantity: item.quantity,
          unit: item.unit,
          price: item.price,
          category: item.category,
          notes: item.notes,
          isCompleted: nextValue,
          createdBy: item.createdBy,
          createdAt: item.createdAt,
          updatedAt: DateTime.now(),
        );
      }).toList();
    });
  }

  Future<void> deleteItem(String listId, String itemId) async {
    await _runAction(() async {
      final user = _requireCurrentUser();

      await _shoppingListService.deleteItem(
        listId: listId,
        currentUserId: user.uid,
        itemId: itemId,
      );
      _items = _items.where((item) => item.id != itemId).toList();
    });
  }

  Future<void> deleteList(String listId) async {
    await _runAction(() async {
      final user = _requireCurrentUser();

      await _shoppingListService.deleteShoppingList(
        listId: listId,
        currentUserId: user.uid,
      );

      _lists = _lists.where((list) => list.id != listId).toList();

      if (_selectedList?.id == listId) {
        _selectedList = null;
        _items = const [];
        await _itemsSubscription?.cancel();
      }
    });
  }

  Future<void> loadMembers(ShoppingListModel list) async {
    await _runAction(() async {
      _members = await _shoppingListService.getListMembers(list);
    });
  }

  Future<void> changeMemberPermission({
    required String listId,
    required String memberId,
    required String role,
  }) async {
    await _runAction(() async {
      final user = _requireCurrentUser();

      await _shoppingListService.updateMemberRole(
        listId: listId,
        currentUserId: user.uid,
        memberId: memberId,
        role: role,
      );

      _members = _members.map((member) {
        if (member.uid != memberId) {
          return member;
        }

        return ListMemberModel(
          uid: member.uid,
          name: member.name,
          email: member.email,
          photoUrl: member.photoUrl,
          role: role,
        );
      }).toList();
    });
  }

  Future<void> removeMember({
    required String listId,
    required String memberId,
  }) async {
    await _runAction(() async {
      final user = _requireCurrentUser();

      await _shoppingListService.removeMember(
        listId: listId,
        currentUserId: user.uid,
        memberId: memberId,
      );

      _members = _members.where((member) => member.uid != memberId).toList();
    });
  }

  Future<void> shareListByEmail({
    required String listId,
    required String email,
    required String permission,
  }) async {
    await _runAction(() async {
      final user = _requireCurrentUser();

      await _shoppingListService.shareShoppingListByEmail(
        listId: listId,
        currentUserId: user.uid,
        email: email,
        permission: permission,
      );
    });
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    _safeNotifyListeners();
  }

  Future<void> _runAction(Future<void> Function() action) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await action();
    } on ShoppingListServiceException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = _messageFromError(error);
    } finally {
      _setLoading(false);
    }
  }

  UserModel _requireCurrentUser() {
    final user = _currentUser;
    if (user == null) {
      throw const ShoppingListServiceException(
        'You must be signed in to manage shopping lists.',
      );
    }

    return user;
  }

  void _syncSelectedList() {
    final selected = _selectedList;
    if (selected == null) {
      return;
    }

    final index = _lists.indexWhere((list) => list.id == selected.id);
    if (index == -1) {
      _selectedList = null;
      _items = const [];
      _itemsSubscription?.cancel();
      return;
    }

    _selectedList = _lists[index];
  }

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;
    _safeNotifyListeners();
  }

  void _finishStreamUpdate() {
    if (_isLoading) {
      _setLoading(false);
      return;
    }

    _safeNotifyListeners();
  }

  String _messageFromError(Object error) {
    if (error is ShoppingListServiceException) {
      return error.message;
    }

    return 'Something went wrong. Please try again.';
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _listsSubscription?.cancel();
    _itemsSubscription?.cancel();
    super.dispose();
  }
}
