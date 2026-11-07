import 'user_model.dart';

/// Authentication response model
class AuthResponseModel {

  AuthResponseModel({
    required this.user,
    required this.token,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) => AuthResponseModel(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      token: json['token'] as String,
    );
  final UserModel user;
  final String token;

  Map<String, dynamic> toJson() => {
      'user': user.toJson(),
      'token': token,
    };
}
