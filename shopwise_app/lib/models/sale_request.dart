/// Sale payload sent to the sales engine (Firestore).
class SaleRequest {

  const SaleRequest({
    required this.items,
    this.discount = 0,
    this.payments = const [],
    this.customerId,
    this.customerDocId,
    this.customerName,
    this.returnDate,
  });
  final List<SaleRequestItem> items;
  final double discount;
  final List<SaleRequestPayment> payments;
  final int? customerId;
  /// Firestore document id of the customer; replaces the legacy numeric id
  /// for Firestore-backed sales.
  final String? customerDocId;
  final String? customerName;
  final DateTime? returnDate;

  Map<String, dynamic> toJson() => {
        'items': items.map((item) => item.toJson()).toList(),
        'discount': discount,
        'payments': payments.map((payment) => payment.toJson()).toList(),
        if (customerId != null) 'customer_id': customerId,
        if (returnDate != null)
          'return_date': returnDate!.toIso8601String(),
      };
}

class SaleRequestItem {

  const SaleRequestItem({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });
  final int productId;
  final double quantity;
  final double unitPrice;

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
      };
}

class SaleRequestPayment {

  const SaleRequestPayment({required this.amount, required this.paymentMethod});
  final double amount;
  final String paymentMethod;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'payment_method': paymentMethod,
      };
}
