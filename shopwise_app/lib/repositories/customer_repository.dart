import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/network/api_exception.dart';
import '../models/customer_model.dart';

/// Customer (Baki Khata) repository backed by Cloud Firestore.
///
/// Each customer lives at `shops/{uid}/customers/{cid}`.
/// [totalDue] is the running balance — the sales engine increments it when a
/// sale has a due amount, and [recordPayment] decrements it.
class CustomerRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw ApiException(message: 'প্রথমে লগইন করুন');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('shops').doc(_uid).collection('customers');

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Real-time stream, sorted by name.
  Stream<List<CustomerModel>> customersStream() {
    return _col.orderBy('name').snapshots().map(
          (snap) => snap.docs.map(CustomerModel.fromFirestore).toList(),
        );
  }

  Future<List<CustomerModel>> fetchAll() async {
    try {
      final snap = await _col.orderBy('name').get();
      return snap.docs.map(CustomerModel.fromFirestore).toList();
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'গ্রাহক তালিকা লোড করা যায়নি');
    }
  }

  Future<CustomerModel?> fetchById(String docId) async {
    try {
      final doc = await _col.doc(docId).get();
      if (!doc.exists) return null;
      return CustomerModel.fromFirestore(doc);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'গ্রাহক তথ্য লোড করা যায়নি');
    }
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Creates a new customer. Returns the created model.
  Future<CustomerModel> create({
    required String name,
    required String phone,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final data = <String, dynamic>{
        'name': name.trim(),
        'phone': phone.trim(),
        'total_due': 0.0,
        'created_at': Timestamp.fromDate(now),
        'updated_at': Timestamp.fromDate(now),
      };
      final ref = await _col.add(data);
      final doc = await ref.get();
      return CustomerModel.fromFirestore(doc);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'গ্রাহক তৈরি করা যায়নি');
    }
  }

  Future<CustomerModel> update(String docId, {String? name, String? phone}) async {
    try {
      final data = <String, dynamic>{
        'updated_at': Timestamp.fromDate(DateTime.now().toUtc()),
      };
      if (name != null) data['name'] = name.trim();
      if (phone != null) data['phone'] = phone.trim();
      await _col.doc(docId).set(data, SetOptions(merge: true));
      final doc = await _col.doc(docId).get();
      return CustomerModel.fromFirestore(doc);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'গ্রাহক তথ্য আপডেট করা যায়নি');
    }
  }

  Future<void> delete(String docId) async {
    try {
      await _col.doc(docId).delete();
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'গ্রাহক মুছতে সমস্যা হয়েছে');
    }
  }

  // ---------------------------------------------------------------------------
  // Baki (due) management
  // ---------------------------------------------------------------------------

  /// Increments a customer's `total_due` by [amount] (called by sales engine).
  /// This is safe to call inside a Firestore transaction via the batch.
  Future<void> addDue(String docId, double amount) async {
    if (amount <= 0) return;
    try {
      await _col.doc(docId).set(
        {
          'total_due': FieldValue.increment(amount),
          'updated_at': Timestamp.fromDate(DateTime.now().toUtc()),
        },
        SetOptions(merge: true),
      );
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'বাকি আপডেট করা যায়নি');
    }
  }

  /// Records a cash payment from the customer, reducing their `total_due`.
  /// Clamps the result at zero — you can't pay more than you owe.
  Future<CustomerModel> recordPayment(String docId, double payment) async {
    if (payment <= 0) throw ApiException(message: 'পেমেন্টের পরিমাণ শূন্যের বেশি হতে হবে');
    try {
      await _firestore.runTransaction((tx) async {
        final ref = _col.doc(docId);
        final snap = await tx.get(ref);
        if (!snap.exists) throw ApiException(message: 'গ্রাহক পাওয়া যায়নি');
        final currentDue =
            (snap.data()!['total_due'] as num?)?.toDouble() ?? 0;
        final newDue = (currentDue - payment).clamp(0.0, double.infinity);
        tx.set(
          ref,
          {
            'total_due': newDue,
            'updated_at': Timestamp.fromDate(DateTime.now().toUtc()),
          },
          SetOptions(merge: true),
        );
      });
      final doc = await _col.doc(docId).get();
      return CustomerModel.fromFirestore(doc);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'পেমেন্ট রেকর্ড করা যায়নি');
    }
  }

  ApiException _mapError(Object error, String fallback) {
    if (error is FirebaseException) {
      return ApiException(message: error.message ?? fallback);
    }
    return ApiException(message: fallback);
  }
}
