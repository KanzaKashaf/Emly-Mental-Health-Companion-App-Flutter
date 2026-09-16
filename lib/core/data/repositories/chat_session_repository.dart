import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';

class ChatSessionRepository {
  final ApiClient api;

  ChatSessionRepository(this.api);

  Future<ChatSessionSummary?> getLatestSession() async {
    try {
      final res = await api.dio.get(
        '/chat/sessions',
        queryParameters: {
          'page': 1,
          'limit': 20,
        },
      );

      final sessions = _extractSessions(res.data)
          .map((e) => ChatSessionSummary.fromJson(e))
          .where((e) => e.id.isNotEmpty)
          .toList();

      if (sessions.isEmpty) return null;

      // Prefer active/incomplete session first.
      final activeSessions = sessions.where((s) => s.isIncomplete).toList();

      if (activeSessions.isNotEmpty) {
        activeSessions.sort((a, b) {
          final ad = a.updatedAt ?? a.createdAt ?? DateTime(1970);
          final bd = b.updatedAt ?? b.createdAt ?? DateTime(1970);
          return bd.compareTo(ad);
        });

        return activeSessions.first;
      }

      // Otherwise return most recent session.
      sessions.sort((a, b) {
        final ad = a.updatedAt ?? a.createdAt ?? DateTime(1970);
        final bd = b.updatedAt ?? b.createdAt ?? DateTime(1970);
        return bd.compareTo(ad);
      });

      return sessions.first;
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<ChatSessionStatus> getSessionStatus(String sessionId) async {
    try {
      final res = await api.dio.get('/chat/sessions/$sessionId/status');

      return ChatSessionStatus.fromJson(
        Map<String, dynamic>.from(res.data),
        fallbackSessionId: sessionId,
      );
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  List<Map<String, dynamic>> _extractSessions(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);

      final rawList = map['sessions'] ?? map['items'] ?? map['data'] ?? map['results'];

      if (rawList is List) {
        return rawList
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    return [];
  }

  Future<ChatSessionDetail> getSessionDetail(String sessionId) async {
    try {
      final res = await api.dio.get('/chat/sessions/$sessionId');

      return ChatSessionDetail.fromJson(
        Map<String, dynamic>.from(res.data),
        fallbackSessionId: sessionId,
      );
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<ChatSendResponse> sendMessage({
    required String? sessionId,
    required String message,
    String inputMode = 'text',
  }) async {
    try {
      final res = await api.dio.post('/chat/message', data: {
        'sessionId': sessionId,
        'message': message,
        'inputMode': inputMode,
      });

      return ChatSendResponse.fromJson(
        Map<String, dynamic>.from(res.data),
      );
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }
}

class ChatSessionSummary {
  final String id;
  final String title;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChatSessionSummary({
    required this.id,
    required this.title,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  bool get isIncomplete {
    final s = (status ?? '').toLowerCase().trim();

    return s == 'active' ||
        s == 'in_progress' ||
        s == 'in-progress' ||
        s == 'incomplete' ||
        s == 'open' ||
        s == 'started';
  }

  factory ChatSessionSummary.fromJson(Map<String, dynamic> json) {
    return ChatSessionSummary(
      id: (json['id'] ?? json['sessionId'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? 'Previous session').toString(),
      status: json['status']?.toString(),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(
        json['updatedAt'] ??
            json['lastMessageAt'] ??
            json['lastActivityAt'] ??
            json['modifiedAt'],
      ),
    );
  }
}

class ChatSessionStatus {
  final String sessionId;
  final bool canResume;
  final bool isExpired;
  final bool hasReport;
  final bool showOptions;
  final bool forceNewSession;
  final int? gapDays;
  final String? message;

  ChatSessionStatus({
    required this.sessionId,
    required this.canResume,
    required this.isExpired,
    required this.hasReport,
    required this.showOptions,
    required this.forceNewSession,
    this.gapDays,
    this.message,
  });

  bool get shouldShowWelcomeBack {
    return canResume || showOptions || isExpired || forceNewSession;
  }

  factory ChatSessionStatus.fromJson(
    Map<String, dynamic> json, {
    required String fallbackSessionId,
  }) {
    final gapRaw = json['gapDays'] ??
        json['daysSinceLastMessage'] ??
        json['daysSinceStarted'] ??
        json['inactiveDays'];

    final forceNewRaw = json['forceNewSession'] ??
        json['force_new_session'] ??
        json['mustStartNew'];

    final showOptionsRaw = json['showOptions'] ??
        json['show_options'] ??
        json['shouldShowOptions'];

    final expiredRaw = json['isExpired'] ??
        json['expired'] ??
        json['sessionExpired'] ??
        forceNewRaw;

    final canResumeRaw = json['canResume'] ??
        json['canContinue'] ??
        json['resumable'];

    final hasReportRaw = json['hasReport'] ??
        json['reportAvailable'] ??
        json['canViewReport'];

    return ChatSessionStatus(
      sessionId: (json['sessionId'] ?? json['id'] ?? fallbackSessionId).toString(),
      canResume: canResumeRaw == true,
      isExpired: expiredRaw == true,
      hasReport: hasReportRaw == true,
      showOptions: showOptionsRaw == true,
      forceNewSession: forceNewRaw == true,
      gapDays: _asNullableInt(gapRaw),
      message: json['message']?.toString() ??
          json['gapDescription']?.toString() ??
          json['description']?.toString(),
    );
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class ChatSessionDetail {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<BackendChatMessage> messages;

  ChatSessionDetail({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });

  factory ChatSessionDetail.fromJson(
    Map<String, dynamic> json, {
    required String fallbackSessionId,
  }) {
    final rawMessages =
        json['messages'] ?? json['conversation'] ?? json['chatMessages'] ?? [];

    return ChatSessionDetail(
      id: (json['id'] ?? json['sessionId'] ?? fallbackSessionId).toString(),
      title: (json['title'] ?? 'Previous session').toString(),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      messages: rawMessages is List
          ? rawMessages
              .whereType<Map>()
              .map((e) => BackendChatMessage.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : [],
    );
  }
}

class BackendChatMessage {
  final String text;
  final bool fromUser;
  final DateTime createdAt;
  final Map<String, dynamic> meta;

  BackendChatMessage({
    required this.text,
    required this.fromUser,
    required this.createdAt,
    required this.meta,
  });

  factory BackendChatMessage.fromJson(Map<String, dynamic> json) {
    final role = (json['role'] ??
            json['sender'] ??
            json['type'] ??
            json['from'] ??
            '')
        .toString()
        .toLowerCase();

    final fromUser = json['fromUser'] == true ||
        json['isUser'] == true ||
        role == 'user' ||
        role == 'human';

    return BackendChatMessage(
      text: (json['text'] ??
              json['content'] ??
              json['message'] ??
              json['body'] ??
              '')
          .toString(),
      fromUser: fromUser,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      meta: json['meta'] is Map
          ? Map<String, dynamic>.from(json['meta'])
          : <String, dynamic>{},
    );
  }
}

class ChatSendResponse {
  final String sessionId;
  final String sessionTitle;
  final DateTime sessionCreatedAt;
  final BackendChatMessage assistantMessage;

  ChatSendResponse({
    required this.sessionId,
    required this.sessionTitle,
    required this.sessionCreatedAt,
    required this.assistantMessage,
  });

  factory ChatSendResponse.fromJson(Map<String, dynamic> json) {
    final session = json['session'] is Map
        ? Map<String, dynamic>.from(json['session'])
        : <String, dynamic>{};

    final assistant = json['assistantMessage'] is Map
        ? Map<String, dynamic>.from(json['assistantMessage'])
        : <String, dynamic>{};

    return ChatSendResponse(
      sessionId: (session['id'] ?? session['sessionId'] ?? '').toString(),
      sessionTitle: (session['title'] ?? 'New session').toString(),
      sessionCreatedAt: _parseDate(session['createdAt']) ?? DateTime.now(),
      assistantMessage: BackendChatMessage.fromJson(assistant),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}