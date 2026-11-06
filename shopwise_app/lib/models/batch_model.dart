import 'package:cloud_firestore/cloud_firestore.dart';

class BatchModel {
  final int id;
  /// The Firestore document id of this batch. Populated by
  /// [BatchModel.fromFirestore]; `null` for legacy API-parsed batches.
  final String? docId;
  final int productId;
  final String? batchNumber;
  final DateTime purchaseDate;
  final DateTime? expiryDate;
  final double quantity;
  final double purchasePrice;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? productName;
  final String? unit;
  final int? shopId;
  final String? status;
  final int? daysUntilExpiry;
  final bool isActive;

  const BatchModel({
    required this.id,
    this.docId,
    required this.productId,
    this.batchNumber,
    required this.purchaseDate,
    this.expiryDate,
    required this.quantity,
    required this.purchasePrice,
    required this.createdAt,
    required this.updatedAt,
    this.productName,
    this.unit,
    this.shopId,
    this.status,
    this.daysUntilExpiry,
    this.isActive = true,
  });

  factory BatchModel.fromJson(Map<String, dynamic> json) => BatchModel(
        id: (json['id'] as num).toInt(),
        productId: (json['product_id'] as num).toInt(),
        batchNumber: json['batch_number'] as String?,
        purchaseDate: _parseDateOnly(json['purchase_date'] as String),
        expiryDate: json['expiry_date'] == null
            ? null
            : _parseDateOnly(json['expiry_date'] as String),
        quantity: _toDouble(json['quantity']),
        purchasePrice: _toDouble(json['purchase_price']),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        productName: json['product_name'] as String?,
        unit: json['unit'] as String?,
        shopId: (json['shop_id'] as num?)?.toInt(),
        status: json['status'] as String?,
        daysUntilExpiry: (json['days_until_expiry'] as num?)?.toInt(),
        isActive: json['is_active'] == null ||
            json['is_active'] == true || json['is_active'] == 1,
      );

  /// Builds a [BatchModel] from a Firestore document. Dates are stored as
  /// Firestore [Timestamp]s but represented as date-only [DateTime]s to match
  /// the legacy model. [productId]/[shopId] are mapped to the legacy `int` ids
  /// via the deterministic [_stableId] hash.
  factory BatchModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String shopId,
  }) {
    final data = doc.data() ?? <String, dynamic>{};
    return BatchModel(
      id: _stableId(doc.id),
      docId: doc.id,
      productId: data['product_id'] == null
          ? 0
          : _stableId(data['product_id'].toString()),
      batchNumber: data['batch_number'] as String?,
      purchaseDate: _parseDate(data['purchase_date']) ?? DateTime.now(),
      expiryDate: _parseDate(data['expiry_date']),
      quantity: _toDouble(data['quantity']),
      purchasePrice: _toDouble(data['purchase_price']),
      createdAt: _toDateTime(data['created_at']),
      updatedAt: _toDateTime(data['updated_at']),
      shopId: _stableId(shopId),
      isActive: data['is_active'] == null || data['is_active'] == true,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Firestore-aware date-only parser. Accepts [Timestamp], [DateTime], or a
  /// `YYYY-MM-DD` / ISO string, and returns a date-only [DateTime] (no time).
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    DateTime d;
    if (value is Timestamp) {
      d = value.toDate();
    } else if (value is DateTime) {
      d = value;
    } else if (value is String) {
      final parsed = DateTime.tryParse(value.length >= 10 ? value.substring(0, 10) : value);
      if (parsed == null) return null;
      d = parsed;
    } else {
      return null;
    }
    return DateTime(d.year, d.month, d.day);
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  /// Deterministic FNV-1a hash so the same Firestore id maps to a stable int,
  /// matching the mapping used in `product_model.dart` and `auth_provider.dart`.
  static int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final byte in value.codeUnits) {
      hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'batch_number': batchNumber,
        'purchase_date': _formatDate(purchaseDate),
        'expiry_date': expiryDate == null ? null : _formatDate(expiryDate!),
        'quantity': quantity,
        'purchase_price': purchasePrice,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        if (productName != null) 'product_name': productName,
        if (unit != null) 'unit': unit,
        if (shopId != null) 'shop_id': shopId,
        if (status != null) 'status': status,
        if (daysUntilExpiry != null) 'days_until_expiry': daysUntilExpiry,
        'is_active': isActive,
      };

  BatchModel copyWith({
    int? id,
    String? docId,
    int? productId,
    String? batchNumber,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    double? quantity,
    double? purchasePrice,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? productName,
    String? unit,
    int? shopId,
    String? status,
    int? daysUntilExpiry,
    bool? isActive,
  }) =>
      BatchModel(
        id: id ?? this.id,
        docId: docId ?? this.docId,
        productId: productId ?? this.productId,
        batchNumber: batchNumber ?? this.batchNumber,
        purchaseDate: purchaseDate ?? this.purchaseDate,
        expiryDate: expiryDate ?? this.expiryDate,
        quantity: quantity ?? this.quantity,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        productName: productName ?? this.productName,
        unit: unit ?? this.unit,
        shopId: shopId ?? this.shopId,
        status: status ?? this.status,
        daysUntilExpiry: daysUntilExpiry ?? this.daysUntilExpiry,
        isActive: isActive ?? this.isActive,
      );

  int? get calculatedDaysUntilExpiry {
    if (expiryDate == null) return null;
    final today = DateTime.now();
    final expiry = expiryDate!;
    return DateTime.utc(expiry.year, expiry.month, expiry.day)
        .difference(DateTime.utc(today.year, today.month, today.day))
        .inDays;
  }

  bool get isExpired => status == 'EXPIRED' ||
      ((daysUntilExpiry ?? calculatedDaysUntilExpiry ?? 0) < 0);

  bool get isExpiringSoon {
    if (status != null) return status == 'NEAR_EXPIRY';
    final days = daysUntilExpiry ?? calculatedDaysUntilExpiry;
    return days != null && days >= 0 && days <= 7;
  }

  bool get isExpiryWarning {
    final days = daysUntilExpiry ?? calculatedDaysUntilExpiry;
    return days != null && days > 7 && days <= 30;
  }

  String get expiryStatusText {
    final days = daysUntilExpiry ?? calculatedDaysUntilExpiry;
    if (days == null) return 'মেয়াদ নেই';
    if (days < 0) return 'মেয়াদ শেষ';
    if (days == 0) return 'আজ মেয়াদ শেষ';
    if (days == 1) return 'আগামীকাল মেয়াদ শেষ';
    if (days <= 30) return '$days দিনে মেয়াদ শেষ';
    return '${days ~/ 30} মাসে মেয়াদ শেষ';
  }

  bool get isDepleted => quantity <= 0;
  double get totalValue => quantity * purchasePrice;

  static DateTime _parseDateOnly(String value) {
    final parts = value.substring(0, 10).split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
