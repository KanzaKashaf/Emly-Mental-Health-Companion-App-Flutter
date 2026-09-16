import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';
import '../../../../core/data/repositories/therapy_repository.dart';
import '../../../../core/services/cbt_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../../../routes/app_routes.dart';

class CbtPlanScreen extends StatefulWidget {
  const CbtPlanScreen({super.key});

  @override
  State<CbtPlanScreen> createState() => _CbtPlanScreenState();
}

class _CbtPlanScreenState extends State<CbtPlanScreen> {
  bool _loading = true;
  bool _error = false;

  TherapyPlan? _plan;
  TherapyProgressSummary? _summary;

  List<TherapyActivity> _dashboardActivities = [];

  List<TherapyActivity> get _activities => _dashboardActivities;

  TherapyProgressEvaluation? _evaluation;

  @override
  void initState() {
    super.initState();
    _loadCbtPlan();
  }

  int get _bestStreak => _summary?.bestStreak ?? 0;

  int get _todayCompletions => _summary?.todayCompletions ?? 0;

  double get _moodAverage => _summary?.moodAverage ?? 0;

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

    for (final activity in _activities) {
      final parsed = _parseActivityProgress(activity.progressText);

      if (parsed != null) {
        completed += parsed.completed;
        target += parsed.target;
        continue;
      }

      final fallbackTarget = _weeklyTargetForActivity(activity);

      target += fallbackTarget;

      if (activity.isCompletedToday) {
        completed += 1;
      }
    }

