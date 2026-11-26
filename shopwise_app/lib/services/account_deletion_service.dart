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

  Future<void> deleteCurrentAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in account was found.');
    }

    final providerIds =
        user.providerData.map((provider) => provider.providerId);

    // Require a fresh sign-in before touching any Firestore data. Google users
    // don't have an app password, so reauthenticate with their linked provider.
    if (providerIds.contains('google.com')) {
      await user.reauthenticateWithProvider(GoogleAuthProvider());
    } else if (providerIds.contains(EmailAuthProvider.PROVIDER_ID)) {
      final email = user.email;
      if (email == null ||
          email.isEmpty ||
          password == null ||
          password.isEmpty) {
        throw StateError(
          'A valid email and current password are required to delete this account.',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } else {
      throw StateError(
        'This sign-in method is not supported for account deletion. '
        'Contact support for help.',
      );
    }

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
