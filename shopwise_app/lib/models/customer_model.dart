import 'package:cloud_firestore/cloud_firestore.dart';

/// A customer record stored at `shops/{shopId}/customers/{id}`.
///
/// [totalDue] is the cumulative baki (amount owed) — it is incremented
/// whenever a sale has `due_amount > 0` and decremented whenever the
/// shopkeeper records a payment.
class CustomerModel {
  /// Firestore document id.
  final String docId;
  final String name;
  final String phone;
  final double totalDue;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomerModel({
    required this.docId,
    required this.name,
    required this.phone,
    required this.totalDue,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return CustomerModel(
      docId: doc.id,
      name: (data['name'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      totalDue: _toDouble(data['total_due']),
      createdAt: _toDateTime(data['created_at']),
      updatedAt: _toDateTime(data['updated_at']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'phone': phone,
        'total_due': totalDue,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
      };

  CustomerModel copyWith({
    String? docId,
    String? name,
    String? phone,
    double? totalDue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      CustomerModel(
        docId: docId ?? this.docId,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        totalDue: totalDue ?? this.totalDue,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  /// Whether this customer has any outstanding balance.
  bool get hasDue => totalDue > 0.005;
}
