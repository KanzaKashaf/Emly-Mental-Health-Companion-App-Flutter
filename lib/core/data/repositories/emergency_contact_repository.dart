import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';

class EmergencyContactRepository {
  final ApiClient api;

  EmergencyContactRepository(this.api);

  Future<List<EmergencyContactModel>> getContacts() async {
    try {
      final res = await api.dio.get('/emergency-contacts');

      dynamic raw = res.data;

      if (raw is Map) {
        raw = raw['contacts'] ??
            raw['emergencyContacts'] ??
            raw['items'] ??
            raw['data'] ??
            raw['results'] ??
            [];
      }

      if (raw is! List) return [];

      return raw
          .whereType<Map>()
          .map((e) => EmergencyContactModel.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .where((c) => c.id.trim().isNotEmpty)
          .toList();
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<EmergencyContactModel?> addContact({
    required String name,
    required String phone,
    required String relation,
  }) async {
    try {
      final res = await api.dio.post('/emergency-contacts', data: {
        'name': name,
        'phone': phone,
        'relation': relation,
      });

      if (res.data is Map<String, dynamic>) {
        return EmergencyContactModel.fromJson(
          Map<String, dynamic>.from(res.data),
        );
      }

      return null;
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<void> deleteContact(String contactId) async {
    try {
      await api.dio.delete('/emergency-contacts/$contactId');
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }
}

class EmergencyContactModel {
  final String id;
  final String name;
  final String relation;
  final String phone;

  EmergencyContactModel({
    required this.id,
    required this.name,
    required this.relation,
    required this.phone,
  });

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return EmergencyContactModel(
      id: (json['id'] ??
              json['_id'] ??
              json['contactId'] ??
              json['contact_id'] ??
              '')
          .toString(),
      name: (json['name'] ?? '').toString(),
      relation: (json['relation'] ?? json['relationship'] ?? '').toString(),
      phone: (json['phone'] ??
              json['phoneNumber'] ??
              json['phone_number'] ??
              '')
          .toString(),
    );
  }
}