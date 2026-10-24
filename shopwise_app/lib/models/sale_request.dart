/// Sale payload sent to POST /api/v1/sales.
class SaleRequest {
  final List<SaleRequestItem> items;
  final double discount;
  final List<SaleRequestPayment> payments;
  final int? customerId;

  const SaleRequest({
    required this.items,
    this.discount = 0,
    this.payments = const [],
    this.customerId,
  });

  Map<String, dynamic> toJson() => {
        'items': items.map((item) => item.toJson()).toList(),
        'discount': discount,
        'payments': payments.map((payment) => payment.toJson()).toList(),
        if (customerId != null) 'customer_id': customerId,
      };
}

class SaleRequestItem {
  final int productId;
  final double quantity;
  final double unitPrice;

  const SaleRequestItem({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
      };
}

class SaleRequestPayment {
  final double amount;
  final String paymentMethod;

  const SaleRequestPayment({required this.amount, required this.paymentMethod});

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'payment_method': paymentMethod,
      };
}
