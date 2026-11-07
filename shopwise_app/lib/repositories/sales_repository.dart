import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/network/api_exception.dart';
import '../models/batch_model.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/sale_request.dart';

/// Processes sales against Cloud Firestore.
///
/// For each cart line it deducts the sold quantity from the product's batches
/// using simplified FEFO (earliest expiry first, batches without an expiry last).
/// All decrements + product `total_stock` updates + invoice creation + optional
/// customer `total_due` increment happen in a single Firestore transaction, so
/// a sale either commits fully or not at all.
class SalesRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw ApiException(message: 'প্রথমে লগইন করুন');
    }
    return uid;
  }

  Future<SaleModel> processSale(SaleRequest request) async {
    final uid = _uid;
    final shopRef = _firestore.collection('shops').doc(uid);
    final productsCol = shopRef.collection('products');
    final batchesCol = shopRef.collection('batches');
    final invoicesCol = shopRef.collection('invoices');
    final customersCol = shopRef.collection('customers');

    // ──────────────────────────────────────────────────────────────────────────
    // 1.  Resolve legacy-int product ids → Firestore doc ids + product info.
    // ──────────────────────────────────────────────────────────────────────────
    final productSnap = await productsCol.get();
    final productsByIntId = <int, _ProductInfo>{};
    for (final d in productSnap.docs) {
      final p = ProductModel.fromFirestore(d, shopId: uid);
      productsByIntId[p.id] = _ProductInfo(
        docId: p.docId ?? d.id,
        name: p.name,
        unit: p.unit,
        sellingPrice: p.sellingPrice,
      );
    }
    for (final item in request.items) {
      if (!productsByIntId.containsKey(item.productId)) {
        throw ApiException(message: 'কার্টে এমন কোনো পণ্য নেই');
      }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 2.  Plan FEFO batch deductions; abort early on insufficient stock.
    // ──────────────────────────────────────────────────────────────────────────
    final plan = <_Deduction>[];
    final productTotalDelta = <String, double>{};

    for (final item in request.items) {
      final info = productsByIntId[item.productId]!;
      final need = item.quantity;

      final batchSnap =
          await batchesCol.where('product_id', isEqualTo: info.docId).get();
      final batches = batchSnap.docs
          .map((d) => BatchModel.fromFirestore(d, shopId: uid))
          .where((b) => b.isActive && b.quantity > 0)
          .toList();

      // FEFO sort — earliest expiry first; no-expiry batches last.
      batches.sort((a, b) {
        final ae = a.expiryDate;
        final be = b.expiryDate;
        if (ae == null && be == null) return 0;
        if (ae == null) return 1;
        if (be == null) return -1;
        return ae.compareTo(be);
      });

      var remaining = need;
      for (final b in batches) {
        if (remaining <= 0) break;
        final take = b.quantity < remaining ? b.quantity : remaining;
        plan.add(_Deduction(batchDocId: b.docId ?? '', quantity: take));
        remaining -= take;
      }
      if (remaining > 0.0001) {
        throw ApiException(message: '${info.name} এর পর্যাপ্ত স্টক নেই');
      }
      productTotalDelta[info.docId] =
          (productTotalDelta[info.docId] ?? 0) + need;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 3.  Compute invoice totals.
    // ──────────────────────────────────────────────────────────────────────────
    final subtotal =
        request.items.fold<double>(0, (s, i) => s + i.quantity * i.unitPrice);
    final discount = request.discount;
    final total = subtotal - discount;
    final paid = request.payments.fold<double>(0, (s, p) => s + p.amount);
    final due = (total - paid).clamp(0.0, double.infinity);
    final paymentMethod = request.payments.isNotEmpty
        ? request.payments.first.paymentMethod
        : 'cash';

    final now = DateTime.now();
    final invoiceNumber = 'INV-${now.millisecondsSinceEpoch}';

    final itemsData = request.items.map((i) {
      final info = productsByIntId[i.productId]!;
      return <String, dynamic>{
        'product_id': info.docId,
        'product_name': info.name,
        'quantity': i.quantity,
        'unit_price': i.unitPrice,
        'total_price': i.quantity * i.unitPrice,
      };
    }).toList();

    final invoiceData = <String, dynamic>{
      'invoice_number': invoiceNumber,
      'total_amount': total,
      'discount': discount,
      'paid_amount': paid,
      'due_amount': due,
      'payment_method': paymentMethod,
      'items': itemsData,
      'status': 'completed',
      'created_at': Timestamp.fromDate(now),
      if (request.returnDate != null)
        'return_date': Timestamp.fromDate(request.returnDate!),
      // Customer fields (optional).
      if (request.customerDocId != null) 'customer_id': request.customerDocId,
      if (request.customerName != null) 'customer_name': request.customerName,
    };

    // ──────────────────────────────────────────────────────────────────────────
    // 4.  Firestore transaction: read → validate → write atomically.
    // ──────────────────────────────────────────────────────────────────────────
    await _firestore.runTransaction((tx) async {
      // --- Reads (must all come before writes) ---
      final batchReads = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final d in plan) {
        if (!batchReads.containsKey(d.batchDocId)) {
          batchReads[d.batchDocId] =
              await tx.get(batchesCol.doc(d.batchDocId));
        }
      }
      final productReads = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final pid in productTotalDelta.keys) {
        productReads[pid] = await tx.get(productsCol.doc(pid));
      }
      DocumentSnapshot<Map<String, dynamic>>? customerSnap;
      if (request.customerDocId != null && due > 0) {
        customerSnap = await tx.get(customersCol.doc(request.customerDocId));
      }

      // --- Stock validation at commit time ---
      for (final d in plan) {
        final snap = batchReads[d.batchDocId]!;
        if (!snap.exists) {
          throw ApiException(
              message: 'স্টক আপডেট করা যায়নি, আবার চেষ্টা করুন',);
        }
        final current = (snap.data()!['quantity'] as num?)?.toDouble() ?? 0;
        if (current < d.quantity - 0.0001) {
          throw ApiException(
              message: 'স্টক অপর্যাপ্ত, বিক্রয় সম্পন্ন করা যায়নি',);
        }
      }

      // --- Writes ---
      // Decrement batch quantities.
      for (final d in plan) {
        final current =
            (batchReads[d.batchDocId]!.data()!['quantity'] as num?)
                    ?.toDouble() ??
                0;
        tx.update(batchesCol.doc(d.batchDocId), {
          'quantity': current - d.quantity,
          'updated_at': Timestamp.fromDate(now),
        });
      }
      // Update product total_stock.
      for (final entry in productTotalDelta.entries) {
        final snap = productReads[entry.key];
        if (snap == null || !snap.exists) continue;
        final current =
            (snap.data()!['total_stock'] as num?)?.toDouble() ?? 0;
        final next = current - entry.value;
        tx.update(productsCol.doc(entry.key), {
          'total_stock': next < 0 ? 0.0 : next,
          'updated_at': Timestamp.fromDate(now),
        });
      }
      // Create invoice.
      tx.set(invoicesCol.doc(), invoiceData);
      // Update customer due (baki) atomically with the sale.
      if (customerSnap != null && due > 0) {
        final currentDue =
            (customerSnap.data()?['total_due'] as num?)?.toDouble() ?? 0;
        tx.set(
          customersCol.doc(request.customerDocId),
          {
            'total_due': currentDue + due,
            'updated_at': Timestamp.fromDate(now),
          },
          SetOptions(merge: true),
        );
      }
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 5.  Return a SaleModel for the UI state.
    // ──────────────────────────────────────────────────────────────────────────
    return SaleModel(
      id: now.millisecondsSinceEpoch,
      shopId: _stableId(uid),
      invoiceNumber: invoiceNumber,
      customerDocId: request.customerDocId,
      customerName: request.customerName,
      totalAmount: total,
      discount: discount,
      paidAmount: paid,
      dueAmount: due,
      status: 'completed',
      paymentMethod: paymentMethod,
      createdAt: now,
      items: request.items.map((i) {
        final info = productsByIntId[i.productId]!;
        return SaleItemModel(
          productId: i.productId,
          productName: info.name,
          quantity: i.quantity,
          unitPrice: i.unitPrice,
          totalPrice: i.quantity * i.unitPrice,
        );
      }).toList(),
      payments: request.payments
          .map((p) =>
              SalePaymentModel(amount: p.amount, paymentMethod: p.paymentMethod),)
          .toList(),
    );
  }

  static int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final byte in value.codeUnits) {
      hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}

class _ProductInfo {

  const _ProductInfo({
    required this.docId,
    required this.name,
    required this.unit,
    required this.sellingPrice,
  });
  final String docId;
  final String name;
  final String unit;
  final double sellingPrice;
}

class _Deduction {

  const _Deduction({required this.batchDocId, required this.quantity});
  final String batchDocId;
  final double quantity;
}
