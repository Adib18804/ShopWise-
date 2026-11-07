import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/network/api_exception.dart';
import '../models/category_model.dart';

/// Category service backed by Cloud Firestore.
///
/// Categories live at `shops/{ownerUid}/categories/{id}`. The legacy `int` ids
/// used by the UI are a stable hash of the Firestore document id.
class CategoryService {
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
      _firestore.collection('shops').doc(_uid).collection('categories');

  /// Returns all categories. If the shop has no categories yet, a default
  /// "সাধারণ" category is created (idempotently) so products can be added.
  Future<List<CategoryModel>> getCategories() async {
    try {
      final uid = _uid;
      var snap = await _ref.get();
      if (snap.docs.isEmpty) {
        final now = DateTime.now().toUtc();
        await _ref.doc('default').set({
          'name': 'সাধারণ',
          'description': 'ডিফল্ট ক্যাটাগরি',
          'created_at': Timestamp.fromDate(now),
          'updated_at': Timestamp.fromDate(now),
        }, SetOptions(merge: true),);
        snap = await _ref.get();
      }
      return snap.docs
          .map((d) => CategoryModel.fromFirestore(d, shopId: uid))
          .toList();
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<CategoryModel> createCategory({
    required String name,
    String? description,
  }) async {
    try {
      final uid = _uid;
      final now = DateTime.now().toUtc();
      final ref = await _ref.add({
        'name': name.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'created_at': Timestamp.fromDate(now),
        'updated_at': Timestamp.fromDate(now),
      });
      final doc = await ref.get();
      return CategoryModel.fromFirestore(doc, shopId: uid);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<CategoryModel> getCategoryById(int id) async {
    try {
      final uid = _uid;
      final docId = await _resolveDocId(id);
      final doc = await _ref.doc(docId).get();
      if (!doc.exists) {
        throw ApiException(message: 'ক্যাটাগরি পাওয়া যায়নি');
      }
      return CategoryModel.fromFirestore(doc, shopId: uid);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<CategoryModel> updateCategory({
    required int id,
    String? name,
    String? description,
  }) async {
    try {
      final uid = _uid;
      final docId = await _resolveDocId(id);
      final data = <String, dynamic>{
        'updated_at': Timestamp.fromDate(DateTime.now().toUtc()),
      };
      if (name != null) data['name'] = name.trim();
      if (description != null) data['description'] = description.trim();
      await _ref.doc(docId).set(data, SetOptions(merge: true));
      final doc = await _ref.doc(docId).get();
      return CategoryModel.fromFirestore(doc, shopId: uid);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      final docId = await _resolveDocId(id);
      await _ref.doc(docId).delete();
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error);
    }
  }

  /// Resolves a legacy int id back to the Firestore document id.
  Future<String> _resolveDocId(int id) async {
    final uid = _uid;
    final snap = await _ref.get();
    for (final doc in snap.docs) {
      if (CategoryModel.fromFirestore(doc, shopId: uid).id == id) return doc.id;
    }
    throw ApiException(message: 'ক্যাটাগরি পাওয়া যায়নি');
  }

  ApiException _mapError(Object error) {
    if (error is FirebaseException) {
      return ApiException(message: error.message ?? 'ক্যাটাগরি তথ্য লোড করা যায়নি');
    }
    return ApiException(message: 'ক্যাটাগরি তথ্য লোড করা যায়নি');
  }
}
