import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../api/api_error.dart';
import '../api/models/auth_response.dart';

class AuthRepository {
  final ApiClient api;

  AuthRepository(this.api);

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await api.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final auth = AuthResponse.fromJson(res.data);

      await api.tokenStore.saveTokens(
        accessToken: auth.accessToken,
        refreshToken: auth.refreshToken,
      );

      return auth;
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<AuthResponse> loginWithGoogle({
    required String idToken,
  }) async {
    try {
      final res = await api.dio.post('/auth/oauth/google', data: {
        'idToken': idToken,
      });

      final auth = AuthResponse.fromJson(res.data);

      await api.tokenStore.saveTokens(
        accessToken: auth.accessToken,
        refreshToken: auth.refreshToken,
      );

      return auth;
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<AuthResponse> signup({
    required String email,
    required String password,
    required String name,
    required String gender,
    required String dateOfBirth,
    String profileImage = '',
  }) async {
    try {
      final res = await api.dio.post('/auth/signup', data: {
        'name': name,
        'email': email,
        'password': password,
        'gender': gender,
        'dateOfBirth': dateOfBirth,

        // Backend schema requires this field.
        // Actual image upload is still handled separately by /users/me/avatar.
        'profileImage': profileImage,
      });

      final auth = AuthResponse.fromJson(res.data);

      await api.tokenStore.saveTokens(
        accessToken: auth.accessToken,
        refreshToken: auth.refreshToken,
      );

      return auth;
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<void> sendOtp({
    required String email,
    required String purpose,
  }) async {
    try {
      await api.dio.post('/auth/send-otp', data: {
        'email': email,
        'purpose': purpose,
      });
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<OtpVerifyResponse> verifyOtp({
    required String email,
    required String code,
    required String purpose,
  }) async {
    try {
      final res = await api.dio.post('/auth/verify-otp', data: {
        'email': email,
        'code': code,
        'purpose': purpose,
      });

      return OtpVerifyResponse.fromJson(
        Map<String, dynamic>.from(res.data),
      );
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<ResetPasswordResponse> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      final res = await api.dio.post('/auth/reset-password', data: {
        'resetToken': resetToken,
        'newPassword': newPassword,
      });

      return ResetPasswordResponse.fromJson(
        Map<String, dynamic>.from(res.data),
      );
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<void> logout() async {
    final refreshToken = await api.tokenStore.getRefreshToken();

    try {
      if (refreshToken != null && refreshToken.trim().isNotEmpty) {
        await api.dio.post('/auth/logout', data: {
          'refreshToken': refreshToken,
        });
      }
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    } finally {
      await api.tokenStore.clear();
    }
  }
}

class OtpVerifyResponse {
  final bool verified;
  final String message;
  final String? resetToken;

  OtpVerifyResponse({
    required this.verified,
    required this.message,
    this.resetToken,
  });

  factory OtpVerifyResponse.fromJson(Map<String, dynamic> json) {
    return OtpVerifyResponse(
      verified: json['verified'] == true,
      message: (json['message'] ?? '').toString(),
      resetToken: json['resetToken']?.toString(),
    );
  }
}

class ResetPasswordResponse {
  final String message;

  ResetPasswordResponse({
    required this.message,
  });

  factory ResetPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ResetPasswordResponse(
      message: (json['message'] ?? 'Password updated successfully').toString(),
    );
  }
}