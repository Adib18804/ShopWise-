/// Supported retail business types. Unknown or missing Firestore values fall
/// back to [ShopType.general] so shops created before this field existed keep
/// working without a migration.
enum ShopType {
  general,
  pharmacy,
  stationery,
  library;

  static ShopType fromValue(Object? value) => switch (value) {
        'pharmacy' => ShopType.pharmacy,
        'stationery' => ShopType.stationery,
        'library' => ShopType.library,
        _ => ShopType.general,
      };

  String get value => name;
}

/// Shop model
class ShopModel {

  ShopModel({
    required this.id,
    required this.ownerId,
    required this.shopName,
    required this.address,
    required this.phone,
    required this.currency,
    required this.createdAt, required this.updatedAt, this.shopType = ShopType.general,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) => ShopModel(
      id: json['id'] as int,
      ownerId: json['owner_id'] as int,
      shopName: json['shop_name'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String,
      currency: json['currency'] as String,
      shopType: ShopType.fromValue(json['shop_type']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  final int id;
  final int ownerId;
  final String shopName;
  final String address;
  final String phone;
  final String currency;
  final ShopType shopType;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
      'id': id,
      'owner_id': ownerId,
      'shop_name': shopName,
      'address': address,
      'phone': phone,
      'currency': currency,
      'shop_type': shopType.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };

  ShopModel copyWith({
    int? id,
    int? ownerId,
    String? shopName,
    String? address,
    String? phone,
    String? currency,
    ShopType? shopType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ShopModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      shopName: shopName ?? this.shopName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      currency: currency ?? this.currency,
      shopType: shopType ?? this.shopType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
}
