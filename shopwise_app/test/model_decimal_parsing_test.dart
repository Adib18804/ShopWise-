import 'package:flutter_test/flutter_test.dart';
import 'package:shopwise_app/models/batch_model.dart';
import 'package:shopwise_app/models/product_model.dart';

void main() {
  test('BatchModel parses MySQL DECIMAL strings', () {
    final batch = BatchModel.fromJson({
      'id': 1,
      'product_id': 2,
      'batch_number': 'B-1',
      'purchase_date': '2026-10-15',
      'expiry_date': '2027-01-01',
      'quantity': '20.00',
      'purchase_price': '8.25',
      'created_at': '2026-10-15T10:00:00.000Z',
      'updated_at': '2026-10-15T10:00:00.000Z',
    });

    expect(batch.quantity, 20.0);
    expect(batch.purchasePrice, 8.25);
  });

  test(
    'ProductModel parses MySQL DECIMAL strings and retains integer fields',
    () {
    final product = ProductModel.fromJson({
      'id': 1,
      'shop_id': 2,
      'category_id': null,
      'name': 'Rice',
      'unit': 'kg',
      'selling_price': '75.50',
      'default_purchase_price': '62.25',
      'minimum_stock': '10.00',
      'target_stock_days': 7,
      'total_stock': '24.50',
      'batch_count': 2,
      'created_at': '2026-10-15T10:00:00.000Z',
      'updated_at': '2026-10-15T10:00:00.000Z',
    });

    expect(product.sellingPrice, 75.5);
    expect(product.defaultPurchasePrice, 62.25);
    expect(product.minimumStock, 10.0);
    expect(product.totalStock, 24.5);
    expect(product.targetStockDays, 7);
  });
}
