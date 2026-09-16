import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';
import '../../../../core/data/repositories/therapy_repository.dart';

class ProgressEvaluationScreen extends StatefulWidget {
  const ProgressEvaluationScreen({super.key});

  @override
  State<ProgressEvaluationScreen> createState() =>
      _ProgressEvaluationScreenState();
}

class _ProgressEvaluationScreenState extends State<ProgressEvaluationScreen> {
  bool _argsRead = false;
  bool _fromMyProfile = false;

  bool _loading = true;
  TherapyProgressEvaluation? _evaluation;
  List<TherapyActivity> _planActivities = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_argsRead) return;

    final args = ModalRoute.of(context)?.settings.arguments;

    bool hasPassedEvaluation = false;

    if (args is Map) {
      _fromMyProfile = args['source'] == 'myProfile';

      final passedEvaluation = args['evaluation'];
      final passedActivities = args['activities'];

      if (passedEvaluation is TherapyProgressEvaluation) {
        _evaluation = passedEvaluation;
        hasPassedEvaluation = true;
      }

      if (passedActivities is List<TherapyActivity>) {
        _planActivities = passedActivities;
      } else if (passedActivities is List) {
        _planActivities = passedActivities
            .whereType<TherapyActivity>()
            .toList();
      }
    }

    _argsRead = true;

    if (hasPassedEvaluation) {
      setState(() {
        _loading = false;
      });
    } else {
      _loadEvaluation();
    }
  }

  Future<void> _loadEvaluation() async {
    setState(() => _loading = true);

    try {
      final dashboard = await AppServices.therapyRepository.getCbtDashboard();

      if (!mounted) return;

      setState(() {
        _evaluation = dashboard?.evaluation;
        _planActivities =
            dashboard?.activities ?? dashboard?.plan?.activities ?? [];
        _loading = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      _showError(
        e.message.isNotEmpty
            ? e.message
            : 'Failed to load progress evaluation.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showError('Failed to load progress evaluation.');
    }
  }

  void _handleBack() {
    if (_fromMyProfile) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.cbt);
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  String _stageLabel(String value) {
    final cleaned = value
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim()
        .toLowerCase();

    if (cleaned.isEmpty) return 'Early Stage';

    return cleaned
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  String _percentageLabel(double value) {
    final normalized = value <= 1 ? value * 100 : value;
    return '${normalized.round()}%';
  }

  double _clampedProgress(double value) {
    final normalized = value > 1 ? value / 100 : value;
    return normalized.clamp(0.0, 1.0);
  }

  TherapyActivityScore? _moodActivityScore(List<TherapyActivityScore> scores) {
    for (final item in scores) {
      final type = item.type.toLowerCase();
      final title = item.title.toLowerCase();

      if (type.contains('mood') || title.contains('mood')) {
        return item;
      }
    }

    return null;
  }

  String _moodValue(TherapyProgressEvaluation eval) {
    final mood = _moodActivityScore(eval.activityScores);

    if (mood?.avgScore != null) {
      return _formatNumber(mood!.avgScore!);
    }

    return _titleCase(eval.moodTrend);
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }

  String _titleCase(String value) {
    final cleaned = value.replaceAll('_', ' ').replaceAll('-', ' ').trim();

    if (cleaned.isEmpty) return 'Stable';

    return cleaned
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  String _trendArrowAsset(String trend) {
    final t = trend.toLowerCase();

    if (t.contains('improving') ||
        t.contains('increase') ||
        t.contains('up') ||
        t.contains('positive')) {
      return 'assets/images/UpArrow.png';
    }

    if (t.contains('declining') ||
        t.contains('decrease') ||
        t.contains('down') ||
        t.contains('worse')) {
      return 'assets/images/DownArrow.png';
    }

    return 'assets/images/StraightArrow.png';
  }

  Color _trendColor(String trend, Color defaultColor) {
    final t = trend.toLowerCase();

    if (t.contains('improving') ||
        t.contains('increase') ||
        t.contains('up') ||
        t.contains('positive')) {
      return const Color(0xFF18B663);
    }

    if (t.contains('declining') ||
        t.contains('decrease') ||
        t.contains('down') ||
        t.contains('worse')) {
      return const Color(0xFFF63A3A);
    }

    return defaultColor;
  }

  String _activitySubtitle(TherapyActivityScore score) {
    final completions = score.completionsLast7Days;
    final target = _weeklyTargetForScore(score);
    final label = _frequencyLabelForScore(score);

    if (score.avgScore != null) {
      return '$completions/$target $label · avg ${_formatNumber(score.avgScore!)}';
    }

    return '$completions/$target $label';
  }

  double _activityProgress(TherapyActivityScore score) {
    final target = _weeklyTargetForScore(score);
    if (target <= 0) return 0;

    return (score.completionsLast7Days / target).clamp(0.0, 1.0);
  }

  TherapyActivity? _matchingPlanActivity(TherapyActivityScore score) {
    final scoreType = score.type.trim().toLowerCase();
    final scoreTitle = score.title.trim().toLowerCase();

    for (final activity in _planActivities) {
      final activityType = activity.type.trim().toLowerCase();
      final activityTitle = activity.title.trim().toLowerCase();

      if (scoreType.isNotEmpty && activityType == scoreType) {
        return activity;
      }

      if (scoreTitle.isNotEmpty && activityTitle == scoreTitle) {
        return activity;
      }
    }

    for (final activity in _planActivities) {
      final activityType = activity.type.trim().toLowerCase();
      final activityTitle = activity.title.trim().toLowerCase();

      if (scoreType.isNotEmpty &&
          (activityType.contains(scoreType) ||
              scoreType.contains(activityType))) {
        return activity;
      }

      if (scoreTitle.isNotEmpty &&
          (activityTitle.contains(scoreTitle) ||
              scoreTitle.contains(activityTitle))) {
        return activity;
      }
    }

    return null;
  }

  int _weeklyTargetForScore(TherapyActivityScore score) {
    final activity = _matchingPlanActivity(score);
    final frequency = activity?.frequency.trim().toLowerCase() ?? '';

    if (frequency == 'daily') return 7;

    if (frequency == 'weekly') return 1;

    if (frequency == '3x_week' ||
        frequency == '3x week' ||
        frequency == '3 times/week' ||
        frequency == '3 times a week' ||
        frequency == 'three_times_weekly') {
      return 3;
    }

    if (frequency.contains('3')) return 3;
    if (frequency.contains('week')) return 1;
    if (frequency.contains('daily')) return 7;

    return 7;
  }

  String _frequencyLabelForScore(TherapyActivityScore score) {
    final target = _weeklyTargetForScore(score);

    if (target == 7) return 'days';
    if (target == 3) return 'times';
    if (target == 1) return 'time';

    return 'times';
  }

  _WeeklyProgress? _parseActivityProgress(String? value) {
    final text = (value ?? '').trim();

    if (text.isEmpty) return null;

    final match = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(text);

    if (match == null) return null;

    final completed = int.tryParse(match.group(1) ?? '') ?? 0;
    final target = int.tryParse(match.group(2) ?? '') ?? 0;

    if (target <= 0) return null;

    final safeCompleted = completed > target ? target : completed;

    return _WeeklyProgress(completed: safeCompleted, target: target);
  }

  int _weeklyTargetForActivity(TherapyActivity activity) {
    final frequency = activity.frequency.trim().toLowerCase();

    if (frequency.contains('daily')) return 7;
    if (frequency.contains('3')) return 3;
    if (frequency.contains('weekly')) return 1;
    if (frequency.contains('week')) return 1;

    return 7;
  }

  _WeeklyProgress get _currentWeekProgress {
    int completed = 0;
    int target = 0;

    // Main source: same activities used by CBT dashboard
    for (final activity in _planActivities) {
      final parsed = _parseActivityProgress(activity.progressText);

      if (parsed != null) {
        completed += parsed.completed;
        target += parsed.target;
        continue;
      }

      if (activity.isTargetCompleted) {
        final fallbackTarget = _weeklyTargetForActivity(activity);
        completed += fallbackTarget;
        target += fallbackTarget;
        continue;
      }

      final fallbackTarget = _weeklyTargetForActivity(activity);
      target += fallbackTarget;

      if (activity.isCompletedToday) {
        completed += 1;
      }
    }

    // Fallback source: evaluation activity scores
    if (target == 0 && _evaluation != null) {
      for (final score in _evaluation!.activityScores) {
        final scoreTarget = score.weeklyTarget > 0
            ? score.weeklyTarget
            : _weeklyTargetForScore(score);

        if (score.isTargetCompleted) {
          completed += scoreTarget;
        } else {
          completed += score.completionsLast7Days > scoreTarget
              ? scoreTarget
              : score.completionsLast7Days;
        }

        target += scoreTarget;
      }
    }

    return _WeeklyProgress(completed: completed, target: target);
  }

  double get _currentWeekCompletionRate {
    return _currentWeekProgress.rate;
  }

  String get _currentWeekCompletionText {
    final percent = (_currentWeekCompletionRate * 100).round();
    return '$percent%';
  }

  Widget _buildTopBar({required Color textColor}) {
    return Row(
      children: [
        IconButton(
          onPressed: _loading ? null : _handleBack,
          icon: Icon(Icons.arrow_back, size: 26, color: textColor),
        ),
        Text(
          _fromMyProfile ? 'CBT Progress' : 'Progress Evaluation',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final textColor = isDark ? Colors.white : const Color(0xFF2F2F2F);
    final subTextColor = isDark
        ? Colors.white.withOpacity(0.68)
        : Colors.black.withOpacity(0.52);

    final cardColor = isDark
        ? const Color(0xFF2B2B2B)
        : const Color(0xFFF4F7FD);

    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final eval = _evaluation;

    final currentStage = eval?.currentStageLabel ?? 'Early Stage';

    final recommendedStage = eval?.recommendedStageLabel ?? 'Mid Stage';

    final completionValue = _currentWeekCompletionText;
    final completionProgress = _currentWeekCompletionRate;

    final moodValue = eval?.moodValue ?? '--';
    final moodTrend = eval?.moodTrend ?? 'stable';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              _buildTopBar(textColor: textColor),

              Expanded(
                child: _loading
                    ? _ProgressEvaluationSkeleton(isDark: isDark)
                    : RefreshIndicator(
                        onRefresh: _loadEvaluation,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 18),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    /// HERO CARD
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        22,
                                        24,
                                        26,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primary,
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'STAGE PROGRESS',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0.4,
                                              color: Colors.white.withOpacity(
                                                0.45,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            eval?.stageChangeReady == true
                                                ? 'Ready for Next Stage'
                                                : 'Your CBT Progress',
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 24,
                                              fontWeight: FontWeight.w600,
                                              height: 1.15,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 18),

                                          /// STAGE PILLS
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.16),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          18,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    currentStage,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontFamily: 'Poppins',
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              const Text(
                                                '>',
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.white,
                                                  height: 1,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Flexible(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 18,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          18,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    recommendedStage,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontFamily: 'Poppins',
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: primary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 22),

                                    /// METRIC CARDS
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _MetricCard(
                                            backgroundColor: cardColor,
                                            title: 'Completion',
                                            value: completionValue,
                                            valueColor: textColor,
                                            titleColor: subTextColor,
                                            leadingAsset: null,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _MetricCard(
                                            backgroundColor: cardColor,
                                            title: 'Mood',
                                            value: moodValue,
                                            valueColor: _trendColor(
                                              moodTrend,
                                              textColor,
                                            ),
                                            titleColor: subTextColor,
                                            leadingAsset: _trendArrowAsset(
                                              moodTrend,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 14),

                                    Text(
                                      'By Activity',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: textColor,
                                      ),
                                    ),

                                    const SizedBox(height: 10),

                                    if (eval == null ||
                                        eval.activityScores.isEmpty) ...[
                                      _EmptyEvaluationCard(
                                        isDark: isDark,
                                        message:
                                            'No activity progress available yet. Complete a few CBT activities to see your breakdown.',
                                      ),
                                    ] else ...[
                                      ...eval.activityScores.map(
                                        (score) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 2,
                                          ),
                                          child: _ActivityProgressCard(
                                            isDark: isDark,
                                            title: score.title,
                                            subtitle:
                                                score.subtitle.trim().isNotEmpty
                                                ? score.subtitle
                                                : _activitySubtitle(score),
                                            progress: score.progress > 0
                                                ? score.progress
                                                : _activityProgress(score),
                                            arrowAsset: _trendArrowAsset(
                                              score.trend,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 30),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final Color backgroundColor;
  final String title;
  final String value;
  final Color valueColor;
  final Color titleColor;
  final String? leadingAsset;

  const _MetricCard({
    required this.backgroundColor,
    required this.title,
    required this.value,
    required this.valueColor,
    required this.titleColor,
    this.leadingAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 81,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: titleColor,
            ),
          ),
          const Spacer(),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leadingAsset != null) ...[
                Image.asset(
                  leadingAsset!,
                  width: 18,
                  height: 18,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    height: 1,
                    color: valueColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityProgressCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;
  final double progress;
  final String arrowAsset;

  const _ActivityProgressCard({
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.arrowAsset,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark
        ? const Color(0xFF2B2B2B)
        : const Color(0xFFF4F7FD);

    final titleColor = isDark ? Colors.white : const Color(0xFF2F2F2F);

    final subColor = isDark
        ? Colors.white.withOpacity(0.68)
        : Colors.black.withOpacity(0.52);

    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          /// LEFT TEXT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.15,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.15,
                    color: subColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          /// PROGRESS BAR + ARROW SAME ROW / SAME LEVEL
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 90,
                height: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? Colors.white
                        : const Color(0xFFFFFFFF),
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Image.asset(
                arrowAsset,
                width: 16,
                height: 16,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyEvaluationCard extends StatelessWidget {
  final bool isDark;
  final String message;

  const _EmptyEvaluationCard({required this.isDark, required this.message});

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark
        ? const Color(0xFF2B2B2B)
        : const Color(0xFFF4F7FD);

    final textColor = isDark
        ? Colors.white.withOpacity(0.70)
        : Colors.black.withOpacity(0.55);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          height: 1.45,
          color: textColor,
        ),
      ),
    );
  }
}

class _ProgressEvaluationSkeleton extends StatelessWidget {
  final bool isDark;

  const _ProgressEvaluationSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark
        ? const Color(0xFF2B2B2B)
        : const Color(0xFFE8ECF3);

    final highlightColor = isDark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFF6F8FC);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// HERO CARD SKELETON
                  const _ProgressHeroSkeleton(),

                  const SizedBox(height: 22),

                  /// METRIC CARDS SKELETON
                  const Row(
                    children: [
                      Expanded(child: _MetricCardSkeleton()),
                      SizedBox(width: 16),
                      Expanded(child: _MetricCardSkeleton()),
                    ],
                  ),

                  const SizedBox(height: 14),

                  const _SkeletonBox(width: 90, height: 20, radius: 6),

                  const SizedBox(height: 10),

                  /// ACTIVITY ROWS SKELETON
                  const _ActivityProgressCardSkeleton(),
                  SizedBox(height: 2),
                  const _ActivityProgressCardSkeleton(),
                  SizedBox(height: 2),
                  const _ActivityProgressCardSkeleton(),
                  SizedBox(height: 2),
                  const _ActivityProgressCardSkeleton(),
                  SizedBox(height: 2),
                  const _ActivityProgressCardSkeleton(),
                  SizedBox(height: 2),
                  const _ActivityProgressCardSkeleton(),
                  SizedBox(height: 2),
                  const _ActivityProgressCardSkeleton(),
                  SizedBox(height: 2),
                  const _ActivityProgressCardSkeleton(),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressHeroSkeleton extends StatelessWidget {
  const _ProgressHeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkeletonBox(width: 130, height: 14, radius: 6),

          const SizedBox(height: 10),

          const _SkeletonBox(width: 230, height: 28, radius: 8),

          const SizedBox(height: 18),

          Row(
            children: [
              Flexible(
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(
                    child: _SkeletonBox(
                      width: double.infinity,
                      height: 14,
                      radius: 6,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              const _SkeletonBox(width: 16, height: 24, radius: 4),

              const SizedBox(width: 10),

              Flexible(
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(
                    child: _SkeletonBox(
                      width: double.infinity,
                      height: 14,
                      radius: 6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCardSkeleton extends StatelessWidget {
  const _MetricCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 81,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(width: 90, height: 13, radius: 6),
          Spacer(),
          _SkeletonBox(width: 70, height: 28, radius: 8),
        ],
      ),
    );
  }
}

class _ActivityProgressCardSkeleton extends StatelessWidget {
  const _ActivityProgressCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 170, height: 14, radius: 6),
                SizedBox(height: 6),
                _SkeletonBox(width: 130, height: 13, radius: 6),
              ],
            ),
          ),

          SizedBox(width: 12),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SkeletonBox(width: 90, height: 6, radius: 10),
              SizedBox(width: 8),
              _SkeletonBox(width: 16, height: 16, radius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.height,
    this.width = double.infinity,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _WeeklyProgress {
  final int completed;
  final int target;

  const _WeeklyProgress({required this.completed, required this.target});

  double get rate {
    if (target <= 0) return 0.0;
    return (completed / target).clamp(0.0, 1.0);
  }
}
