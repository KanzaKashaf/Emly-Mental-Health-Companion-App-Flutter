class AuthResponse {
  final String accessToken;
  final String refreshToken;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final token = (json['token'] as Map?)?.cast<String, dynamic>();

    if (token == null) {
      throw Exception('AuthResponse: missing "token" in response');
    }

    final access = token['accessToken'];
    final refresh = token['refreshToken'];

    if (access is! String || refresh is! String) {
      throw Exception('AuthResponse: invalid token fields');
    }

    return AuthResponse(
      accessToken: access,
      refreshToken: refresh,
    );
  }
}
