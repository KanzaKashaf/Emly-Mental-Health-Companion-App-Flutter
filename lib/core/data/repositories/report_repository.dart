import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';

class ReportRepository {
  final ApiClient api;

  ReportRepository(this.api);

  Future<List<ReportListItem>> getReports() async {
    try {
      final sessionsRes = await api.dio.get(
        '/chat/sessions',
        queryParameters: {
          'page': 1,
          'limit': 50,
        },
      );

      final sessions = _parseSessions(sessionsRes.data);

      final reports = <ReportListItem>[];

      for (final session in sessions) {
        final currentStatus = await _resolveReportSessionStatus(session);

        // Only completed sessions should be considered for report list.
        // If status is unknown, still try report endpoint because backend may not
        // return status perfectly but report endpoint is the real source.
        if (currentStatus != 'completed' && currentStatus != 'unknown') {
          continue;
        }

        try {
          final reportRes = await api.dio.get(
            '/chat/sessions/${session.id}/report',
          );

          final reportJson = reportRes.data is Map<String, dynamic>
              ? Map<String, dynamic>.from(reportRes.data)
              : <String, dynamic>{};

          if (!_ReportParser.hasRealReportData(reportJson)) {
            continue;
          }

          reports.add(
            ReportListItem.fromReportAndSession(
              session: session,
              report: reportJson,
            ),
          );
        } on DioException catch (e) {
          final status = e.response?.statusCode;

          if (status == 404 || status == 400 || status == 422) {
            continue;
          }

          throw (e.error is ApiError)
              ? (e.error as ApiError)
              : ApiError.fromDio(e);
        }
      }

      reports.sort((a, b) {
        final ad = a.completedAt;
        final bd = b.completedAt;

        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;

        return bd.compareTo(ad);
      });

      return reports;
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<ReportDetail> getReportBySessionId(String sessionId) async {
    try {
      final res = await api.dio.get('/chat/sessions/$sessionId/report');

      final data = res.data is Map<String, dynamic>
          ? Map<String, dynamic>.from(res.data)
          : <String, dynamic>{};

      return ReportDetail.fromJson(data);
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<String> _resolveReportSessionStatus(_ReportSession session) async {
    final localStatus = _normalizeSessionStatus(session.status);

    // If /chat/sessions already clearly says completed, trust it.
    if (localStatus == 'completed') return 'completed';

    try {
      final res = await api.dio.get('/chat/sessions/${session.id}/status');

      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data)
          : <String, dynamic>{};

      final directStatus =
          _normalizeSessionStatus(data['computedStatus']) ??
          _normalizeSessionStatus(data['computed_status']) ??
          _normalizeSessionStatus(data['status']) ??
          _normalizeSessionStatus(data['sessionStatus']) ??
          _normalizeSessionStatus(data['session_status']);

      // Completed must win over expired.
      if (directStatus == 'completed' ||
          _ReportParser.truthy(data['isCompleted']) ||
          _ReportParser.truthy(data['is_completed']) ||
          _ReportParser.truthy(data['completed']) ||
          _ReportParser.truthy(data['reportReady']) ||
          _ReportParser.truthy(data['report_ready']) ||
          _ReportParser.truthy(data['summaryReady']) ||
          _ReportParser.truthy(data['summary_ready']) ||
          _ReportParser.truthy(data['screeningSummaryReady']) ||
          _ReportParser.truthy(data['screening_summary_ready']) ||
          _ReportParser.truthy(data['hasReport']) ||
          _ReportParser.truthy(data['has_report']) ||
          _ReportParser.truthy(data['reportAvailable']) ||
          _ReportParser.truthy(data['report_available'])) {
        return 'completed';
      }

      if (directStatus == 'expired' ||
          _ReportParser.truthy(data['forceNewSession']) ||
          _ReportParser.truthy(data['force_new_session']) ||
          _ReportParser.truthy(data['isExpired']) ||
          _ReportParser.truthy(data['is_expired']) ||
          _ReportParser.truthy(data['expired']) ||
          _ReportParser.truthy(data['sessionExpired']) ||
          _ReportParser.truthy(data['session_expired'])) {
        return 'expired';
      }

      if (directStatus == 'active' ||
          _ReportParser.truthy(data['showOptions']) ||
          _ReportParser.truthy(data['show_options']) ||
          _ReportParser.truthy(data['shouldShowWelcomeBack']) ||
          _ReportParser.truthy(data['should_show_welcome_back']) ||
          _ReportParser.truthy(data['isIncomplete']) ||
          _ReportParser.truthy(data['is_incomplete'])) {
        return 'active';
      }

      return localStatus ?? 'unknown';
    } catch (_) {
      return localStatus ?? 'unknown';
    }
  }

  String? _normalizeSessionStatus(dynamic value) {
    final s = value?.toString().toLowerCase().trim() ?? '';

    if (s == 'completed' ||
        s == 'complete' ||
        s == 'closed' ||
        s == 'done' ||
        s == 'finished') {
      return 'completed';
    }

    if (s == 'expired' || s == 'session_expired') {
      return 'expired';
    }

    if (s == 'active' ||
        s == 'incomplete' ||
        s == 'ongoing' ||
        s == 'in_progress' ||
        s == 'in-progress' ||
        s == 'open' ||
        s == 'started') {
      return 'active';
    }

    return null;
  }

  List<_ReportSession> _parseSessions(dynamic data) {
    dynamic raw = data;

    if (data is Map) {
      raw = data['sessions'] ??
          data['items'] ??
          data['data'] ??
          data['results'] ??
          data['chatSessions'] ??
          [];
    }

    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((e) => _ReportSession.fromJson(Map<String, dynamic>.from(e)))
        .where((session) => session.id.trim().isNotEmpty)
        .toList();
  }
}

class _ReportSession {
  final String id;
  final String title;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  _ReportSession({
    required this.id,
    required this.title,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  factory _ReportSession.fromJson(Map<String, dynamic> json) {
    return _ReportSession(
      id: (json['id'] ??
              json['sessionId'] ??
              json['session_id'] ??
              json['_id'] ??
              '')
          .toString(),
      title: (json['title'] ??
              json['sessionTitle'] ??
              json['session_title'] ??
              json['summary'] ??
              json['firstMessage'] ??
              json['first_message'] ??
              'Session')
          .toString(),
      status: (json['status'] ??
              json['sessionStatus'] ??
              json['session_status'] ??
              json['computedStatus'] ??
              json['computed_status'] ??
              '')
          .toString()
          .toLowerCase()
          .trim(),
      createdAt: _ReportParser.date(
        json['createdAt'] ?? json['created_at'],
      ),
      updatedAt: _ReportParser.date(
        json['updatedAt'] ?? json['updated_at'],
      ),
      completedAt: _ReportParser.date(
        json['completedAt'] ??
            json['completed_at'] ??
            json['finishedAt'] ??
            json['finished_at'],
      ),
    );
  }
}

class ReportListItem {
  final String sessionId;
  final String sessionTitle;
  final String disorderName;
  final String outcome;
  final double confidence;
  final String severity;
  final DateTime? completedAt;
  final ReportDetail detail;

  ReportListItem({
    required this.sessionId,
    required this.sessionTitle,
    required this.disorderName,
    required this.outcome,
    required this.confidence,
    required this.severity,
    required this.completedAt,
    required this.detail,
  });

  factory ReportListItem.fromReportAndSession({
    required _ReportSession session,
    required Map<String, dynamic> report,
  }) {
    final detail = ReportDetail.fromJson(report);

    return ReportListItem(
      sessionId: session.id,
      sessionTitle: session.title,
      disorderName: detail.disorderName,
      outcome: detail.outcome,
      confidence: detail.confidence,
      severity: detail.severity,
      completedAt: _ReportParser.date(
        report['completedAt'] ??
            report['completed_at'] ??
            report['generatedAt'] ??
            report['generated_at'] ??
            report['createdAt'] ??
            report['created_at'],
      ) ??
      session.completedAt ??
      session.updatedAt ??
      session.createdAt,
      detail: detail,
    );
  }
}

class ReportDetail {
  final String activeDisorder;
  final String disorderName;
  final String outcome;
  final double confidence;
  final String severity;
  final String plainSummary;
  final String disclaimer;
  final Map<String, dynamic> symptomCoverage;
  final Map<String, dynamic> criteriaTable;
  final List<String> nextSteps;

  ReportDetail({
    required this.activeDisorder,
    required this.disorderName,
    required this.outcome,
    required this.confidence,
    required this.severity,
    required this.plainSummary,
    required this.disclaimer,
    required this.symptomCoverage,
    required this.criteriaTable,
    required this.nextSteps,
  });

  factory ReportDetail.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['next_steps'] ?? json['nextSteps'] ?? [];

    return ReportDetail(
      activeDisorder: (json['active_disorder'] ??
              json['activeDisorder'] ??
              '')
          .toString(),
      disorderName: (json['disorder_name'] ??
              json['disorderName'] ??
              'Screening Report')
          .toString(),
      outcome: (json['outcome'] ?? 'INSUFFICIENT').toString(),
      confidence: _ReportParser.doubleValue(json['confidence']),
      severity: (json['severity'] ?? 'N/A').toString(),
      plainSummary: (json['plain_summary'] ??
              json['plainSummary'] ??
              '')
          .toString(),
      disclaimer: (json['disclaimer'] ??
              'I’m not a clinician and I can’t diagnose. I can help with structured symptom screening and suggest next steps.')
          .toString(),
      symptomCoverage: json['symptom_coverage'] is Map
          ? Map<String, dynamic>.from(json['symptom_coverage'])
          : json['symptomCoverage'] is Map
              ? Map<String, dynamic>.from(json['symptomCoverage'])
              : <String, dynamic>{},
      criteriaTable: json['criteria_table'] is Map
          ? Map<String, dynamic>.from(json['criteria_table'])
          : json['criteriaTable'] is Map
              ? Map<String, dynamic>.from(json['criteriaTable'])
              : <String, dynamic>{},
      nextSteps: rawSteps is List
          ? rawSteps.map((e) => e.toString()).toList()
          : <String>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'active_disorder': activeDisorder,
      'disorder_name': disorderName,
      'outcome': outcome,
      'confidence': confidence,
      'severity': severity,
      'plain_summary': plainSummary,
      'disclaimer': disclaimer,
      'symptom_coverage': symptomCoverage,
      'criteria_table': criteriaTable,
      'next_steps': nextSteps,
    };
  }
}

class _ReportParser {
  static DateTime? date(dynamic value) {
    if (value == null) return null;

    return DateTime.tryParse(value.toString());
  }

  static double doubleValue(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;

    return double.tryParse((value ?? '').toString()) ?? 0.0;
  }

  static bool truthy(dynamic value) {
    if (value == true) return true;

    final s = value?.toString().toLowerCase().trim() ?? '';
    return s == 'true' || s == '1' || s == 'yes';
  }

  static bool hasRealReportData(Map<String, dynamic> json) {
    final disorder = (json['disorder_name'] ?? json['disorderName'] ?? '')
        .toString()
        .trim();

    final activeDisorder =
        (json['active_disorder'] ?? json['activeDisorder'] ?? '')
            .toString()
            .trim();

    final plainSummary =
        (json['plain_summary'] ?? json['plainSummary'] ?? '')
            .toString()
            .trim();

    final criteria = json['criteria_table'] ?? json['criteriaTable'];
    final symptoms = json['symptom_coverage'] ?? json['symptomCoverage'];

    return disorder.isNotEmpty ||
        activeDisorder.isNotEmpty ||
        plainSummary.isNotEmpty ||
        criteria is Map ||
        symptoms is Map;
  }
}