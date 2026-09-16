import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';

class KnowledgeRepository {
  final ApiClient api;

  KnowledgeRepository(this.api);

  Future<List<KnowledgeItemModel>> getKnowledge() async {
    try {
      final res = await api.dio.get('/knowledge');

      dynamic raw = res.data;

      if (raw is Map) {
        raw = raw['knowledge'] ??
            raw['items'] ??
            raw['facts'] ??
            raw['data'] ??
            raw['results'] ??
            [];
      }

      if (raw is! List) return [];

      return raw
          .whereType<Map>()
          .map((e) => KnowledgeItemModel.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .where((item) => item.id.trim().isNotEmpty)
          .toList();
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<void> deleteKnowledgeItem(String id) async {
    try {
      await api.dio.delete('/knowledge/$id');
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<void> clearKnowledge() async {
    try {
      await api.dio.delete('/knowledge');
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }
}

class KnowledgeItemModel {
  final String id;
  final String title;
  final String value;
  final String category;

  KnowledgeItemModel({
    required this.id,
    required this.title,
    required this.value,
    required this.category,
  });

  factory KnowledgeItemModel.fromJson(Map<String, dynamic> json) {
    return KnowledgeItemModel(
      id: (json['id'] ??
              json['_id'] ??
              json['knowledgeId'] ??
              json['knowledge_id'] ??
              json['factId'] ??
              json['fact_id'] ??
              '')
          .toString(),
      title: (json['title'] ??
              json['key'] ??
              json['label'] ??
              json['name'] ??
              'Saved detail')
          .toString(),
      value: (json['value'] ??
              json['content'] ??
              json['fact'] ??
              json['text'] ??
              json['description'] ??
              '')
          .toString(),
      category: (json['category'] ?? json['type'] ?? 'Personal').toString(),
    );
  }

  bool get isClinical {
    final c = category.trim().toLowerCase();
    return c.contains('clinical') ||
        c.contains('medical') ||
        c.contains('medication') ||
        c.contains('symptom') ||
        c.contains('health');
  }
}