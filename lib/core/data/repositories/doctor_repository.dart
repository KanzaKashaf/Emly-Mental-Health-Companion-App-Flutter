import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';

class DoctorRepository {
  final ApiClient api;

  DoctorRepository(this.api);

  Future<List<DoctorModel>> getDoctors() async {
    try {
      final res = await api.dio.get('/doctors');

      dynamic raw = res.data;

      if (raw is Map) {
        raw = raw['doctors'] ??
            raw['items'] ??
            raw['data'] ??
            raw['results'] ??
            [];
      }

      if (raw is! List) return [];

      return raw
          .whereType<Map>()
          .map((e) => DoctorModel.fromJson(Map<String, dynamic>.from(e)))
          .where((doctor) => doctor.id.trim().isNotEmpty)
          .toList();
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }
}

class DoctorModel {
  final String id;
  final String name;
  final String specialty;
  final String phone;
  final String availability;
  final String imageUrl;

  DoctorModel({
    required this.id,
    required this.name,
    required this.specialty,
    required this.phone,
    required this.availability,
    required this.imageUrl,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: (json['id'] ??
              json['_id'] ??
              json['doctorId'] ??
              json['doctor_id'] ??
              '')
          .toString(),
      name: (json['name'] ??
              json['doctorName'] ??
              json['doctor_name'] ??
              'Doctor')
          .toString(),
      specialty: (json['specialty'] ??
              json['specialization'] ??
              json['doctorType'] ??
              json['doctor_type'] ??
              'Mental Health Professional')
          .toString(),
      phone: (json['phone'] ??
              json['phoneNumber'] ??
              json['phone_number'] ??
              json['contact'] ??
              '')
          .toString(),
      availability: (json['availability'] ??
              json['availableText'] ??
              json['available_text'] ??
              'Availability not specified')
          .toString(),
      imageUrl: (json['imageUrl'] ??
              json['image_url'] ??
              json['profileImageUrl'] ??
              json['profile_image_url'] ??
              '')
          .toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'specialty': specialty,
      'phone': phone,
      'availability': availability,
      'imageUrl': imageUrl,
    };
  }
}