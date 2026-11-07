import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackModel {
  const FeedbackModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.category,
    required this.message,
    required this.status,
    required this.adminResponse,
    required this.createdAt,
  });

  factory FeedbackModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final timestamp = data['createdAt'];
    return FeedbackModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      category: data['category'] as String? ?? 'Question',
      message: data['message'] as String? ?? '',
      status: data['status'] as String? ?? 'Pending',
      adminResponse: data['adminResponse'] as String? ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }

  final String id;
  final String userId;
  final String userName;
  final String category;
  final String message;
  final String status;
  final String adminResponse;
  final DateTime createdAt;
}
