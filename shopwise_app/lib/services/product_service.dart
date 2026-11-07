import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/network/api_exception.dart';
import '../models/product_model.dart';

/// Product service backed by Cloud Firestore.
///
/// Products live at `shops/{ownerUid}/products/{id}`. [productsStream] gives
/// real-time updates; the CRUD methods keep the legacy int-id contract so the
/// existing Riverpod provider and screens work unchanged.
class ProductService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw ApiException(message: 'প্রথমে লগইন করুন');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('shops').doc(_uid).collection('products');

  /// Real-time stream of all products for the signed-in shop.
  Stream<List<ProductModel>> productsStream() {
    final uid = _uid;
    return _ref.snapshots().map((snap) => snap.docs
        .map((d) => ProductModel.fromFirestore(d, shopId: uid))
        .toList(),);
  }

  /// One-time fetch with optional client-side search/category filtering.
  Future<List<ProductModel>> getProducts({
    String? search,
    int? categoryId,
    int? limit,
    int? offset,
  }) async {
    try {
      final uid = _uid;
      final snap = await _ref.get();
      var list = snap.docs
          .map((d) => ProductModel.fromFirestore(d, shopId: uid))
          .toList();
      if (categoryId != null) {
        list = list.where((p) => p.categoryId == categoryId).toList();
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        list = list.where((p) => p.name.toLowerCase().contains(q) ||
              (p.sku?.toLowerCase().contains(q) ?? false) ||
              (p.barcode?.toLowerCase().contains(q) ?? false),).toList();
      }
      return list;
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<ProductModel> getProductById(int id) async {
    try {
      final uid = _uid;
      final docId = await _resolveDocId(id);
      final doc = await _ref.doc(docId).get();
      if (!doc.exists) {
        throw ApiException(message: 'পণ্য পাওয়া যায়নি');
      }
      return ProductModel.fromFirestore(doc, shopId: uid);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error);
    }
  }

  /// Creates a product. `categoryId` is stored as-is (the legacy int id used by
  /// the UI) so client-side category filtering keeps matching.
  Future<ProductModel> createProduct({
    required int categoryId,
    required String name,
    required String unit, required double sellingPrice, required double defaultPurchasePrice, String? sku,
    String? barcode,
    String? author,
    String? isbn,
    double minimumStock = 0,
    int targetStockDays = 7,
  }) async {
    try {
      final uid = _uid;
      final now = DateTime.now().toUtc();
      final data = <String, dynamic>{
        'category_id': categoryId,
        'name': name.trim(),
        if (sku != null && sku.trim().isNotEmpty) 'sku': sku.trim(),
        if (barcode != null && barcode.trim().isNotEmpty) 'barcode': barcode.trim(),
        if (author != null && author.trim().isNotEmpty) 'author': author.trim(),
        if (isbn != null && isbn.trim().isNotEmpty) 'isbn': isbn.trim(),
        'unit': unit,
        'selling_price': sellingPrice,
        'default_purchase_price': defaultPurchasePrice,
        'minimum_stock': minimumStock,
        'target_stock_days': targetStockDays,
        'is_active': true,
        'total_stock': 0.0,
        'created_at': Timestamp.fromDate(now),
        'updated_at': Timestamp.fromDate(now),
      };
      final ref = await _ref.add(data);
      final doc = await ref.get();
      return ProductModel.fromFirestore(doc, shopId: uid);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<ProductModel> updateProduct({
    required int id,
    int? categoryId,
    String? name,
    String? sku,
    String? barcode,
    String? author,
    String? isbn,
    String? unit,
    double? sellingPrice,
    double? defaultPurchasePrice,
    double? minimumStock,
    int? targetStockDays,
  }) async {
    try {
      final uid = _uid;
      final docId = await _resolveDocId(id);
      final data = <String, dynamic>{
        'updated_at': Timestamp.fromDate(DateTime.now().toUtc()),
      };
      if (categoryId != null) data['category_id'] = categoryId;
      if (name != null) data['name'] = name.trim();
      if (sku != null) data['sku'] = sku.trim();
      if (barcode != null) data['barcode'] = barcode.trim();
      if (author != null) data['author'] = author.trim();
      if (isbn != null) data['isbn'] = isbn.trim();
      if (unit != null) data['unit'] = unit;
      if (sellingPrice != null) data['selling_price'] = sellingPrice;
      if (defaultPurchasePrice != null) {
        data['default_purchase_price'] = defaultPurchasePrice;
      }
      if (minimumStock != null) data['minimum_stock'] = minimumStock;
      if (targetStockDays != null) data['target_stock_days'] = targetStockDays;
      await _ref.doc(docId).set(data, SetOptions(merge: true));
      final doc = await _ref.doc(docId).get();
      return ProductModel.fromFirestore(doc, shopId: uid);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      final docId = await _resolveDocId(id);
      await _ref.doc(docId).delete();
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<ProductModel>> getLowStockProducts() async {
    final all = await getProducts();
    return all.where((p) => p.isLowStock).toList();
  }

  /// Resolves a legacy int id to the Firestore document id.
  Future<String> _resolveDocId(int id) async {
    final uid = _uid;
    final snap = await _ref.get();
    for (final doc in snap.docs) {
      if (ProductModel.fromFirestore(doc, shopId: uid).id == id) return doc.id;
    }
    throw ApiException(message: 'পণ্য পাওয়া যায়নি');
  }

  ApiException _mapError(Object error) {
    if (error is FirebaseException) {
      return ApiException(message: error.message ?? 'পণ্য তথ্য লোড করা যায়নি');
    }
    return ApiException(message: 'পণ্য তথ্য লোড করা যায়নি');
  }
}
