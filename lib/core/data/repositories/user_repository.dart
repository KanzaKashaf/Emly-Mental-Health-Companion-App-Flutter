import '../api/api_client.dart';
import '../api/models/user_model.dart';

class UserRepository {
  final ApiClient api;

  UserRepository(this.api);

  Future<UserModel> getMe() async {
    final res = await api.dio.get('/users/me');
    return UserModel.fromJson(res.data);
  }

  Future<UserModel> updateProfile(Map<String, dynamic> payload) async {
    final res = await api.dio.patch('/users/me', data: payload);
    return UserModel.fromJson(res.data);
  }
}
