import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';

class SubscriptionRepository {
  final ApiClient api;

  SubscriptionRepository(this.api);

  Future<SubscriptionStatus> getStatus() async {
    try {
      final res = await api.dio.get('/subscription/status');

      return SubscriptionStatus.fromJson(
        Map<String, dynamic>.from(res.data),
      );
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<SubscriptionStatus> activatePremium() async {
    try {
      await api.dio.post(
        '/subscription/activate',
        data: {
          'tier': 'premium',
        },
      );

      // Backend returns only a string, so fetch updated status after success.
      return await getStatus();
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<SubscriptionStatus> deactivatePremium() async {
    try {
      await api.dio.post('/subscription/deactivate');

      // Backend returns only a string, so fetch updated status after success.
      return await getStatus();
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }
}

class SubscriptionStatus {
  final String tier;
  final int sessionsUsed;
  final String? sessionsAllowed;
  final String? expiresAt;
  final bool canCreateSession;

  SubscriptionStatus({
    required this.tier,
    required this.sessionsUsed,
    required this.sessionsAllowed,
    required this.expiresAt,
    required this.canCreateSession,
  });

  bool get isPremium => tier.toLowerCase() == 'premium';

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final tierValue =
        (json['tier'] ?? json['subscriptionTier'] ?? 'free').toString();

    return SubscriptionStatus(
      tier: tierValue,
      sessionsUsed: _asInt(json['sessionsUsed']),
      sessionsAllowed: json['sessionsAllowed']?.toString(),
      expiresAt: json['expiresAt']?.toString(),
      canCreateSession: json['canCreateSession'] == true ||
          tierValue.toLowerCase() == 'premium',
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? 0).toString()) ?? 0;
  }
}