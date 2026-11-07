import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/feedback_model.dart';

class FeedbackRepository {
  FeedbackRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Sign in before sending feedback.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _feedback =>
      _firestore.collection('feedback');

  Stream<List<FeedbackModel>> myFeedbackStream() {
    final uid = _uid;
    return _feedback.where('userId', isEqualTo: uid).snapshots().map(_sort);
  }

  Stream<List<FeedbackModel>> allFeedbackStream() =>
      _feedback.snapshots().map(_sort);

  List<FeedbackModel> _sort(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final entries = snapshot.docs.map(FeedbackModel.fromFirestore).toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<void> submit({
    required String category,
    required String message,
  }) async {
    final user = _auth.currentUser;
    final uid = _uid;
    final trimmedMessage = message.trim();
    if (!const {'Bug', 'Feature', 'Question'}.contains(category)) {
      throw ArgumentError('Choose a feedback category.');
    }
    if (trimmedMessage.isEmpty || trimmedMessage.length > 4000) {
      throw ArgumentError('Feedback must be between 1 and 4000 characters.');
    }

    await _feedback.add({
      'userId': uid,
      'userName': (user?.displayName?.trim().isNotEmpty ?? false)
          ? user!.displayName!.trim()
          : (user?.email ?? 'ShopWise user'),
      'category': category,
      'message': trimmedMessage,
      'status': 'Pending',
      'adminResponse': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resolve({
    required String feedbackId,
    required String response,
  }) async {
    await _feedback.doc(feedbackId).update({
      'adminResponse': response.trim(),
      'status': 'Resolved',
    });
  }

  Future<void> markResolved(String feedbackId) async {
    await _feedback.doc(feedbackId).update({'status': 'Resolved'});
  }
}
