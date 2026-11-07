import 'package:cloud_firestore/cloud_firestore.dart';

/// Invoice returned after the backend (or Firestore) processes a sale.
class SaleModel {

  const SaleModel({
    required this.id,
    required this.shopId,
    required this.invoiceNumber,
    required this.totalAmount, required this.discount, required this.paidAmount, required this.dueAmount, required this.status, this.docId,
    this.customerId,
    this.customerDocId,
    this.customerName,
    this.paymentMethod = 'cash',
    this.createdAt,
    this.returnDate,
    this.items = const [],
    this.payments = const [],
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) => SaleModel(
        id: _toInt(json['id']),
        shopId: _toInt(json['shop_id']),
        invoiceNumber: json['invoice_number']?.toString() ?? '',
        customerId:
            json['customer_id'] == null ? null : _toInt(json['customer_id']),
        totalAmount: _toDouble(json['total_amount']),
        discount: _toDouble(json['discount']),
        paidAmount: _toDouble(json['paid_amount']),
        dueAmount: _toDouble(json['due_amount']),
        status: json['status']?.toString() ?? 'completed',
        paymentMethod: json['payment_method']?.toString() ?? 'cash',
        createdAt: _toDateTime(json['created_at']),
        returnDate: _toDateTime(json['return_date']),
        items: _mapList(json['items'], SaleItemModel.fromJson),
        payments: _mapList(json['payments'], SalePaymentModel.fromJson),
      );

  /// Builds a [SaleModel] from a Firestore invoice document.
  factory SaleModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    int shopIntId,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawItems = data['items'];
    final items = <SaleItemModel>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        items.add(SaleItemModel(
          productId: _stableId(raw['product_id']?.toString() ?? ''),
          productName: raw['product_name']?.toString(),
          quantity: _toDouble(raw['quantity']),
          unitPrice: _toDouble(raw['unit_price']),
          totalPrice: _toDouble(raw['total_price']),
        ),);
      }
    }
    final createdRaw = data['created_at'];
    final returnRaw = data['return_date'];
    final createdAt = createdRaw is Timestamp
        ? createdRaw.toDate()
        : createdRaw is String
            ? DateTime.tryParse(createdRaw)
            : null;
    return SaleModel(
      id: _stableId(doc.id),
      docId: doc.id,
      shopId: shopIntId,
      invoiceNumber: (data['invoice_number'] as String?) ?? '',
      customerDocId: data['customer_id'] as String?,
      customerName: data['customer_name'] as String?,
      totalAmount: _toDouble(data['total_amount']),
      discount: _toDouble(data['discount']),
      paidAmount: _toDouble(data['paid_amount']),
      dueAmount: _toDouble(data['due_amount']),
      status: (data['status'] as String?) ?? 'completed',
      paymentMethod: (data['payment_method'] as String?) ?? 'cash',
      createdAt: createdAt,
      returnDate: returnRaw is Timestamp
          ? returnRaw.toDate()
          : returnRaw is String
              ? DateTime.tryParse(returnRaw)
              : null,
      items: items,
    );
  }
  final int id;
  final int shopId;
  final String invoiceNumber;
  /// Firestore document id of this invoice (`null` for legacy API objects).
  final String? docId;
  final int? customerId;
  /// Firestore document id of the customer who has a baki (due amount).
  final String? customerDocId;
  final String? customerName;
  final double totalAmount;
  final double discount;
  final double paidAmount;
  final double dueAmount;
  final String status;
  final String paymentMethod;
  final DateTime? createdAt;
  final DateTime? returnDate;
  final List<SaleItemModel> items;
  final List<SalePaymentModel> payments;

  Map<String, dynamic> toJson() => {
        'id': id,
        'shop_id': shopId,
        'invoice_number': invoiceNumber,
        'customer_id': customerId,
        'total_amount': totalAmount,
        'discount': discount,
        'paid_amount': paidAmount,
        'due_amount': dueAmount,
        'status': status,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (returnDate != null)
          'return_date': returnDate!.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
        'payments': payments.map((payment) => payment.toJson()).toList(),
      };
}

/// One FEFO-allocated line in a processed invoice.
class SaleItemModel {

  const SaleItemModel({
    required this.productId, required this.quantity, required this.unitPrice, required this.totalPrice, this.id,
    this.productName,
    this.batchId,
    this.purchasePrice,
  });

  factory SaleItemModel.fromJson(Map<String, dynamic> json) => SaleItemModel(
        id: json['id'] == null ? null : _toInt(json['id']),
        productId: _toInt(json['product_id']),
        productName: json['product_name']?.toString(),
        batchId: json['batch_id'] == null ? null : _toInt(json['batch_id']),
        quantity: _toDouble(json['quantity']),
        unitPrice: _toDouble(json['unit_price']),
        purchasePrice: json['purchase_price'] == null
            ? null
            : _toDouble(json['purchase_price']),
        totalPrice: _toDouble(json['total_price']),
      );
  final int? id;
  final int productId;
  final String? productName;
  final int? batchId;
  final double quantity;
  final double unitPrice;
  final double? purchasePrice;
  final double totalPrice;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'product_id': productId,
        if (productName != null) 'product_name': productName,
        if (batchId != null) 'batch_id': batchId,
        'quantity': quantity,
        'unit_price': unitPrice,
        if (purchasePrice != null) 'purchase_price': purchasePrice,
        'total_price': totalPrice,
      };
}

class SalePaymentModel {

  const SalePaymentModel(
      {required this.amount, required this.paymentMethod, this.id,});

  factory SalePaymentModel.fromJson(Map<String, dynamic> json) =>
      SalePaymentModel(
        id: json['id'] == null ? null : _toInt(json['id']),
        amount: _toDouble(json['amount']),
        paymentMethod: json['payment_method']?.toString() ?? '',
      );
  final int? id;
  final double amount;
  final String paymentMethod;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'amount': amount,
        'payment_method': paymentMethod,
      };
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0;
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _toDateTime(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

List<T> _mapList<T>(dynamic value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map(parse)
      .toList(growable: false);
}

/// Deterministic FNV-1a hash so the same Firestore doc id always maps to the
/// same int. Matches the mapping used by every other Firestore-backed model.
int _stableId(String value) {
  var hash = 0x811c9dc5;
  for (final byte in value.codeUnits) {
    hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
