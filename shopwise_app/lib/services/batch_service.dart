import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/network/api_exception.dart';
import '../models/batch_model.dart';

/// Batch (stock) service backed by Cloud Firestore.
///
/// Batches live at `shops/{ownerUid}/batches/{id}` with a `product_id` field
/// that stores the product's Firestore document id. To keep the existing
/// [BatchModel.fromJson]-based provider and screens untouched, [getBatches]
/// and [getFefoRecommendations] return legacy-shaped maps (snake_case keys,
/// ISO date strings, stable int ids) rather than typed model objects.
class BatchService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw ApiException(message: 'প্রথমে লগইন করুন');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection('shops').doc(_uid).collection('products');

  CollectionReference<Map<String, dynamic>> get _batchesRef =>
      _firestore.collection('shops').doc(_uid).collection('batches');

  // ---------------------------------------------------------------------------
  // Public API (contract unchanged from the old Dio version)
  // ---------------------------------------------------------------------------

  /// Returns `{'product': {'current_stock': <double>}, 'batches': [<legacy map>, ...]}`.
  Future<Map<String, dynamic>> getBatches(
    int productId, {
    bool includeDepleted = false,
  }) async {
    try {
      final productDocId = await _resolveProductDocId(productId);

      final batchSnap =
          await _batchesRef.where('product_id', isEqualTo: productDocId).get();

      var batches = batchSnap.docs
          .map((d) => _batchToLegacyMap(d, productId))
          .toList();

      if (!includeDepleted) {
        batches = batches
            .where((b) => ((b['quantity'] as num?)?.toDouble() ?? 0) > 0)
            .toList();
      }

      final productDoc = await _productsRef.doc(productDocId).get();
      final currentStock =
          (productDoc.data()?['total_stock'] as num?)?.toDouble() ?? 0;

      return {
        'product': {'current_stock': currentStock},
        'batches': batches,
      };
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error);
    }
  }

  /// Adds a batch and increments the product's denormalised `total_stock` so
  /// the product list and Smart Assistant insights stay in sync.
  Future<BatchModel> addBatch({
    required int productId,
    required DateTime purchaseDate, required double quantity, required double purchasePrice, String? batchNumber,
    DateTime? expiryDate,
  }) async {
    try {
      final productDocId = await _resolveProductDocId(productId);
      final now = DateTime.now().toUtc();

      final batchData = <String, dynamic>{
        'product_id': productDocId,
        if (batchNumber != null && batchNumber.trim().isNotEmpty)
          'batch_number': batchNumber.trim(),
        'purchase_date': Timestamp.fromDate(
          DateTime(purchaseDate.year, purchaseDate.month, purchaseDate.day),
        ),
        'expiry_date': expiryDate == null
            ? null
            : Timestamp.fromDate(
                DateTime(expiryDate.year, expiryDate.month, expiryDate.day),
              ),
        'quantity': quantity,
        'purchase_price': purchasePrice,
        'is_active': true,
        'created_at': Timestamp.fromDate(now),
        'updated_at': Timestamp.fromDate(now),
      };

      // Use a batch write so both the new batch doc and the total_stock
      // increment happen atomically.
      final writeBatch = _firestore.batch();
      writeBatch.set(_batchesRef.doc(), batchData);
      writeBatch.set(
        _productsRef.doc(productDocId),
        {
          'total_stock': FieldValue.increment(quantity),
          'updated_at': Timestamp.fromDate(now),
        },
        SetOptions(merge: true),
      );
      await writeBatch.commit();

      // The provider calls load() after this, so a minimal model is fine.
      return BatchModel(
        id: 0,
        productId: productId,
        batchNumber: batchNumber,
        purchaseDate: purchaseDate,
        expiryDate: expiryDate,
        quantity: quantity,
        purchasePrice: purchasePrice,
        createdAt: now,
        updatedAt: now,
      );
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<BatchModel> getBatch(int batchId) async {
    try {
      final uid = _uid;
      final docId = await _resolveBatchDocId(batchId);
      final doc = await _batchesRef.doc(docId).get();
      if (!doc.exists) throw ApiException(message: 'ব্যাচ পাওয়া যায়নি');
      return BatchModel.fromFirestore(doc, shopId: uid);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error);
    }
  }

  /// Applies a map of legacy-keyed changes (e.g. `{'quantity': 5.0}`) to a batch.
  Future<BatchModel> updateBatch(
      int batchId, Map<String, dynamic> changes,) async {
    try {
      final uid = _uid;
      final docId = await _resolveBatchDocId(batchId);
      final now = DateTime.now().toUtc();
      final data = <String, dynamic>{'updated_at': Timestamp.fromDate(now)};

      for (final entry in changes.entries) {
        switch (entry.key) {
          case 'quantity':
            data['quantity'] = (entry.value as num).toDouble();
            break;
          case 'purchase_price':
            data['purchase_price'] = (entry.value as num).toDouble();
            break;
          case 'batch_number':
            data['batch_number'] = entry.value?.toString();
            break;
          case 'purchase_date':
            if (entry.value != null) {
              data['purchase_date'] =
                  Timestamp.fromDate(DateTime.parse(entry.value.toString()));
            }
            break;
          case 'expiry_date':
            data['expiry_date'] = entry.value == null
                ? null
                : Timestamp.fromDate(
                    DateTime.parse(entry.value.toString()),
                  );
            break;
          case 'is_active':
            data['is_active'] = entry.value == true || entry.value == 1;
            break;
        }
      }

      await _batchesRef.doc(docId).set(data, SetOptions(merge: true));
      final doc = await _batchesRef.doc(docId).get();
      return BatchModel.fromFirestore(doc, shopId: uid);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> deactivateBatch(int batchId) async {
    try {
      final docId = await _resolveBatchDocId(batchId);
      await _batchesRef.doc(docId).set(
        {
          'is_active': false,
          'updated_at': Timestamp.fromDate(DateTime.now().toUtc()),
        },
        SetOptions(merge: true),
      );
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error);
    }
  }

  /// Stock history. The prototype has no separate transactions collection so an
  /// empty list is returned — the screen shows "no history yet" gracefully.
  Future<Map<String, dynamic>> getStockHistory(int productId) async => {'transactions': <Map<String, dynamic>>[]};

  /// FEFO recommendation: active batches with remaining stock, sorted
  /// earliest-expiry first, no-expiry batches last.
  Future<Map<String, dynamic>> getFefoRecommendations(int productId) async {
    try {
      final productDocId = await _resolveProductDocId(productId);
      final snap =
          await _batchesRef.where('product_id', isEqualTo: productDocId).get();

      // Filter: active && quantity > 0
      final docs = snap.docs.where((d) {
        final data = d.data();
        final active = data['is_active'] as bool? ?? true;
        final qty = (data['quantity'] as num?)?.toDouble() ?? 0;
        return active && qty > 0;
      }).toList();

      // Sort FEFO: earliest expiry first, null expiry last.
      docs.sort((a, b) {
        final ae = _tsToDate(a.data()['expiry_date']);
        final be = _tsToDate(b.data()['expiry_date']);
        if (ae == null && be == null) return 0;
        if (ae == null) return 1;
        if (be == null) return -1;
        return ae.compareTo(be);
      });

      final batches = <Map<String, dynamic>>[];
      for (var i = 0; i < docs.length; i++) {
        final data = docs[i].data();
        final expiry = _tsToDate(data['expiry_date']);
        final days = expiry == null ? 0 : _daysUntilExpiry(expiry);
        batches.add({
          'batch_id': _stableId(docs[i].id),
          'batch_number': data['batch_number'],
          'expiry_date': expiry == null ? '' : _dateOnly(expiry),
          'quantity': (data['quantity'] as num?)?.toDouble() ?? 0,
          'days_until_expiry': days,
          'priority': i + 1,
        });
      }
      return {'batches': batches};
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<String> _resolveProductDocId(int productId) async {
    final snap = await _productsRef.get();
    for (final doc in snap.docs) {
      if (_stableId(doc.id) == productId) return doc.id;
    }
    throw ApiException(message: 'পণ্য পাওয়া যায়নি');
  }

  Future<String> _resolveBatchDocId(int batchId) async {
    final snap = await _batchesRef.get();
    for (final doc in snap.docs) {
      if (_stableId(doc.id) == batchId) return doc.id;
    }
    throw ApiException(message: 'ব্যাচ পাওয়া যায়নি');
  }

  /// Converts a Firestore document to the snake_case map shape that
  /// [BatchModel.fromJson] and the legacy provider expect.
  Map<String, dynamic> _batchToLegacyMap(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    int productId,
  ) {
    final data = doc.data();
    final purchase = _tsToDate(data['purchase_date']);
    final expiry = _tsToDate(data['expiry_date']);
    final createdAt = _tsToDate(data['created_at']) ?? DateTime.now();
    final updatedAt = _tsToDate(data['updated_at']) ?? DateTime.now();
    return {
      'id': _stableId(doc.id),
      'product_id': productId,
      'batch_number': data['batch_number'],
      'purchase_date': _dateOnly(purchase),
      'expiry_date': expiry == null ? null : _dateOnly(expiry),
      'quantity': (data['quantity'] as num?)?.toDouble() ?? 0,
      'purchase_price': (data['purchase_price'] as num?)?.toDouble() ?? 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_active': data['is_active'] ?? true,
    };
  }

  /// Converts a Firestore [Timestamp], [DateTime], or ISO [String] to a
  /// [DateTime]. Returns `null` if the value is absent.
  DateTime? _tsToDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _dateOnly(DateTime? date) {
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  int _daysUntilExpiry(DateTime expiry) {
    final today = DateTime.now();
    return DateTime.utc(expiry.year, expiry.month, expiry.day)
        .difference(DateTime.utc(today.year, today.month, today.day))
        .inDays;
  }

  /// Deterministic FNV-1a hash — matches the mapping used by every other
  /// Firestore-backed service so the same doc id always maps to the same int.
  static int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final byte in value.codeUnits) {
      hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  ApiException _mapError(Object error) {
    if (error is FirebaseException) {
      return ApiException(
          message: error.message ?? 'স্টক তথ্য লোড করা যায়নি',);
    }
    return ApiException(message: 'স্টক তথ্য লোড করা যায়নি');
  }
}
