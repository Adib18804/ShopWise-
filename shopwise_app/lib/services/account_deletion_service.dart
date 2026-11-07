import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Deletes the signed-in user's app data before deleting their Firebase Auth
/// account. Keep [shopCollections] in sync with every subcollection the app
/// creates beneath `shops/{uid}`.
class AccountDeletionService {
  AccountDeletionService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const shopCollections = <String>[
    'products',
    'batches',
    'categories',
    'invoices',
    'customers',
  ];

  Future<void> deleteCurrentAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in account was found.');
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw StateError(
        'This account cannot be reauthenticated with email and password. '
        'Sign in again, then retry account deletion.',
      );
    }

    // Firebase requires a recent sign-in for deleting an account. Reauthenticate
    // before removing any data, so a stale session cannot partially erase it.
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);

    final uid = user.uid;
    final shopRef = _firestore.collection('shops').doc(uid);

    // Flutter's Firestore SDK cannot enumerate arbitrary subcollection names.
    // Delete all collections currently created by this app, then remove the
    // parent documents. Chunk writes to remain under Firestore's 500-write cap.
    for (final name in shopCollections) {
      await _deleteQuery(shopRef.collection(name));
    }
    await _deleteQuery(
      _firestore.collection('feedback').where('userId', isEqualTo: uid),
    );

    await shopRef.delete();
    await _firestore.collection('users').doc(uid).delete();

    // Delete Auth last: if a Firestore operation fails, the user can still sign
    // in and retry cleanup instead of being stranded with orphaned records.
    await user.delete();
  }

  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    const pageSize = 400;
    while (true) {
      final page = await query.limit(pageSize).get();
      if (page.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final document in page.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();

      if (page.docs.length < pageSize) return;
    }
  }
}
