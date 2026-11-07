/// User model
class UserModel {

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.preferredLanguage,
    required this.hasShop,
    required this.createdAt, required this.updatedAt, this.shopId,
    this.shopType,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String,
      preferredLanguage: json['preferred_language'] as String,
      hasShop: json['has_shop'] as bool? ?? false,
      shopId: json['shop_id'] as int?,
      shopType: json['shop_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  final int id;
  final String name;
  final String phone;
  final String email;
  final String preferredLanguage;
  final bool hasShop;
  final int? shopId;
  /// Null until the owner completes shop setup and chooses a business type.
  final String? shopType;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'preferred_language': preferredLanguage,
      'has_shop': hasShop,
      'shop_id': shopId,
      if (shopType != null) 'shop_type': shopType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };

  UserModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? preferredLanguage,
    bool? hasShop,
    int? shopId,
    String? shopType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      hasShop: hasShop ?? this.hasShop,
      shopId: shopId ?? this.shopId,
      shopType: shopType ?? this.shopType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
}