    return _WeeklyProgress(completed: completed, target: target);
  }

  double get _overallProgress {
    return _currentWeekProgress.rate;
  }

  String get _overallProgressText {
    final percent = (_overallProgress * 100).round();
    return '$percent% completed';
  }

  String get _moodDisplay {
    if (_moodAverage <= 0) return '--';
    return _moodAverage.toStringAsFixed(1);
  }

  String _activityProgressText(TherapyActivity activity) {
    return activity.progressText ?? '';
  }

  bool _activityShouldShowCheck(TherapyActivity activity) {
    final frequency = activity.frequency.trim().toLowerCase();

    // Daily activities should only show checked when completed today.
    if (frequency.contains('daily')) {
      return activity.isCompletedToday;
    }

    // Backend source: weekly / 3× week target completed.
    if (activity.isTargetCompleted) {
      return true;
    }

    // Fallback: parse progressText like "1/1", "3/3".
    final parsed = _parseActivityProgress(activity.progressText);

    if (parsed != null && parsed.target > 0) {
      return parsed.completed >= parsed.target;
    }

    return activity.isCompletedToday;
  }

  bool _activityShouldShowFlame(TherapyActivity activity) {
    final streak = activity.streakCount ?? 0;
    final frequency = activity.frequency.trim().toLowerCase();

    if (_bestStreak <= 0) return false;
    if (streak <= 0) return false;

    // Weekly activities are plan-completion activities, not daily streak activities.
    if (frequency == 'weekly' || frequency.contains('weekly')) {
      return false;
    }

    return true;
  }

  Future<void> _loadCbtPlan() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final dashboard = await AppServices.therapyRepository.getCbtDashboard();

      if (!mounted) return;

      final hasPlan = dashboard?.hasPlan == true;

      setState(() {
        _plan = hasPlan ? dashboard!.plan : null;
        _summary = hasPlan ? dashboard!.summary : null;
        _evaluation = hasPlan ? dashboard!.evaluation : null;
        _dashboardActivities = hasPlan
            ? dashboard!.activities.isNotEmpty
                  ? dashboard.activities
                  : dashboard.plan?.activities ?? []
            : [];
        _loading = false;
        _error = false;
      });

      if (hasPlan && _dashboardActivities.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          CbtNotificationService.instance.setupDefaultRemindersIfFirstTime();
        });
      }
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = true;
      });

      _showError(e.message.isNotEmpty ? e.message : 'Failed to load CBT plan.');
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = true;
      });

      _showError('Failed to load CBT plan.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _openActivity(TherapyActivity item) {
    final route = _routeForActivity(item);

    if (route == null) {
      _showError('This activity screen is not available yet.');
      return;
    }

    Navigator.pushNamed(context, route, arguments: item.toRouteArgs()).then((
      _,
    ) {
      if (mounted) {
        _loadCbtPlan();
      }
    });
  }

  String? _routeForActivity(TherapyActivity item) {
    final routeKey = item.routeKey?.trim().toLowerCase();

    switch (routeKey) {
      case 'thought_record':
        return AppRoutes.thoughtRecord;
      case 'thinking_traps':
        return AppRoutes.thinkingTraps;
      case 'sleep_habits':
        return AppRoutes.sleepHabits;
      case 'gratitude_log':
        return AppRoutes.gratitudeLog;
      case 'self_compassion':
        return AppRoutes.selfCompassion;
      case 'weekly_review':
        return AppRoutes.weeklyReview;
      case 'mood':
      case 'mood_tracker':
        return AppRoutes.moodCheckIn;
      case 'pleasant_activities':
      case 'behavioral_activation':
        return AppRoutes.pleasantActivities;
    }

    final title = item.title.toLowerCase();
    final type = item.type.toLowerCase();

    if (type.contains('thought_record') || title.contains('thought record')) {
      return AppRoutes.thoughtRecord;
    }

    if (type.contains('distortion') ||
        type.contains('trap') ||
        title.contains('thinking trap')) {
      return AppRoutes.thinkingTraps;
    }

    if (type.contains('sleep') || title.contains('sleep')) {
      return AppRoutes.sleepHabits;
    }

    if (type.contains('gratitude') || title.contains('gratitude')) {
      return AppRoutes.gratitudeLog;
    }

    if (type.contains('self') || title.contains('self compassion')) {
      return AppRoutes.selfCompassion;
    }

    if (type.contains('weekly') ||
        type.contains('reflection') ||
        title.contains('weekly review')) {
      return AppRoutes.weeklyReview;
    }

    if (type.contains('mood') || title.contains('mood')) {
      return AppRoutes.moodCheckIn;
    }

    if (type.contains('pleasant') ||
        type.contains('behavioral') ||
        title.contains('pleasant')) {
      return AppRoutes.pleasantActivities;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      },
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, AppRoutes.home);
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Text(
                    'Your CBT Plan',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Expanded(child: _buildBody(isDark)),
            ],
          ),
        ),

        bottomNavigationBar: BottomNavBar(
          currentIndex: 2,
          onTap: (i) {
            if (i == 1) {
              Navigator.pushReplacementNamed(
                context,
                AppRoutes.chat,
                arguments: {'startFresh': true},
              );
            }

            if (i == 2) {
              // Already on CBT.
            }

            if (i == 3) {
              Navigator.pushReplacementNamed(context, AppRoutes.history);
            }

            if (i == 4) {
              Navigator.pushReplacementNamed(context, AppRoutes.settings);
            }
          },
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    final hasDashboardContent = _plan != null && _activities.isNotEmpty;

    if (_loading && !hasDashboardContent) {
      return _CbtDashboardSkeleton(isDark: isDark);
    }

    if (_error && !hasDashboardContent) {
      return _CbtEmptyState(
        isDark: isDark,
        title: 'Could not load CBT plan',
        subtitle: 'Please check your connection and try again.',
        buttonText: 'Retry',
        onTap: _loadCbtPlan,
      );
    }

    if (_plan == null || _activities.isEmpty) {
      return _CbtEmptyState(
        isDark: isDark,
        title: 'No CBT plan yet',
        subtitle:
            'Complete a screening session first. When EMLY creates your personalized CBT plan, your activities will appear here.',
        buttonText: 'Start Session',
        onTap: () {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.chat,
            arguments: {'startFresh': true},
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCbtPlan,
      child: Scrollbar(
        thumbVisibility: true,
        radius: const Radius.circular(10),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroPlanCard(
                isDark: isDark,
                plan: _plan!,
                summary: _summary,
                progressText: _overallProgressText,
                progress: _overallProgress,
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      isDark: isDark,
                      iconPath: 'assets/images/Fire.png',
                      title: 'Streak',
                      value:
                          '$_bestStreak ${_bestStreak == 1 ? 'Day' : 'Days'}',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      isDark: isDark,
                      iconPath: 'assets/images/Tick2.png',
                      title: 'Today',
                      value: '$_todayCompletions Done',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      isDark: isDark,
                      iconPath: 'assets/images/Mood.png',
                      title: 'Mood',
                      value: _moodDisplay,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              const Text(
                "Today's Activities",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 8),

              ..._activities.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _ActivityTile(
                    item: item,
                    isDark: isDark,
                    progressTextOverride: _activityProgressText(item),
                    isCompletedOverride: _activityShouldShowCheck(item),
                    showFlameOverride: _activityShouldShowFlame(item),
                    onTap: () => _openActivity(item),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: PrimaryButton(
                  text: 'View Full Evaluation',
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.progressEvaluation,
                      arguments: {
                        'evaluation': _evaluation,
                        'activities': _activities,
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _CbtEmptyState extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onTap;

  const _CbtEmptyState({
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/Robot2.png',
              width: 138,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: onSurface.withOpacity(0.62),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: PrimaryButton(text: buttonText, onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────
/// HERO CARD
/// ─────────────────────────────────────────

class _HeroPlanCard extends StatelessWidget {
  final bool isDark;
  final TherapyPlan plan;
  final TherapyProgressSummary? summary;
  final String progressText;
  final double progress;

  const _HeroPlanCard({
    required this.isDark,
    required this.plan,
    required this.summary,
    required this.progressText,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final streak = summary?.bestStreak ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 20, 26),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STAGE · ${plan.stageLabel}',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.45),
              height: 1.0,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            plan.heroTitle,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 28,
              fontWeight: FontWeight.w500,
              height: 1.25,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            streak > 0
                ? 'You have shown up $streak consecutive ${streak == 1 ? 'day' : 'days'}\nthat matters'
                : plan.planSummary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.35,
              color: Colors.white.withOpacity(0.95),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ProgressBadge(progress: progress),
              const SizedBox(width: 18),
              Text(
                progressText,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  final double progress;

  const _ProgressBadge({required this.progress});

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0);
    final percent = (safeProgress * 100).round();

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              value: safeProgress,
              strokeWidth: 4,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          Text(
            '$percent%',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────
/// STAT CARD
/// ─────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final bool isDark;
  final String iconPath;
  final String title;
  final String value;

  const _StatCard({
    required this.isDark,
    required this.iconPath,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(iconPath, width: 20, height: 20, fit: BoxFit.contain),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.48),
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────
/// ACTIVITY TILE
/// ─────────────────────────────────────────
class _ActivityTile extends StatelessWidget {
  final TherapyActivity item;
  final bool isDark;
  final String progressTextOverride;
  final bool isCompletedOverride;
  final bool showFlameOverride;
  final VoidCallback? onTap;

  const _ActivityTile({
    required this.item,
    required this.isDark,
    required this.progressTextOverride,
    required this.showFlameOverride,
    required this.isCompletedOverride,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final tileColor = isDark
        ? const Color(0xFF2B2B2B)
        : const Color(0xFFF4F7FD);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 2),
            _ActivityLeading(isCompleted: isCompletedOverride, color: primary),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                            ),
                          ),
                        ),
                        if (progressTextOverride.trim().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            progressTextOverride,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.55),
                              height: 1.0,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ActivityTrailing(
              frequency: item.frequency,
              streakCount: item.streakCount,
              showFlame: showFlameOverride,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityLeading extends StatelessWidget {
  final bool isCompleted;
  final Color color;

  const _ActivityLeading({required this.isCompleted, required this.color});

  @override
  Widget build(BuildContext context) {
    if (isCompleted) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const Icon(Icons.check, size: 14, color: Colors.white),
      );
    }

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}

class _ActivityTrailing extends StatelessWidget {
  final String frequency;
  final int? streakCount;
  final bool showFlame;
  final bool isDark;

  const _ActivityTrailing({
    required this.frequency,
    required this.streakCount,
    required this.showFlame,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final shouldShowFlame = showFlame && (streakCount ?? 0) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          frequency,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: primary,
            height: 1.0,
          ),
        ),
        if (shouldShowFlame) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/Fire.png',
                width: 16,
                height: 16,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 2),
              Text(
                '${streakCount ?? ''}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: primary,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CbtDashboardSkeleton extends StatelessWidget {
  final bool isDark;

  const _CbtDashboardSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
      highlightColor: isDark
          ? const Color(0xFF3A3A3A)
          : const Color(0xFFF6F8FC),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SkeletonBox(width: double.infinity, height: 210, radius: 18),

            const SizedBox(height: 14),

            Row(
              children: const [
                Expanded(child: _SkeletonBox(height: 82, radius: 8)),
                SizedBox(width: 16),
                Expanded(child: _SkeletonBox(height: 82, radius: 8)),
                SizedBox(width: 16),
                Expanded(child: _SkeletonBox(height: 82, radius: 8)),
              ],
            ),

            const SizedBox(height: 18),

            const _SkeletonBox(width: 160, height: 18, radius: 6),

            const SizedBox(height: 12),

            const _ActivityTileSkeleton(),
            const SizedBox(height: 6),
            const _ActivityTileSkeleton(),
            const SizedBox(height: 6),
            const _ActivityTileSkeleton(),
            const SizedBox(height: 6),
            const _ActivityTileSkeleton(),
            const SizedBox(height: 6),
            const _ActivityTileSkeleton(),

            const SizedBox(height: 22),

            const _SkeletonBox(width: double.infinity, height: 54, radius: 14),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ActivityTileSkeleton extends StatelessWidget {
  const _ActivityTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SizedBox(width: 2),
          _SkeletonCircle(size: 20),
          SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: double.infinity, height: 14, radius: 5),
                SizedBox(height: 8),
                _SkeletonBox(width: 190, height: 12, radius: 5),
              ],
            ),
          ),

          SizedBox(width: 12),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _SkeletonBox(width: 54, height: 12, radius: 5),
              SizedBox(height: 8),
              _SkeletonBox(width: 32, height: 12, radius: 5),
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

class _SkeletonCircle extends StatelessWidget {
  final double size;

  const _SkeletonCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
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
