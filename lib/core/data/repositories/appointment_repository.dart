import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';

class AppointmentRepository {
  final ApiClient api;

  AppointmentRepository(this.api);

  Future<List<AppointmentModel>> getAppointments() async {
    try {
      final res = await api.dio.get('/appointments');

      dynamic raw = res.data;

      if (raw is Map) {
        raw = raw['appointments'] ??
            raw['items'] ??
            raw['data'] ??
            raw['results'] ??
            [];
      }

      if (raw is! List) return [];

      return raw
          .whereType<Map>()
          .map((e) => AppointmentModel.fromJson(Map<String, dynamic>.from(e)))
          .where((a) => a.id.trim().isNotEmpty)
          .toList();
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<AppointmentModel?> updateAppointmentStatus({
    required String appointmentId,
    required String status,
  }) async {
    try {
      final res = await api.dio.patch(
        '/appointments/$appointmentId/status',
        data: {
          'status': status,
        },
      );

      if (res.data is Map<String, dynamic>) {
        return AppointmentModel.fromJson(
          Map<String, dynamic>.from(res.data),
        );
      }

      return null;
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<void> cancelAppointment(String appointmentId) async {
    await updateAppointmentStatus(
      appointmentId: appointmentId,
      status: 'cancelled',
    );
  }

  Future<AppointmentModel?> createAppointment({
    required String doctorId,
    required DateTime preferredDate,
    required String notes,
  }) async {
    try {
      final dateOnly =
          '${preferredDate.year.toString().padLeft(4, '0')}-'
          '${preferredDate.month.toString().padLeft(2, '0')}-'
          '${preferredDate.day.toString().padLeft(2, '0')}';

      final res = await api.dio.post('/appointments', data: {
        'doctorId': doctorId,

        // Backend DB column is VARCHAR(10), so send only YYYY-MM-DD.
        'preferredDate': dateOnly,

        // Keep selected time inside notes until backend supports a time field.
        'notes': notes,
      });

      if (res.data is Map<String, dynamic>) {
        return AppointmentModel.fromJson(
          Map<String, dynamic>.from(res.data),
        );
      }

      return null;
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }
}

class AppointmentModel {
  final String id;
  final String doctorId;
  final String doctorName;
  final String doctorType;
  final String doctorPhone;
  final String status;
  final DateTime? preferredDate;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppointmentModel({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.doctorType,
    required this.doctorPhone,
    required this.status,
    required this.preferredDate,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    final doctorRaw = json['doctor'];
    final doctor = doctorRaw is Map
        ? Map<String, dynamic>.from(doctorRaw)
        : <String, dynamic>{};

    return AppointmentModel(
      id: (json['id'] ??
              json['_id'] ??
              json['appointmentId'] ??
              json['appointment_id'] ??
              '')
          .toString(),
      doctorId: (json['doctorId'] ??
              json['doctor_id'] ??
              doctor['id'] ??
              doctor['_id'] ??
              '')
          .toString(),
      doctorName: (json['doctorName'] ??
              json['doctor_name'] ??
              doctor['name'] ??
              'Doctor')
          .toString(),
      doctorType: (json['doctorType'] ??
              json['doctor_type'] ??
              json['specialization'] ??
              doctor['specialization'] ??
              doctor['type'] ??
              'Mental Health Professional')
          .toString(),
      doctorPhone: (json['doctorPhone'] ??
              json['doctor_phone'] ??
              doctor['phone'] ??
              '')
          .toString(),
      status: (json['status'] ?? 'pending').toString(),
      preferredDate: _AppointmentParser.date(
        json['preferredDate'] ??
            json['preferred_date'] ??
            json['date'] ??
            json['appointmentDate'] ??
            json['appointment_date'],
      ),
      notes: (json['notes'] ?? json['note'] ?? '').toString(),
      createdAt: _AppointmentParser.date(
        json['createdAt'] ?? json['created_at'],
      ),
      updatedAt: _AppointmentParser.date(
        json['updatedAt'] ?? json['updated_at'],
      ),
    );
  }

  bool get isCancelled {
    final s = status.toLowerCase();
    return s == 'cancelled' || s == 'canceled';
  }

  bool get isPast {
    if (isCancelled) return false;

    if (preferredDate == null) return false;

    final now = DateTime.now();
    final local = preferredDate!.toLocal();

    final today = DateTime(now.year, now.month, now.day);
    final appointmentDay = DateTime(local.year, local.month, local.day);

    return appointmentDay.isBefore(today);
  }

  bool get isUpcoming {
    return !isCancelled && !isPast;
  }
}

class _AppointmentParser {
  static DateTime? date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}