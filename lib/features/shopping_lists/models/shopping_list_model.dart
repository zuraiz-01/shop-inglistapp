import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingListModel {
  const ShoppingListModel({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.ownerName,
    required this.members,
    required this.memberRoles,
    required this.totalItems,
    required this.completedItems,
    required this.createdAt,
    required this.updatedAt,
    this.description,
  });

  final String id;
  final String title;
  final String? description;
  final String ownerId;
  final String ownerName;
  final List<String> members;
  final Map<String, String> memberRoles;
  final int totalItems;
  final int completedItems;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ShoppingListModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return ShoppingListModel.fromMap(data, id: doc.id);
  }

  factory ShoppingListModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return ShoppingListModel(
      id: id ?? map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      ownerId: map['ownerId'] as String? ?? '',
      ownerName: map['ownerName'] as String? ?? '',
      members: _stringListFromValue(map['members']),
      memberRoles: _stringMapFromValue(map['memberRoles']),
      totalItems: _intFromValue(map['totalItems']),
      completedItems: _intFromValue(map['completedItems']),
      createdAt: _dateTimeFromValue(map['createdAt']),
      updatedAt: _dateTimeFromValue(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'members': members,
      'memberRoles': memberRoles,
      'totalItems': totalItems,
      'completedItems': completedItems,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static List<String> _stringListFromValue(Object? value) {
    if (value is Iterable) {
      return value.whereType<String>().toList();
    }

    return const [];
  }

  static Map<String, String> _stringMapFromValue(Object? value) {
    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }

    return const {};
  }

  static int _intFromValue(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  static DateTime _dateTimeFromValue(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
