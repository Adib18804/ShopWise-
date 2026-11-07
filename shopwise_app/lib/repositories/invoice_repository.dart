import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/network/api_exception.dart';
import '../models/sale_model.dart';

/// Fetches invoices from `shops/{uid}/invoices` for the Sale History screen.
class InvoiceRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw ApiException(message: 'প্রথমে লগইন করুন');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _invoicesCol(String uid) =>
      _firestore.collection('shops').doc(uid).collection('invoices');

  /// Real-time stream of all invoices, newest first.
  Stream<List<SaleModel>> invoicesStream() {
    final uid = _uid;
    final shopIntId = _stableId(uid);
    return _invoicesCol(uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => SaleModel.fromFirestore(d, shopIntId)).toList(),);
  }

  /// Paged one-time fetch (for initial load or pull-to-refresh).
  Future<List<SaleModel>> fetchInvoices({int limit = 50}) async {
    try {
      final uid = _uid;
      final shopIntId = _stableId(uid);
      final snap = await _invoicesCol(uid)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => SaleModel.fromFirestore(d, shopIntId))
          .toList();
    } on ApiException {
      rethrow;
    } catch (error) {
      if (error is FirebaseException) {
        throw ApiException(message: error.message ?? 'বিক্রয় ইতিহাস লোড করা যায়নি');
      }
      throw ApiException(message: 'বিক্রয় ইতিহাস লোড করা যায়নি');
    }
  }

  /// Returns a single invoice by its Firestore document id.
  Future<SaleModel?> fetchInvoiceById(String docId) async {
    try {
      final uid = _uid;
      final shopIntId = _stableId(uid);
      final doc = await _invoicesCol(uid).doc(docId).get();
      if (!doc.exists) return null;
      return SaleModel.fromFirestore(doc, shopIntId);
    } on ApiException {
      rethrow;
    } catch (error) {
      if (error is FirebaseException) {
        throw ApiException(message: error.message ?? 'ইনভয়েস লোড করা যায়নি');
      }
      throw ApiException(message: 'ইনভয়েস লোড করা যায়নি');
    }
  }

  static int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final byte in value.codeUnits) {
      hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
