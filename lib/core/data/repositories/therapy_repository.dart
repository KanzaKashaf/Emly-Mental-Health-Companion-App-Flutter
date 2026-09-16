import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';

class TherapyRepository {
  final ApiClient api;

  TherapyRepository(this.api);

  Future<TherapyPlan?> getPlan() async {
    try {
      final res = await api.dio.get('/therapy/plan');

      if (res.data == null) return null;

      final data = Map<String, dynamic>.from(res.data as Map);

      // Backend may return:
      // { plan: {...} } OR direct plan object.
      final rawPlan = data['plan'] is Map
          ? Map<String, dynamic>.from(data['plan'])
          : data;

      if (rawPlan.isEmpty) return null;

      return TherapyPlan.fromJson(rawPlan);
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      // No CBT plan yet.
      if (status == 404) return null;

      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<TherapyProgressSummary?> getProgressSummary() async {
    try {
      final res = await api.dio.get('/therapy/progress/summary');

      if (res.data == null) return null;

      return TherapyProgressSummary.fromJson(
        Map<String, dynamic>.from(res.data as Map),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      // No summary yet.
      if (status == 404) return null;

      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<List<TherapyActivityHistoryItem>> getActivityHistory(
    String activityId,
  ) async {
    try {
      final res = await api.dio.get('/therapy/activities/$activityId/history');

      final data = res.data;

      final rawList = data is List
          ? data
          : data is Map
          ? (data['history'] ?? data['items'] ?? data['data'] ?? [])
          : [];

      if (rawList is! List) return [];

      return rawList
          .whereType<Map>()
          .map(
            (e) => TherapyActivityHistoryItem.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];

      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<TherapyProgressSubmitResponse> submitProgress({
    required String activityId,
    required Map<String, dynamic> responseData,
  }) async {
    try {
      final res = await api.dio.post(
        '/therapy/progress',
        data: {'activityId': activityId, 'responseData': responseData},
      );

      return TherapyProgressSubmitResponse.fromJson(
        Map<String, dynamic>.from(res.data),
      );
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> refreshActivityCards(String activityId) async {
    try {
      final res = await api.dio.post(
        '/therapy/activities/$activityId/refresh-cards',
      );

      if (res.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(res.data);
      }

      return <String, dynamic>{};
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<TherapyProgressEvaluation> getEvaluation() async {
    try {
      final res = await api.dio.get('/therapy/progress/evaluation');

      final data = res.data is Map<String, dynamic>
          ? Map<String, dynamic>.from(res.data)
          : <String, dynamic>{};

      final rawEvaluation = data['evaluation'] ?? data;

      return TherapyProgressEvaluation.fromJson(
        rawEvaluation is Map
            ? Map<String, dynamic>.from(rawEvaluation)
            : <String, dynamic>{},
      );
    } on DioException catch (e) {
      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }

  Future<CbtDashboard?> getCbtDashboard() async {
    try {
      final res = await api.dio.get('/therapy/cbt-dashboard');

      if (res.data == null) return null;

      return CbtDashboard.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      if (status == 404) {
        return CbtDashboard.empty();
      }

      throw (e.error is ApiError) ? (e.error as ApiError) : ApiError.fromDio(e);
    }
  }
}

class CbtDashboard {
  final bool success;
  final bool hasPlan;
  final String serverDate;
  final String timezone;
  final TherapyPlan? plan;
  final TherapyProgressSummary? summary;
  final List<TherapyActivity> activities;
  final TherapyProgressEvaluation? evaluation;

  CbtDashboard({
    required this.success,
    required this.hasPlan,
    required this.serverDate,
    required this.timezone,
    required this.plan,
    required this.summary,
    required this.activities,
    required this.evaluation,
  });

  factory CbtDashboard.empty() {
    return CbtDashboard(
      success: true,
      hasPlan: false,
      serverDate: '',
      timezone: 'Asia/Karachi',
      plan: null,
      summary: null,
      activities: const [],
      evaluation: null,
    );
  }

  factory CbtDashboard.fromJson(Map<String, dynamic> json) {
    final rawActivities = json['activities'];

    return CbtDashboard(
      success: json['success'] == true,
      hasPlan: json['hasPlan'] == true,
      serverDate: (json['serverDate'] ?? '').toString(),
      timezone: (json['timezone'] ?? 'Asia/Karachi').toString(),
      plan: json['plan'] is Map
          ? TherapyPlan.fromJson(Map<String, dynamic>.from(json['plan']))
          : null,
      summary: json['summary'] is Map
          ? TherapyProgressSummary.fromJson(
              Map<String, dynamic>.from(json['summary']),
            )
          : null,
      activities: rawActivities is List
          ? rawActivities
                .whereType<Map>()
                .map(
                  (e) => TherapyActivity.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : [],
      evaluation: json['evaluation'] is Map
          ? TherapyProgressEvaluation.fromJson(
              Map<String, dynamic>.from(json['evaluation']),
            )
          : null,
    );
  }
}

class TherapyPlan {
  final String id;
  final String stage;
  final String status;
  final String planSummary;
  final List<TherapyActivity> activities;

  final String? stageLabelOverride;
  final String? heroTitleOverride;
  final String validUntil;
  final String createdAt;

  TherapyPlan({
    required this.id,
    required this.stage,
    required this.status,
    required this.planSummary,
    required this.activities,
    this.stageLabelOverride,
    this.heroTitleOverride,
    this.validUntil = '',
    this.createdAt = '',
  });

  factory TherapyPlan.fromJson(Map<String, dynamic> json) {
    final rawActivities =
        json['activities'] ?? json['todayActivities'] ?? json['tasks'] ?? [];

    return TherapyPlan(
      id: (json['id'] ?? json['planId'] ?? '').toString(),
      stage: (json['stage'] ?? json['currentStage'] ?? 'EARLY_STAGE')
          .toString(),
      status: (json['status'] ?? '').toString(),
      stageLabelOverride: json['stageLabel']?.toString(),
      heroTitleOverride: json['heroTitle']?.toString(),
      validUntil: (json['validUntil'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      planSummary:
          (json['planSummary'] ??
                  json['summary'] ??
                  json['description'] ??
                  'Your CBT plan is ready.')
              .toString(),
      activities: rawActivities is List
          ? rawActivities
                .whereType<Map>()
                .map(
                  (e) => TherapyActivity.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : [],
    );
  }

  String get stageLabel {
    final backendValue = stageLabelOverride?.trim();
    if (backendValue != null && backendValue.isNotEmpty) {
      return backendValue;
    }

    final s = stage.toUpperCase();

    if (s.contains('EARLY')) return 'Early Stage';
    if (s.contains('MID')) return 'Mid Stage';
    if (s.contains('LATE')) return 'Late Stage';

    return stage.replaceAll('_', ' ');
  }

  String get heroTitle {
    final backendValue = heroTitleOverride?.trim();
    if (backendValue != null && backendValue.isNotEmpty) {
      return backendValue;
    }

    final s = stage.toUpperCase();

    if (s.contains('EARLY')) return 'Foundations\nare forming';
    if (s.contains('MID')) return 'Building\nmomentum';
    if (s.contains('LATE')) return 'Maintaining\nprogress';

    return 'Your CBT\nplan';
  }
}

class TherapyActivity {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String description;
  final String frequency;
  final String? progressText;
  final int? streakCount;
  final bool isCompleted;
  final bool isCompletedToday;
  final bool isTargetCompleted;
  final String? routeKey;
  final Map<String, dynamic> content;
  final int orderIndex;

  TherapyActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.frequency,
    this.progressText,
    this.streakCount,
    required this.isCompleted,
    required this.isCompletedToday,
    required this.isTargetCompleted,
    this.routeKey,
    required this.content,
    required this.orderIndex,
  });

  factory TherapyActivity.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? json['activityType'] ?? '').toString();

    final subtitle =
        (json['subtitle'] ??
                json['description'] ??
                json['shortDescription'] ??
                _subtitleFromType(type))
            .toString();

    final completedToday = _asBool(
      json['isCompletedToday'] ?? json['completedToday'],
    );

    final targetCompleted = _asBool(
      json['isTargetCompleted'] ??
          json['targetCompleted'] ??
          json['is_target_completed'],
    );

    final completed = _asBool(
      json['isCompleted'] ?? json['completed'] ?? completedToday,
    );

    return TherapyActivity(
      id: (json['id'] ?? json['activityId'] ?? type).toString(),
      type: type,
      title: (json['title'] ?? _titleFromType(type)).toString(),
      subtitle: subtitle,
      description: (json['description'] ?? subtitle).toString(),
      frequency: _formatFrequency(
        json['frequency'] ?? json['schedule'] ?? 'Daily',
      ),
      progressText: json['progressText']?.toString(),
      streakCount: _asNullableInt(json['streakCount'] ?? json['streak']),
      isCompleted: completed,
      isCompletedToday: completedToday,
      isTargetCompleted: targetCompleted,
      routeKey: json['routeKey']?.toString(),
      content: json['content'] is Map
          ? Map<String, dynamic>.from(json['content'])
          : <String, dynamic>{},
      orderIndex: _asInt(json['orderIndex']),
    );
  }

  Map<String, dynamic> toRouteArgs() {
    return {
      'activityId': id,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'frequency': frequency,
      'content': content,
      'routeKey': routeKey,
      'isCompletedToday': isCompletedToday,
      'isTargetCompleted': isTargetCompleted,
      'streakCount': streakCount,
      'progressText': progressText,
    };
  }

  static String _titleFromType(String type) {
    final t = type.toLowerCase();

    if (t.contains('mood')) return 'Daily Mood Check-in';
    if (t.contains('pleasant') || t.contains('behavioral')) {
      return 'Pleasant Activities';
    }
    if (t.contains('thought_record')) return 'Thought Record';
    if (t.contains('distortion') || t.contains('trap')) return 'Thinking Traps';
    if (t.contains('sleep')) return 'Sleep Habits';
    if (t.contains('gratitude')) return 'Gratitude Log';
    if (t.contains('self')) return 'Self Compassion';
    if (t.contains('weekly') || t.contains('reflection'))
      return 'Weekly Review';

    return 'CBT Activity';
  }

  static String _subtitleFromType(String type) {
    final t = type.toLowerCase();

    if (t.contains('mood')) return 'Rate how you feel 1-10';
    if (t.contains('pleasant') || t.contains('behavioral')) {
      return 'Try one activity today';
    }
    if (t.contains('thought_record')) return 'Reframe a negative thought';
    if (t.contains('distortion') || t.contains('trap')) {
      return 'Review thinking patterns';
    }
    if (t.contains('sleep')) return 'Build helpful sleep habits';
    if (t.contains('gratitude')) return 'Write 3 good things today';
    if (t.contains('self')) return 'Practice a kind response';
    if (t.contains('weekly') || t.contains('reflection')) {
      return 'Reflect on your week';
    }

    return 'Complete this CBT exercise';
  }

  static String _formatFrequency(dynamic value) {
    final raw = (value ?? '').toString().trim();

    if (raw.isEmpty) return 'Daily';

    final lower = raw.toLowerCase();

    if (lower == 'daily') return 'Daily';
    if (lower == 'weekly') return 'Weekly';
    if (lower == '3x_week' || lower == '3x week' || lower == '3× week') {
      return '3× week';
    }

    return raw;
  }
}

class TherapyProgressSummary {
  final int totalCompletions;
  final int todayCompletions;
  final int bestStreak;
  final double completionRate;
  final String moodTrend;
  final List<MoodHistoryItem> moodHistory;
  final double? moodAverageOverride;

  TherapyProgressSummary({
    required this.totalCompletions,
    required this.todayCompletions,
    required this.bestStreak,
    required this.completionRate,
    required this.moodTrend,
    required this.moodHistory,
    this.moodAverageOverride,
  });

  double get moodAverage {
    if (moodAverageOverride != null && moodAverageOverride! > 0) {
      return moodAverageOverride!;
    }

    if (moodHistory.isEmpty) return 0;

    final total = moodHistory.fold<double>(0, (sum, item) => sum + item.score);

    return total / moodHistory.length;
  }

  int get completionPercent {
    return (completionRate.clamp(0.0, 1.0) * 100).round();
  }

  factory TherapyProgressSummary.fromJson(Map<String, dynamic> json) {
    final rawMoodHistory = json['moodHistory'];

    return TherapyProgressSummary(
      totalCompletions: _asInt(
        json['totalCompletions'] ?? json['total_completions'],
      ),
      todayCompletions: _asInt(
        json['todayCompletions'] ??
            json['today_completions'] ??
            json['completedTodayCount'] ??
            json['todayDone'],
      ),
      bestStreak: _asInt(
        json['bestStreak'] ?? json['best_streak'] ?? json['currentStreak'],
      ),
      completionRate: _normalizeProgress(
        json['completionRate'] ?? json['completion_rate'],
      ),
      moodTrend: (json['moodTrend'] ?? json['mood_trend'] ?? 'stable')
          .toString(),
      moodAverageOverride: _asNullableDouble(
        json['moodAverage'] ?? json['mood_average'],
      ),
      moodHistory: rawMoodHistory is List
          ? rawMoodHistory
                .whereType<Map>()
                .map(
                  (e) => MoodHistoryItem.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : [],
    );
  }
}

class MoodHistoryItem {
  final DateTime? date;
  final double score;
  final String interpretation;
  final String note;

  MoodHistoryItem({
    required this.date,
    required this.score,
    required this.interpretation,
    required this.note,
  });

  factory MoodHistoryItem.fromJson(Map<String, dynamic> json) {
    return MoodHistoryItem(
      date: DateTime.tryParse((json['date'] ?? '').toString()),
      score: _asDouble(json['score']),
      interpretation: (json['interpretation'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
    );
  }
}

class ActivityScore {
  final String type;
  final String title;
  final int completionsLast7Days;
  final double averageScore;
  final String trend;

  ActivityScore({
    required this.type,
    required this.title,
    required this.completionsLast7Days,
    required this.averageScore,
    required this.trend,
  });

  factory ActivityScore.fromJson(Map<String, dynamic> json) {
    return ActivityScore(
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      completionsLast7Days: _asInt(json['completions_last_7_days']),
      averageScore: _asDouble(json['avg_score']),
      trend: (json['trend'] ?? '').toString(),
    );
  }
}

class TherapyActivityHistoryItem {
  final String id;
  final DateTime? completedAt;
  final Map<String, dynamic> responseData;
  final int streakCount;
  final String? notes;

  TherapyActivityHistoryItem({
    required this.id,
    required this.completedAt,
    required this.responseData,
    required this.streakCount,
    this.notes,
  });

  factory TherapyActivityHistoryItem.fromJson(Map<String, dynamic> json) {
    final dynamic rawResponse =
        json['response'] ?? json['responseData'] ?? json['data'];

    Map<String, dynamic> parsedResponse = {};

    if (rawResponse is Map) {
      parsedResponse = Map<String, dynamic>.from(rawResponse);
    }

    return TherapyActivityHistoryItem(
      id: (json['id'] ?? '').toString(),
      completedAt: _parseBackendDateTime(
        json['completedAt'] ?? json['createdAt'] ?? json['date'],
      ),
      responseData: parsedResponse,
      streakCount: _asInt(json['streakCount'] ?? json['streak'] ?? 0),
      notes: json['notes']?.toString(),
    );
  }
}

class TherapyProgressSubmitResponse {
  final String message;
  final int streakCount;
  final bool completed;

  TherapyProgressSubmitResponse({
    required this.message,
    required this.streakCount,
    required this.completed,
  });

  factory TherapyProgressSubmitResponse.fromJson(Map<String, dynamic> json) {
    return TherapyProgressSubmitResponse(
      message: (json['message'] ?? 'Activity completed.').toString(),
      streakCount: _asInt(
        json['streakCount'] ??
            json['streak'] ??
            json['bestStreak'] ??
            json['currentStreak'] ??
            0,
      ),
      completed: json['completed'] == true || json['success'] == true,
    );
  }
}

DateTime? _parseBackendDateTime(dynamic value) {
  final raw = (value ?? '').toString().trim();

  if (raw.isEmpty) return null;

  final hasTimezone =
      raw.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);

  final normalized = hasTimezone ? raw : '${raw}Z';

  return DateTime.tryParse(normalized);
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse((value ?? 0).toString()) ?? 0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  return _asInt(value);
}

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  return double.tryParse(value.toString());
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse((value ?? 0).toString()) ?? 0;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is int) return value == 1;

  final s = (value ?? '').toString().trim().toLowerCase();

  return s == 'true' || s == '1' || s == 'yes';
}

double _normalizeProgress(dynamic value) {
  final n = _asDouble(value);

  if (n > 1) {
    return (n / 100).clamp(0.0, 1.0);
  }

  return n.clamp(0.0, 1.0);
}

class TherapyProgressEvaluation {
  final String currentStage;
  final String currentStageLabel;
  final String recommendedStage;
  final String recommendedStageLabel;
  final bool stageChangeReady;
  final double completionRate;
  final String completionText;
  final String moodTrend;
  final String moodValue;
  final List<TherapyActivityScore> activityScores;

  TherapyProgressEvaluation({
    required this.currentStage,
    required this.currentStageLabel,
    required this.recommendedStage,
    required this.recommendedStageLabel,
    required this.stageChangeReady,
    required this.completionRate,
    required this.completionText,
    required this.moodTrend,
    required this.moodValue,
    required this.activityScores,
  });

  factory TherapyProgressEvaluation.fromJson(Map<String, dynamic> json) {
    final rawScores =
        json['activityScores'] ??
        json['activity_scores'] ??
        json['activities'] ??
        [];

    final completionRate = _normalizeProgress(
      json['completionRate'] ?? json['completion_rate'],
    );

    return TherapyProgressEvaluation(
      currentStage:
          (json['currentStage'] ??
                  json['current_stage'] ??
                  json['stage'] ??
                  'EARLY_STAGE')
              .toString(),
      currentStageLabel: (json['currentStageLabel'] ?? 'Early Stage')
          .toString(),
      recommendedStage:
          (json['recommendedStage'] ??
                  json['recommended_stage'] ??
                  json['currentStage'] ??
                  json['current_stage'] ??
                  'EARLY_STAGE')
              .toString(),
      recommendedStageLabel: (json['recommendedStageLabel'] ?? 'Early Stage')
          .toString(),
      stageChangeReady:
          json['stageChangeReady'] == true ||
          json['stage_change_ready'] == true,
      completionRate: completionRate,
      completionText:
          (json['completionText'] ?? '${(completionRate * 100).round()}%')
              .toString(),
      moodTrend: (json['moodTrend'] ?? json['mood_trend'] ?? 'stable')
          .toString(),
      moodValue: (json['moodValue'] ?? '--').toString(),
      activityScores: rawScores is List
          ? rawScores
                .whereType<Map>()
                .map(
                  (e) => TherapyActivityScore.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : [],
    );
  }
}

class TherapyActivityScore {
  final String activityId;
  final String type;
  final String title;
  final int completionsLast7Days;
  final int weeklyTarget;
  final String frequencyLabel;
  final double? avgScore;
  final String trend;
  final double progress;
  final String subtitle;
  final bool isTargetCompleted;

  TherapyActivityScore({
    required this.activityId,
    required this.type,
    required this.title,
    required this.completionsLast7Days,
    required this.weeklyTarget,
    required this.frequencyLabel,
    required this.avgScore,
    required this.trend,
    required this.progress,
    required this.subtitle,
    required this.isTargetCompleted,
  });

  factory TherapyActivityScore.fromJson(Map<String, dynamic> json) {
    final avgRaw =
        json['avg_score'] ??
        json['avgScore'] ??
        json['average_score'] ??
        json['averageScore'];

    final completions = _asInt(
      json['completions_last_7_days'] ??
          json['completionsLast7Days'] ??
          json['completed_last_7_days'] ??
          json['completedLast7Days'],
    );

    final target = _asInt(json['weeklyTarget']);

    return TherapyActivityScore(
      activityId: (json['activityId'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? 'Activity').toString(),
      completionsLast7Days: completions,
      weeklyTarget: target,
      frequencyLabel: (json['frequencyLabel'] ?? 'times').toString(),
      avgScore: _asNullableDouble(avgRaw),
      trend: (json['trend'] ?? 'stable').toString(),
      progress: _normalizeProgress(json['progress']),
      subtitle: (json['subtitle'] ?? '').toString(),
      isTargetCompleted: _asBool(
        json['isTargetCompleted'] ??
            json['targetCompleted'] ??
            json['is_target_completed'],
      ),
    );
  }
}

class _TherapyEvalParser {
  static int asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  static double asDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse((value ?? '').toString()) ?? 0.0;
  }

  static double? nullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString());
  }
}
