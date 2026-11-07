import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../models/user_model.dart';

/// Authentication state consumed by the existing Flutter screens.
///
/// [shopId] is the Firestore document id of the shop owned by the signed-in
/// user. In this prototype the shops collection is keyed by the owner's Firebase
/// UID (`shops/{uid}`), so [shopId] always equals the current user's UID once
/// authenticated. Downstream providers (products, sales, reports) read it to
/// scope every Firestore query to the user's own shop.
class AuthState {

  AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
    this.shopId,
  });
  final UserModel? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  final String? shopId;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    String? shopId,
    bool clearShopId = false,
  }) => AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      // Matches the original behaviour: omitting [error] clears it. Callers
      // that want to keep the current error pass it through explicitly.
      error: error,
      shopId: clearShopId ? null : (shopId ?? this.shopId),
    );

  AuthState clearError() => AuthState(
        user: user,
        isLoading: isLoading,
        isAuthenticated: isAuthenticated,
        shopId: shopId,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier([Object? _]) : super(AuthState());

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Restores the session on app start (called by the splash screen).
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        state = AuthState();
        return;
      }
      final user = await _loadUser(firebaseUser);
      state = AuthState(
        user: user,
        isAuthenticated: true,
        shopId: firebaseUser.uid,
      );
    } catch (error) {
      state = AuthState(
        error: _errorMessage(error),
      );
    }
  }

  /// Creates a new auth account and provisions the `users` Firestore document.
  ///
  /// The shop document is created only after the owner completes Shop Setup.
  Future<bool> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    String preferredLanguage = 'bn',
  }) async {
    state = state.copyWith(isLoading: true);
    User? createdUser;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw ApiException(
            message: 'অ্যাকাউন্ট তৈরি করা যায়নি। আবার চেষ্টা করুন।',);
      }
      createdUser = firebaseUser;
      await firebaseUser.updateDisplayName(name.trim());

      final now = DateTime.now().toUtc();
      final profile = <String, dynamic>{
        'uid': firebaseUser.uid,
        'name': name.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'preferred_language': preferredLanguage,
        'has_shop': false,
        'created_at': Timestamp.fromDate(now),
        'updated_at': Timestamp.fromDate(now),
      };
      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(profile);

      state = AuthState(
        user: _toUserModel(firebaseUser, profile, hasShop: false),
        isAuthenticated: true,
        shopId: firebaseUser.uid,
      );
      return true;
    } catch (error) {
      // Avoid leaving an Auth-only account if profile provisioning fails.
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {
          // The primary Firestore/Auth error is more useful to the user.
        }
      }
      state = AuthState(
        error: _errorMessage(error),
      );
      return false;
    }
  }

  /// Signs the user in with email + password and loads their profile.
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final email = identifier.trim();
      if (!email.contains('@')) {
        throw ApiException(message: 'ইমেইল ঠিকানা দিয়ে লগইন করুন।');
      }
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw ApiException(message: 'লগইন করা যায়নি। আবার চেষ্টা করুন।');
      }
      final user = await _loadUser(firebaseUser);
      state = AuthState(
        user: user,
        isAuthenticated: true,
        shopId: firebaseUser.uid,
      );
      return true;
    } catch (error) {
      state = AuthState(error: _errorMessage(error));
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await _auth.signOut();
    } finally {
      state = AuthState();
    }
  }

  /// Reloads the current user + shop status. Called by the shop setup screen
  /// after a shop is created so `hasShop` reflects the new state.
  Future<void> refreshUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      state = AuthState();
      return;
    }
    try {
      final user = await _loadUser(firebaseUser);
      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        shopId: firebaseUser.uid,
      );
    } catch (error) {
      state = state.copyWith(error: _errorMessage(error));
    }
  }

  void clearError() {
    state = state.clearError();
  }

  /// Loads the user profile + shop status from Firestore.
  ///
  /// `hasShop` is true only when setup is complete and `shop_type` is valid.
  /// Incomplete records and legacy shops without a type return to setup.
  Future<UserModel> _loadUser(User firebaseUser) async {
    final profileSnapshot =
        await _firestore.collection('users').doc(firebaseUser.uid).get();
    final profile = profileSnapshot.data() ?? <String, dynamic>{};

    final shopSnapshot =
        await _firestore.collection('shops').doc(firebaseUser.uid).get();
    final shopData = shopSnapshot.data();
    const supportedShopTypes = {
      'general',
      'pharmacy',
      'stationery',
      'library',
    };
    final shopType = shopData?['shop_type'];
    final hasShop = shopSnapshot.exists &&
        shopData?['setup_complete'] == true &&
        shopType is String &&
        supportedShopTypes.contains(shopType);

    return _toUserModel(
      firebaseUser,
      profile,
      hasShop: hasShop,
      shopType: shopType is String ? shopType : null,
    );
  }

  UserModel _toUserModel(
    User firebaseUser,
    Map<String, dynamic> profile, {
    required bool hasShop,
    String? shopType,
  }) {
    final createdAt = profile['created_at'];
    final updatedAt = profile['updated_at'];
    final createdDate = createdAt is Timestamp
        ? createdAt.toDate()
        : DateTime.tryParse(createdAt?.toString() ?? '') ?? DateTime.now();
    final updatedDate = updatedAt is Timestamp
        ? updatedAt.toDate()
        : DateTime.tryParse(updatedAt?.toString() ?? '') ?? createdDate;

    return UserModel(
      // Existing UI model uses an integer ID. Keep a deterministic local mapping
      // while the Firebase UID remains the actual identity used by Firestore
      // rules and queries (see [AuthState.shopId]).
      id: _stableNumericId(firebaseUser.uid),
      name: (profile['name'] as String?) ?? firebaseUser.displayName ?? '',
      phone: (profile['phone'] as String?) ?? firebaseUser.phoneNumber ?? '',
      email: (profile['email'] as String?) ?? firebaseUser.email ?? '',
      preferredLanguage: (profile['preferred_language'] as String?) ?? 'bn',
      hasShop: hasShop,
      shopId: hasShop ? _stableNumericId(firebaseUser.uid) : null,
      shopType: shopType,
      createdAt: createdDate,
      updatedAt: updatedDate,
    );
  }

  /// Deterministic FNV-1a hash so the same UID always maps to the same int id.
  int _stableNumericId(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  String _errorMessage(Object error) {
    if (error is ApiException) return error.message;
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'এই ইমেইল দিয়ে ইতিমধ্যে অ্যাকাউন্ট আছে।';
        case 'invalid-email':
          return 'সঠিক ইমেইল ঠিকানা লিখুন।';
        case 'weak-password':
          return 'আরও শক্তিশালী পাসওয়ার্ড ব্যবহার করুন।';
        case 'user-not-found':
        case 'invalid-credential':
        case 'wrong-password':
          return 'ইমেইল বা পাসওয়ার্ড সঠিক নয়।';
        case 'network-request-failed':
          return 'নেটওয়ার্ক সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।';
        case 'too-many-requests':
          return 'অনেকবার চেষ্টা হয়েছে। কিছুক্ষণ পরে আবার চেষ্টা করুন।';
        default:
          return error.message ?? 'প্রমাণীকরণ সম্পন্ন করা যায়নি।';
      }
    }
    if (error is FirebaseException) {
      return error.message ?? 'তথ্য সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।';
    }
    return 'অপ্রত্যাশিত সমস্যা হয়েছে। আবার চেষ্টা করুন.';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
