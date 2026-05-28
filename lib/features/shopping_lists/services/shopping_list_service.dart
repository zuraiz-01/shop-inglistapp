import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/list_member_model.dart';
import '../models/shopping_item_model.dart';
import '../models/shopping_list_model.dart';

class ShoppingListService {
  ShoppingListService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _listsCollection {
    return _firestore.collection('shoppingLists');
  }

  CollectionReference<Map<String, dynamic>> get _usersCollection {
    return _firestore.collection('users');
  }

  Future<ShoppingListModel> createShoppingList({
    required String title,
    required String ownerId,
    required String ownerName,
    String? description,
  }) async {
    try {
      final docRef = _listsCollection.doc();
      final now = DateTime.now();

      await docRef.set({
        'title': title.trim(),
        'description': _emptyToNull(description),
        'ownerId': ownerId,
        'ownerName': ownerName,
        'members': [ownerId],
        'memberRoles': {ownerId: 'owner'},
        'totalItems': 0,
        'completedItems': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return ShoppingListModel(
        id: docRef.id,
        title: title.trim(),
        description: _emptyToNull(description),
        ownerId: ownerId,
        ownerName: ownerName,
        members: [ownerId],
        memberRoles: {ownerId: 'owner'},
        totalItems: 0,
        completedItems: 0,
        createdAt: now,
        updatedAt: now,
      );
    } on FirebaseException catch (error) {
      throw ShoppingListServiceException(_firestoreErrorMessage(error));
    } catch (_) {
      throw const ShoppingListServiceException(
        'Could not create the shopping list.',
      );
    }
  }

  Future<List<ShoppingListModel>> getUserLists(String uid) async {
    try {
      final snapshot = await _userListsQuery(uid).get();

      return snapshot.docs.map(ShoppingListModel.fromFirestore).toList();
    } on FirebaseException catch (error) {
      throw ShoppingListServiceException(_firestoreErrorMessage(error));
    } catch (_) {
      throw const ShoppingListServiceException(
        'Could not load shopping lists.',
      );
    }
  }

  Stream<List<ShoppingListModel>> streamUserLists(String uid) async* {
    try {
      yield* _userListsQuery(uid).snapshots().map((snapshot) {
        return snapshot.docs.map(ShoppingListModel.fromFirestore).toList();
      });
    } on FirebaseException catch (error) {
      throw ShoppingListServiceException(_firestoreErrorMessage(error));
    } catch (_) {
      throw const ShoppingListServiceException(
        'Could not stream shopping lists.',
      );
    }
  }

  Future<void> updateShoppingList({
    required String listId,
    String? title,
    String? description,
    List<String>? members,
    Map<String, String>? memberRoles,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (title != null) {
        updates['title'] = title.trim();
      }

      if (description != null) {
        updates['description'] = _emptyToNull(description);
      }

      if (members != null) {
        updates['members'] = members;
      }

      if (memberRoles != null) {
        updates['memberRoles'] = memberRoles;
      }

      await _listsCollection.doc(listId).update(updates);
    } on FirebaseException catch (error) {
      throw ShoppingListServiceException(_firestoreErrorMessage(error));
    } catch (_) {
      throw const ShoppingListServiceException(
        'Could not update the shopping list.',
      );
    }
  }

  Future<void> shareShoppingListByEmail({
    required String listId,
    required String currentUserId,
    required String email,
    required String permission,
  }) async {
    try {
      if (!['viewer', 'editor'].contains(permission)) {
        throw const ShoppingListServiceException(
          'Please select a valid permission.',
        );
      }

      final targetUser = await _findUserByEmail(email);
      if (targetUser == null) {
        throw const ShoppingListServiceException(
          'No user found with this email',
        );
      }

      final targetUid = targetUser['uid'] as String? ?? '';
      if (targetUid.isEmpty) {
        throw const ShoppingListServiceException(
          'No user found with this email',
        );
      }

      if (targetUid == currentUserId) {
        throw const ShoppingListServiceException(
          'You cannot add yourself to your own list.',
        );
      }

      final listRef = _listsCollection.doc(listId);

      await _firestore.runTransaction((transaction) async {
        final listSnapshot = await transaction.get(listRef);
        if (!listSnapshot.exists) {
          throw const ShoppingListServiceException(
            'Shopping list was not found.',
          );
        }

        final list = ShoppingListModel.fromFirestore(listSnapshot);
        if (list.ownerId != currentUserId) {
          throw const ShoppingListServiceException(
            'Only the list owner can share this shopping list.',
          );
        }

        if (list.members.contains(targetUid)) {
          throw const ShoppingListServiceException(
            'This user is already a member of this list.',
          );
        }

        transaction.update(listRef, {
          'members': FieldValue.arrayUnion([targetUid]),
          'memberRoles.$targetUid': permission,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on ShoppingListServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw ShoppingListServiceException(_firestoreErrorMessage(error));
    } catch (_) {
      throw const ShoppingListServiceException(
        'Could not share this shopping list.',
      );
    }
  }

  Future<List<ListMemberModel>> getListMembers(ShoppingListModel list) async {
    try {
      final members = <ListMemberModel>[];

      for (final uid in list.members) {
        final userDoc = await _usersCollection.doc(uid).get();
        final userData = userDoc.data() ?? <String, dynamic>{};
        final role = list.memberRoles[uid] ?? 'viewer';

        members.add(ListMemberModel.fromMap(userData, uid: uid, role: role));
      }

      members.sort((a, b) {
        if (a.isOwner && !b.isOwner) {
          return -1;
        }
        if (!a.isOwner && b.isOwner) {
          return 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return members;
    } on FirebaseException catch (error) {
      throw ShoppingListServiceException(_firestoreErrorMessage(error));
    } catch (_) {
      throw const ShoppingListServiceException('Could not load list members.');
    }
  }

  Future<void> updateMemberRole({
    required String listId,
    required String currentUserId,
    required String memberId,
    required String role,
  }) async {
    try {
      if (!['viewer', 'editor'].contains(role)) {
        throw const ShoppingListServiceException(
          'Please select a valid permission.',
        );
      }

      final listRef = _listsCollection.doc(listId);

      await _firestore.runTransaction((transaction) async {
        final listSnapshot = await transaction.get(listRef);
        if (!listSnapshot.exists) {
          throw const ShoppingListServiceException(
            'Shopping list was not found.',
          );
        }

        final list = ShoppingListModel.fromFirestore(listSnapshot);
        _assertOwnerCanManageMember(
          list: list,
          currentUserId: currentUserId,
          memberId: memberId,
        );

        transaction.update(listRef, {
          'memberRoles.$memberId': role,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on ShoppingListServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw ShoppingListServiceException(_firestoreErrorMessage(error));
    } catch (_) {
      throw const ShoppingListServiceException(
        'Could not update member permission.',
      );
    }
  }

  Future<void> removeMember({
    required String listId,
    required String currentUserId,
    required String memberId,
  }) async {
    try {
      final listRef = _listsCollection.doc(listId);

      await _firestore.runTransaction((transaction) async {
        final listSnapshot = await transaction.get(listRef);
        if (!listSnapshot.exists) {
          throw const ShoppingListServiceException(
            'Shopping list was not found.',
          );
        }

        final list = ShoppingListModel.fromFirestore(listSnapshot);
        _assertOwnerCanManageMember(
          list: list,
          currentUserId: currentUserId,
          memberId: memberId,
        );

        transaction.update(listRef, {
          'members': FieldValue.arrayRemove([memberId]),
          'memberRoles.$memberId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on ShoppingListServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw ShoppingListServiceException(_firestoreErrorMessage(error));
    } catch (_) {
      throw const ShoppingListServiceException('Could not remove this member.');
    }
  }

  Future<void> deleteShoppingList({
    required String listId,
    required String currentUserId,
  }) async {
    try {
      final listRef = _listsCollection.doc(listId);
      final listSnapshot = await listRef.get();

      if (!listSnapshot.exists) {
        throw const ShoppingListServiceException(
          'Shopping list was not found.',
        );
      }

      final list = ShoppingListModel.fromFirestore(listSnapshot);
      if (list.ownerId != currentUserId) {
        throw const ShoppingListServiceException(
          'Only the list owner can delete this shopping list.',
        );
      }

      final itemsSnapshot = await _itemsCollection(listId).get();
      final writes = <DocumentReference<Map<String, dynamic>>>[
        ...itemsSnapshot.docs.map((doc) => doc.reference),
        listRef,
      ];

      await _commitDeleteBatches(writes);
    } on ShoppingListServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw ShoppingListServiceException(_firestoreErrorMessage(error));
    } catch (_) {
      throw const ShoppingListServiceException(
        'Could not delete the shopping list.',
      );
    }
  }

  void _assertOwnerCanManageMember({
    required ShoppingListModel list,
    required String currentUserId,
    required String memberId,
  }) {
    if (list.ownerId != currentUserId) {
      throw const ShoppingListServiceException(
        'Only the list owner can manage members.',
      );
    }

    if (memberId == list.ownerId) {
      throw const ShoppingListServiceException(
        'The owner cannot be removed or changed.',
      );
    }

    if (!list.members.contains(memberId)) {
      throw const ShoppingListServiceException(
        'This user is not a member of this list.',
      );
    }
  }

  Future<ShoppingItemModel> addItemToList({
    required String listId,
    required String name,
    required double quantity,
    required String unit,
    required String createdBy,
    double? price,
    String? category,
    String? notes,
    bool isCompleted = false,
  }) async {
    try {
      final listRef = _listsCollection.doc(listId);
      final itemRef = _itemsCollection(listId).doc();
      final now = DateTime.now();

      await _firestore.runTransaction((transaction) async {
        final listSnapshot = await transaction.get(listRef);
        if (!listSnapshot.exists) {
          throw const ShoppingListServiceException(
            'Shopping list was not found.',
          );
        }

        transaction.set(itemRef, {
          'listId': listId,
          'name': name.trim(),
          'quantity': quantity,
          'unit': unit.trim(),
          'price': price,
          'category': _emptyToNull(category),
          'notes': _emptyToNull(notes),
          'isCompleted': isCompleted,
          'createdBy': createdBy,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(listRef, {
          'totalItems': FieldValue.increment(1),
          'completedItems': FieldValue.increment(isCompleted ? 1 : 0),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return ShoppingItemModel(
        id: itemRef.id,
        listId: listId,
        name: name.trim(),
        quantity: quantity,
        unit: unit.trim(),
        price: price,
        category: _emptyToNull(category),
        notes: _emptyToNull(notes),
        isCompleted: isCompleted,
        createdBy: createdBy,
        createdAt: now,
        updatedAt: now,
      );
    } on ShoppingListServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw ShoppingListServiceException(_firestoreErrorMessage(error));
    } catch (_) {
      throw const ShoppingListServiceException(
        'Could not add the shopping item.',
      );
    }
  }

  Stream<List<ShoppingItemModel>> streamItems(String listId) async* {
    try {
      yield* _itemsCollection(
        listId,
      ).orderBy('createdAt', descending: false).snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => ShoppingItemModel.fromMap(doc.data(), id: doc.id))
            .map((item) => _withListId(item, listId))
            .toList();
      });
    } on FirebaseException catch (error) {
      throw ShoppingListServiceException(_firestoreErrorMessage(error));
    } catch (_) {
      throw const ShoppingListServiceException(
        'Could not stream shopping items.',
      );
    }
  }

  Future<void> updateItem({
    required String listId,
    required String itemId,
    String? name,
    double? quantity,
    String? unit,
    double? price,
    String? category,
    String? notes,
    bool? isCompleted,
  }) async {
    try {
      final listRef = _listsCollection.doc(listId);
      final itemRef = _itemsCollection(listId).doc(itemId);

      await _firestore.runTransaction((transaction) async {
        final itemSnapshot = await transaction.get(itemRef);
        if (!itemSnapshot.exists) {
          throw const ShoppingListServiceException(
            'Shopping item was not found.',
          );
        }

        final currentItem = ShoppingItemModel.fromMap(
          itemSnapshot.data() ?? <String, dynamic>{},
          id: itemSnapshot.id,
        );

        final updates = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (name != null) {
          updates['name'] = name.trim();
        }

        if (quantity != null) {
          updates['quantity'] = quantity;
        }

        if (unit != null) {
          updates['unit'] = unit.trim();
        }

        if (price != null) {
          updates['price'] = price;
        }

        if (category != null) {
          updates['category'] = _emptyToNull(category);
        }

        if (notes != null) {
          updates['notes'] = _emptyToNull(notes);
        }

        var completedDelta = 0;
        if (isCompleted != null) {
          updates['isCompleted'] = isCompleted;

          if (currentItem.isCompleted != isCompleted) {
            completedDelta = isCompleted ? 1 : -1;
          }
        }

        transaction.update(itemRef, updates);
        transaction.update(listRef, {
          if (completedDelta != 0)
            'completedItems': FieldValue.increment(completedDelta),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on ShoppingListServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw ShoppingListServiceException(_firestoreErrorMessage(error));
    } catch (_) {
      throw const ShoppingListServiceException(
        'Could not update the shopping item.',
      );
    }
  }

  Future<void> toggleItemCompleted({
    required String listId,
    required String itemId,
  }) async {
    try {
      final listRef = _listsCollection.doc(listId);
      final itemRef = _itemsCollection(listId).doc(itemId);

      await _firestore.runTransaction((transaction) async {
        final itemSnapshot = await transaction.get(itemRef);
        if (!itemSnapshot.exists) {
          throw const ShoppingListServiceException(
            'Shopping item was not found.',
          );
        }

        final item = ShoppingItemModel.fromMap(
          itemSnapshot.data() ?? <String, dynamic>{},
          id: itemSnapshot.id,
        );
        final nextCompleted = !item.isCompleted;

        transaction.update(itemRef, {
          'isCompleted': nextCompleted,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(listRef, {
          'completedItems': FieldValue.increment(nextCompleted ? 1 : -1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on ShoppingListServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw ShoppingListServiceException(_firestoreErrorMessage(error));
    } catch (_) {
      throw const ShoppingListServiceException(
        'Could not update the item status.',
      );
    }
  }

  Future<void> deleteItem({
    required String listId,
    required String itemId,
  }) async {
    try {
      final listRef = _listsCollection.doc(listId);
      final itemRef = _itemsCollection(listId).doc(itemId);

      await _firestore.runTransaction((transaction) async {
        final itemSnapshot = await transaction.get(itemRef);
        if (!itemSnapshot.exists) {
          throw const ShoppingListServiceException(
            'Shopping item was not found.',
          );
        }

        final item = ShoppingItemModel.fromMap(
          itemSnapshot.data() ?? <String, dynamic>{},
          id: itemSnapshot.id,
        );

        transaction.delete(itemRef);
        transaction.update(listRef, {
          'totalItems': FieldValue.increment(-1),
          if (item.isCompleted) 'completedItems': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on ShoppingListServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw ShoppingListServiceException(_firestoreErrorMessage(error));
    } catch (_) {
      throw const ShoppingListServiceException(
        'Could not delete the shopping item.',
      );
    }
  }

  Query<Map<String, dynamic>> _userListsQuery(String uid) {
    return _listsCollection
        .where('members', arrayContains: uid)
        .orderBy('updatedAt', descending: true);
  }

  CollectionReference<Map<String, dynamic>> _itemsCollection(String listId) {
    return _listsCollection.doc(listId).collection('items');
  }

  Future<Map<String, dynamic>?> _findUserByEmail(String email) async {
    final trimmedEmail = email.trim();
    final normalizedEmail = trimmedEmail.toLowerCase();

    var snapshot = await _usersCollection
        .where('emailLower', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      snapshot = await _usersCollection
          .where('email', isEqualTo: trimmedEmail)
          .limit(1)
          .get();
    }

    if (snapshot.docs.isEmpty && trimmedEmail != normalizedEmail) {
      snapshot = await _usersCollection
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
    }

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final doc = snapshot.docs.first;
    return {...doc.data(), 'uid': doc.data()['uid'] as String? ?? doc.id};
  }

  Future<void> _commitDeleteBatches(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    const batchLimit = 450;

    for (var start = 0; start < refs.length; start += batchLimit) {
      final batch = _firestore.batch();
      final end = (start + batchLimit).clamp(0, refs.length);

      for (final ref in refs.sublist(start, end)) {
        batch.delete(ref);
      }

      await batch.commit();
    }
  }

  ShoppingItemModel _withListId(ShoppingItemModel item, String listId) {
    return ShoppingItemModel(
      id: item.id,
      listId: listId,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      price: item.price,
      category: item.category,
      notes: item.notes,
      isCompleted: item.isCompleted,
      createdBy: item.createdBy,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  String _firestoreErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to access this shopping list.';
      case 'not-found':
        return 'The requested shopping list was not found.';
      case 'unavailable':
        return 'Cloud Firestore is unavailable. Check your internet connection and make sure Firestore Database is enabled in Firebase Console.';
      case 'failed-precondition':
        return 'Cloud Firestore is not ready for this request. Check your Firebase Console Firestore setup.';
      case 'cancelled':
        return 'The request was cancelled. Please try again.';
      default:
        return error.message ?? 'Shopping list request failed.';
    }
  }
}

class ShoppingListServiceException implements Exception {
  const ShoppingListServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
