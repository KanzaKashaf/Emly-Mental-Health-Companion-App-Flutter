import 'package:dio/dio.dart';
import './api_config.dart';
import './token_store.dart';
import './api_error.dart';

class ApiClient {
  final Dio dio;
  final TokenStore tokenStore;

  ApiClient({required this.tokenStore})
      : dio = Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: ApiConfig.connectTimeout,
            receiveTimeout: ApiConfig.receiveTimeout,
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final skipAuth = options.extra['skipAuth'] == true;

          if (!skipAuth) {
            final token = await tokenStore.getAccessToken();

            if (token != null && !options.headers.containsKey('Authorization')) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          // ---------- 401 refresh flow ----------
          final status = error.response?.statusCode;
          final isUnauthorized = status == 401;

          // Avoid refresh loop: do not refresh on refresh endpoint itself
          final isRefreshCall = error.requestOptions.path.contains('/auth/refresh');

          if (isUnauthorized && !isRefreshCall) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              try {
                // Retry the original request (with new token automatically added by onRequest)
                final retryResponse = await dio.request(
                  error.requestOptions.path,
                  data: error.requestOptions.data,
                  queryParameters: error.requestOptions.queryParameters,
                  options: Options(
                    method: error.requestOptions.method,
                    headers: Map<String, dynamic>.from(error.requestOptions.headers),
                    responseType: error.requestOptions.responseType,
                    contentType: error.requestOptions.contentType,
                    receiveTimeout: error.requestOptions.receiveTimeout,
                    sendTimeout: error.requestOptions.sendTimeout,
                    followRedirects: error.requestOptions.followRedirects,
                    validateStatus: error.requestOptions.validateStatus,
                  ),
                );

                return handler.resolve(retryResponse);
              } catch (e) {
                // If retry fails, fall through and wrap as ApiError below
              }
            }

            // Refresh failed
            await tokenStore.clear();
          }

          // ---------- Always wrap to ApiError ----------
          if (error is DioException) {
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                type: error.type,
                error: ApiError.fromDio(error),
              ),
            );
          }

          // Fallback
          handler.next(error);
        },
      ),
    );
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await tokenStore.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(
          headers: {
            'Authorization': null,
            'Content-Type': 'application/json',
          },
          extra: {
            'skipAuth': true,
          },
        ),
      );

      final token = (response.data['token'] as Map?)?.cast<String, dynamic>();
      if (token == null) return false;

      final access = token['accessToken'];
      final refresh = token['refreshToken'];

      if (access is! String || refresh is! String) return false;

      await tokenStore.saveTokens(
        accessToken: access,
        refreshToken: refresh,
      );

      return true;
    } catch (_) {
      return false;
    }
  }
}
