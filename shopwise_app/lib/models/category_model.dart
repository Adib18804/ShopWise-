import 'package:cloud_firestore/cloud_firestore.dart';

/// Category model
class CategoryModel {

  CategoryModel({
    required this.id,
    required this.shopId, required this.name, required this.createdAt, required this.updatedAt, this.docId,
    this.description,
    this.productCount,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
      id: json['id'] as int,
      shopId: json['shop_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      productCount: json['product_count'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

  /// Builds a [CategoryModel] from a Firestore document. The legacy `int` id is
  /// a stable hash of the document id so existing int-based UI (dropdowns,
  /// filters) keeps working.
  factory CategoryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String shopId,
  }) {
    final data = doc.data() ?? <String, dynamic>{};
    return CategoryModel(
      id: _stableId(doc.id),
      docId: doc.id,
      shopId: _stableId(shopId),
      name: (data['name'] as String?) ?? '',
      description: data['description'] as String?,
      productCount: (data['product_count'] as num?)?.toInt(),
      createdAt: _toDateTime(data['created_at']),
      updatedAt: _toDateTime(data['updated_at']),
    );
  }
  final int id;
  /// Firestore document id; `null` for legacy API-parsed categories.
  final String? docId;
  final int shopId;
  final String name;
  final String? description;
  final int? productCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
      'id': id,
      'shop_id': shopId,
      'name': name,
      'description': description,
      'product_count': productCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };

  CategoryModel copyWith({
    int? id,
    String? docId,
    int? shopId,
    String? name,
    String? description,
    int? productCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CategoryModel(
      id: id ?? this.id,
      docId: docId ?? this.docId,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      description: description ?? this.description,
      productCount: productCount ?? this.productCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final byte in value.codeUnits) {
      hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
