/// Product data returned by the API. Numeric database fields are represented
/// as doubles because MySQL DECIMAL values can be fractional.
class ProductModel {
  final int id;
  final int shopId;
  final int? categoryId;
  final String name;
  final String? sku;
  final String? barcode;
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

  const ProductModel({
    required this.id,
    required this.shopId,
    this.categoryId,
    required this.name,
    this.sku,
    this.barcode,
    required this.unit,
    required this.sellingPrice,
    required this.defaultPurchasePrice,
    required this.minimumStock,
    this.targetStockDays = 7,
    this.isActive = true,
    this.totalStock = 0,
    this.batchCount,
    required this.createdAt,
    required this.updatedAt,
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

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'shop_id': shopId,
        'category_id': categoryId,
        'name': name,
        'sku': sku,
        'barcode': barcode,
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
    int? shopId,
    int? categoryId,
    String? name,
    String? sku,
    String? barcode,
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
        shopId: shopId ?? this.shopId,
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        sku: sku ?? this.sku,
        barcode: barcode ?? this.barcode,
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
  final int id;
  final String name;

  const CategoryInfo({required this.id, required this.name});

  factory CategoryInfo.fromJson(Map<String, dynamic> json) => CategoryInfo(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
