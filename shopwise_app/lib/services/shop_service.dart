import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/network/api_exception.dart';
import '../models/shop_model.dart';

/// Shop service backed by Cloud Firestore.
///
/// Each shop lives at `shops/{ownerUid}` and is keyed by the owner's Firebase
/// UID, so every method here derives the shop path from the currently signed-in
/// user instead of relying on a server-issued numeric id or a bearer token.
class ShopService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw ApiException(message: 'প্রথমে লগইন করুন');
    }
    return uid;
  }

  DocumentReference<Map<String, dynamic>> get _shopRef =>
      _firestore.collection('shops').doc(_uid);

  /// Creates (or completes) the shop record for the signed-in user.
  ///
  /// This is the only path that creates the `shops/{uid}` document. It stores
  /// the selected business type and marks setup complete after form submission.
  Future<ShopModel> createShop({
    required String shopName,
    required String address,
    required String phone,
    String currency = 'BDT',
    ShopType shopType = ShopType.general,
  }) async {
    try {
      final uid = _uid;
      final now = DateTime.now().toUtc();

      final shopFields = <String, dynamic>{
        'owner_id': uid,
        'shop_name': shopName.trim(),
        'address': address.trim(),
        'phone': phone.trim(),
        'currency': currency,
        'shop_type': shopType.value,
        'setup_complete': true,
        'created_at': Timestamp.fromDate(now),
        'updated_at': Timestamp.fromDate(now),
      };
      final batch = _firestore.batch();
      batch.set(_shopRef, shopFields, SetOptions(merge: true));
      batch.set(
        _firestore.collection('users').doc(uid),
        {
          'has_shop': true,
          'updated_at': Timestamp.fromDate(now),
        },
        SetOptions(merge: true),
      );
      await batch.commit();

      final snapshot = await _shopRef.get();
      if (!snapshot.exists) {
        throw ApiException(message: 'দোকান তৈরি করা যায়নি। আবার চেষ্টা করুন।');
      }
      return _toShopModel(snapshot);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error, fallback: 'দোকান তৈরি করা যায়নি');
    }
  }

  /// Returns the signed-in user's shop.
  Future<ShopModel> getMyShop() async {
    try {
      final snapshot = await _shopRef.get();
      if (!snapshot.exists) {
        throw ApiException(message: 'দোকান পাওয়া যায়নি। দোকান সেটআপ করুন।');
      }
      return _toShopModel(snapshot);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error, fallback: 'দোকান তথ্য লোড করা যায়নি');
    }
  }

  /// Whether the signed-in user has completed shop setup.
  Future<bool> checkShop() async {
    try {
      final snapshot = await _shopRef.get();
      return snapshot.exists && snapshot.data()?['setup_complete'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Updates the shop's editable fields.
  Future<ShopModel> updateShop({
    String? shopName,
    String? address,
    String? phone,
    String? currency,
    ShopType? shopType,
  }) async {
    try {
      final fields = <String, dynamic>{};
      if (shopName != null) fields['shop_name'] = shopName.trim();
      if (address != null) fields['address'] = address.trim();
      if (phone != null) fields['phone'] = phone.trim();
      if (currency != null) fields['currency'] = currency;
      if (shopType != null) fields['shop_type'] = shopType.value;
      if (fields.isEmpty) return await getMyShop();

      fields['updated_at'] = Timestamp.fromDate(DateTime.now().toUtc());
      await _shopRef.set(fields, SetOptions(merge: true));

      final snapshot = await _shopRef.get();
      return _toShopModel(snapshot);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error, fallback: 'দোকান আপডেট করা যায়নি');
    }
  }

  /// Deletes the shop record (and clears the denormalised `has_shop` flag).
  Future<void> deleteShop() async {
    try {
      final uid = _uid;
      final batch = _firestore.batch();
      batch.delete(_shopRef);
      batch.set(
        _firestore.collection('users').doc(uid),
        {'has_shop': false},
        SetOptions(merge: true),
      );
      await batch.commit();
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _mapError(error, fallback: 'দোকান মুছতে সমস্যা হয়েছে');
    }
  }

  ShopModel _toShopModel(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return ShopModel(
      id: _stableNumericId(snapshot.id),
      ownerId: _stableNumericId(snapshot.id),
      shopName: (data['shop_name'] as String?) ?? '',
      address: (data['address'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      currency: (data['currency'] as String?) ?? 'BDT',
      shopType: ShopType.fromValue(data['shop_type']),
      createdAt: _toDate(data['created_at']) ?? DateTime.now(),
      updatedAt: _toDate(data['updated_at']) ?? DateTime.now(),
    );
  }

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  ApiException _mapError(Object error, {required String fallback}) {
    if (error is FirebaseException) {
      return ApiException(message: error.message ?? fallback);
    }
    return ApiException(message: fallback);
  }

  /// Deterministic FNV-1a hash so the same UID maps to the same int id,
  /// matching the mapping used in `auth_provider.dart`.
  int _stableNumericId(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
