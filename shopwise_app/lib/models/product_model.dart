import 'package:cloud_firestore/cloud_firestore.dart';

/// Product data. Numeric database/Firestore fields are represented as doubles
/// because DECIMAL/Firestore-number values can be fractional. All numeric
/// parsing goes through the safe [_toDouble] helper so that `num`, `String`,
/// `int` and `null` values never throw.
class ProductModel {

  const ProductModel({
    required this.id,
    required this.shopId, required this.name, required this.unit, required this.sellingPrice, required this.defaultPurchasePrice, required this.minimumStock, required this.createdAt, required this.updatedAt, this.docId,
    this.categoryId,
    this.sku,
    this.barcode,
    this.author,
    this.isbn,
    this.targetStockDays = 7,
    this.isActive = true,
    this.totalStock = 0,
    this.batchCount,
    this.category,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    int intValue(dynamic value, [int fallback = 0]) =>
        value == null ? fallback : (value as num).toInt();

    return ProductModel(
      id: (json['id'] as num).toInt(),
      shopId: (json['shop_id'] as num).toInt(),
      categoryId: (json['category_id'] as num?)?.toInt(),
      name: json['name'] as String,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      author: json['author'] as String?,
      isbn: json['isbn'] as String?,
      unit: json['unit'] as String,
      sellingPrice: _toDouble(json['selling_price']),
      defaultPurchasePrice: _toDouble(json['default_purchase_price']),
      minimumStock: _toDouble(json['minimum_stock'] ?? json['reorder_level']),
      targetStockDays: intValue(json['target_stock_days'], 7),
      isActive: json['is_active'] == null || json['is_active'] == true || json['is_active'] == 1,
      totalStock: _toDouble(json['total_stock'] ?? json['current_stock']),
      batchCount: (json['batch_count'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      category: json['category'] != null
          ? CategoryInfo.fromJson(json['category'] as Map<String, dynamic>)
          : (json['category_name'] == null
              ? null
              : CategoryInfo(
                  id: (json['category_id'] as num).toInt(),
                  name: json['category_name'] as String,
                )),
    );
  }

  /// Builds a [ProductModel] from a Firestore document. The shop id is supplied
  /// by the caller (it is implied by the collection path `shops/{shopId}/...`
  /// and not stored on each product) and mapped to the legacy `int` id via the
  /// deterministic [_stableId] hash, matching the mapping used elsewhere.
  factory ProductModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String shopId,
  }) {
    final data = doc.data() ?? <String, dynamic>{};
    return ProductModel(
      id: _stableId(doc.id),
      docId: doc.id,
      shopId: _stableId(shopId),
      categoryId: data['category_id'] == null
          ? null
          : (data['category_id'] is num
              ? (data['category_id'] as num).toInt()
              : _stableId(data['category_id'].toString())),
      name: (data['name'] as String?) ?? '',
      sku: data['sku'] as String?,
      barcode: data['barcode'] as String?,
      author: data['author'] as String?,
      isbn: data['isbn'] as String?,
      unit: (data['unit'] as String?) ?? 'piece',
      sellingPrice: _toDouble(data['selling_price']),
      defaultPurchasePrice: _toDouble(data['default_purchase_price']),
      minimumStock: _toDouble(data['minimum_stock']),
      targetStockDays: (data['target_stock_days'] as num?)?.toInt() ?? 7,
      isActive: data['is_active'] == null || data['is_active'] == true,
      totalStock: _toDouble(data['total_stock']),
      batchCount: (data['batch_count'] as num?)?.toInt(),
      createdAt: _toDateTime(data['created_at']),
      updatedAt: _toDateTime(data['updated_at']),
      category: data['category_name'] == null
          ? null
          : CategoryInfo(id: 0, name: data['category_name'] as String),
    );
  }
  final int id;
  /// The Firestore document id of this product. Populated by
  /// [ProductModel.fromFirestore]; `null` for legacy API-parsed products.
  final String? docId;
  final int shopId;
  final int? categoryId;
  final String name;
  final String? sku;
  final String? barcode;
  final String? author;
  final String? isbn;
  final String unit;
  final double sellingPrice;
  final double defaultPurchasePrice;
  final double minimumStock;
  final int targetStockDays;
  final bool isActive;
  final double totalStock;
  final int? batchCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CategoryInfo? category;

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0;
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  /// Deterministic FNV-1a hash so the same Firestore id maps to a stable int.
  static int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final byte in value.codeUnits) {
      hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'shop_id': shopId,
        'category_id': categoryId,
        'name': name,
        'sku': sku,
        'barcode': barcode,
        'author': author,
        'isbn': isbn,
        'unit': unit,
        'selling_price': sellingPrice,
        'default_purchase_price': defaultPurchasePrice,
        'minimum_stock': minimumStock,
        'target_stock_days': targetStockDays,
        'is_active': isActive,
        'total_stock': totalStock,
        'batch_count': batchCount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'category': category?.toJson(),
      };

  ProductModel copyWith({
    int? id,
    String? docId,
    int? shopId,
    int? categoryId,
    String? name,
    String? sku,
    String? barcode,
    String? author,
    String? isbn,
    String? unit,
    double? sellingPrice,
    double? defaultPurchasePrice,
    double? minimumStock,
    int? targetStockDays,
    bool? isActive,
    double? totalStock,
    int? batchCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    CategoryInfo? category,
  }) =>
      ProductModel(
        id: id ?? this.id,
        docId: docId ?? this.docId,
        shopId: shopId ?? this.shopId,
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        sku: sku ?? this.sku,
        barcode: barcode ?? this.barcode,
        author: author ?? this.author,
        isbn: isbn ?? this.isbn,
        unit: unit ?? this.unit,
        sellingPrice: sellingPrice ?? this.sellingPrice,
        defaultPurchasePrice: defaultPurchasePrice ?? this.defaultPurchasePrice,
        minimumStock: minimumStock ?? this.minimumStock,
        targetStockDays: targetStockDays ?? this.targetStockDays,
        isActive: isActive ?? this.isActive,
        totalStock: totalStock ?? this.totalStock,
        batchCount: batchCount ?? this.batchCount,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        category: category ?? this.category,
      );

  String get formattedTotalStock => _formatQuantity(totalStock);
  String get formattedMinimumStock => _formatQuantity(minimumStock);
  bool get isLowStock => totalStock <= minimumStock;
  bool get isOutOfStock => totalStock <= 0;

  static String _formatQuantity(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);
}

class CategoryInfo {

  const CategoryInfo({required this.id, required this.name});

  factory CategoryInfo.fromJson(Map<String, dynamic> json) => CategoryInfo(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
      );
  final int id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
