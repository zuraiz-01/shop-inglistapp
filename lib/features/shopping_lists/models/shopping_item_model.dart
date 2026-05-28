import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingItemModel {
  const ShoppingItemModel({
    required this.id,
    required this.listId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.isCompleted,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.price,
    this.category,
    this.notes,
  });

  final String id;
  final String listId;
  final String name;
  final double quantity;
  final String unit;
  final double? price;
  final String? category;
  final String? notes;
  final bool isCompleted;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ShoppingItemModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return ShoppingItemModel.fromMap(data, id: doc.id);
  }

  factory ShoppingItemModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return ShoppingItemModel(
      id: id ?? map['id'] as String? ?? '',
      listId: map['listId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      quantity: _doubleFromValue(map['quantity'], fallback: 1),
      unit: map['unit'] as String? ?? '',
      price: _nullableDoubleFromValue(map['price']),
      category: map['category'] as String?,
      notes: map['notes'] as String?,
      isCompleted: map['isCompleted'] as bool? ?? false,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: _dateTimeFromValue(map['createdAt']),
      updatedAt: _dateTimeFromValue(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'listId': listId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'category': category,
      'notes': notes,
      'isCompleted': isCompleted,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static double _doubleFromValue(Object? value, {double fallback = 0}) {
    return _nullableDoubleFromValue(value) ?? fallback;
  }

  static double? _nullableDoubleFromValue(Object? value) {
    if (value is int) {
      return value.toDouble();
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return null;
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
