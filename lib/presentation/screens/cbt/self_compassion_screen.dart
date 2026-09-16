import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';

import '../../widgets/cbt_activity_lock_utils.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/cbt_activity_saved_dialog.dart';
import '../../widgets/cbt_info_dialog.dart';
import '../../widgets/cbt_info_content.dart';
import '../../widgets/cbt_activity_history_section.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';
import '../../../../core/data/repositories/therapy_repository.dart';

class SelfCompassionScreen extends StatefulWidget {
  const SelfCompassionScreen({super.key});

  @override
  State<SelfCompassionScreen> createState() => _SelfCompassionScreenState();
}

class _SelfCompassionScreenState extends State<SelfCompassionScreen> {
  bool _argsRead = false;
  bool _loading = true;
  bool _submitting = false;
  bool _showHistory = false;
  bool _forceCompletedToday = false;
  bool? _completedTodayHint;
  bool _completedThisWeekHint = false;

  String? _activityId;
  String _title = 'Self-Compassion';
  String _subtitle = 'Practice speaking to yourself with kindness.';
  static const int _targetCompletionsForPlan = 3;

  final List<_SelfCompassionStep> _steps = const [
    _SelfCompassionStep(
      title: 'Acknowledge the moment',
      description: 'This is a difficult moment.',
    ),
    _SelfCompassionStep(
      title: 'Remember common humanity',
      description: 'I am not alone in feeling this.',
    ),
    _SelfCompassionStep(
      title: 'Speak kindly to yourself',
      description: 'May I be kind to myself right now.',
    ),
  ];

  List<TherapyActivityHistoryItem> _history = [];

  static const Duration _appUtcOffset = Duration(hours: 5);

  DateTime _appNow() {
    return DateTime.now().toUtc().add(_appUtcOffset);
  }

  DateTime _appDateOnly(DateTime value) {
    final appTime = value.toUtc().add(_appUtcOffset);
    return DateTime(appTime.year, appTime.month, appTime.day);
  }

  DateTime _todayAppDateOnly() {
    final now = _appNow();
    return DateTime(now.year, now.month, now.day);
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isTodayInAppTimezone(DateTime? value) {
    if (value == null) return false;

    return _sameDate(
      _appDateOnly(value),
      _todayAppDateOnly(),
    );
  }

  TherapyActivityHistoryItem? get _todayHistoryEntry {
    for (final item in _history) {
      if (_isTodayInAppTimezone(item.completedAt)) {
        return item;
      }
    }

    return null;
  }

  bool get _hasTodayHistoryEntry {
    return _todayHistoryEntry != null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_argsRead) return;
    _argsRead = true;

    _readRouteArgs();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    setState(() => _loading = true);

    try {
      // Fallback if opened directly without dashboard route args.
      if (_activityId == null || _activityId!.trim().isEmpty) {
        final plan = await AppServices.therapyRepository.getPlan();

        TherapyActivity? selfCompassionActivity;

        if (plan != null) {
          for (final activity in plan.activities) {
            final type = activity.type.toLowerCase();
            final title = activity.title.toLowerCase();

            if (type.contains('self') ||
                type.contains('compassion') ||
                title.contains('self-compassion') ||
                title.contains('self compassion')) {
              selfCompassionActivity = activity;
              break;
            }
          }
        }

        if (selfCompassionActivity != null) {
          _activityId = selfCompassionActivity.id;
          _title = selfCompassionActivity.title;
          _subtitle = selfCompassionActivity.subtitle;
          _completedTodayHint = selfCompassionActivity.isCompletedToday;
          _completedThisWeekHint =
            selfCompassionActivity.isTargetCompleted ||
            _readCurrentWeekProgressHint(selfCompassionActivity.toRouteArgs());
        }
      }

      if (_activityId != null && _activityId!.trim().isNotEmpty) {
        _history = await AppServices.therapyRepository.getActivityHistory(
          _activityId!,
        );
      }

      if (!mounted) return;

      setState(() {
        _completedThisWeekHint =
            _completedThisWeekHint || _history.length >= _targetCompletionsForPlan;
        _loading = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      _showError(
        e.message.isNotEmpty
            ? e.message
            : 'Failed to load Self-Compassion.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showError('Failed to load Self-Compassion.');
    }
  }

  bool get _completedToday {
    return _forceCompletedToday ||
        _completedTodayHint == true ||
        _hasTodayHistoryEntry;
  }

  bool get _completedForCurrentPlan {
    return _completedThisWeekHint || _history.length >= _targetCompletionsForPlan;
  }

  bool get _lockedForUi {
    return _completedToday || _completedForCurrentPlan;
  }

  String get _targetCompletedMessage {
    return 'Self-Compassion target is already completed for this CBT plan. You can continue when your plan renews.';
  }

  void _toggleHistory() {
    setState(() {
      _showHistory = !_showHistory;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;

    if (_completedToday) {
      _showError(CbtActivityLockUtils.completedTodayMessage());
      return;
    }

    if (_completedForCurrentPlan) {
      _showError(_targetCompletedMessage);
      return;
    }

    final activityId = _activityId;

    if (activityId == null || activityId.trim().isEmpty) {
      _showError('Activity is missing. Please open it from your CBT plan again.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final result = await AppServices.therapyRepository.submitProgress(
        activityId: activityId,
        responseData: {
          'completed': true,
        },
      );

      final updatedHistory =
          await AppServices.therapyRepository.getActivityHistory(activityId);

      if (!mounted) return;

      setState(() {
        _history = updatedHistory;
        _forceCompletedToday = true;
        _completedTodayHint = true;
        _completedThisWeekHint =
            updatedHistory.length >= _targetCompletionsForPlan;
        _submitting = false;
      });

      CbtActivitySavedDialog.show(
        context: context,
        type: CbtSavedDialogType.daily,
        activityName: 'Self-Compassion',
        streakDays: result.streakCount,
        onDone: () {
          Navigator.pushReplacementNamed(context, AppRoutes.cbt);
        },
      );
    } on ApiError catch (e) {
      if (!mounted) return;

      final message = e.message.isNotEmpty
          ? e.message
          : 'Failed to save Self-Compassion.';

      if (CbtActivityLockUtils.isDailyLimitError(message)) {
        try {
          final updatedHistory =
              await AppServices.therapyRepository.getActivityHistory(activityId);

          if (!mounted) return;

          setState(() {
            _history = updatedHistory;
            _forceCompletedToday = true;
            _completedTodayHint = true;
            _completedThisWeekHint =
                updatedHistory.length >= _targetCompletionsForPlan;
            _submitting = false;
          });
        } catch (_) {
          if (!mounted) return;

          setState(() {
            _forceCompletedToday = true;
            _forceCompletedToday = true;
            _completedTodayHint = true;
            _submitting = false;
          });
        }
      } else {
        setState(() => _submitting = false);
      }

      _showError(message);
    } catch (_) {
      if (!mounted) return;

      setState(() => _submitting = false);
      _showError('Failed to save Self-Compassion.');
    }
  }

  String _historyDateLabel(DateTime? date) {
    if (date == null) return 'Saved entry';

    final today = _todayAppDateOnly();
    final entryDay = _appDateOnly(date);
    final entryDisplay = date.toUtc().add(_appUtcOffset);

    final diff = today.difference(entryDay).inDays;

    if (diff == 0) {
      return 'Today, ${_formatTime(entryDisplay)}';
    }

    if (diff == 1) {
      return 'Yesterday, ${_formatTime(entryDisplay)}';
    }

    return '${entryDisplay.day.toString().padLeft(2, '0')}/'
        '${entryDisplay.month.toString().padLeft(2, '0')}/'
        '${entryDisplay.year}, ${_formatTime(entryDisplay)}';
  }

  String _formatTime(DateTime date) {
    final hour12 = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour12:$minute $suffix';
  }

  bool _historyCompleted(TherapyActivityHistoryItem item) {
    final raw = item.responseData['completed'];

    if (raw is bool) return raw;

    return raw.toString().toLowerCase() == 'true';
  }

  int _historyScore(TherapyActivityHistoryItem item) {
    final rawScore = item.responseData['_score'];

    if (rawScore is int) return rawScore;
    if (rawScore is double) return rawScore.round();

    final parsed = int.tryParse((rawScore ?? '').toString());
    if (parsed != null) return parsed;

    return _historyCompleted(item) ? 1 : 0;
  }

  int _historyMaxScore(TherapyActivityHistoryItem item) {
    final rawMax = item.responseData['_max_score'];

    if (rawMax is int) return rawMax;
    if (rawMax is double) return rawMax.round();

    final parsed = int.tryParse((rawMax ?? '').toString());
    if (parsed != null) return parsed;

    return 1;
  }

  String? _historyInterpretation(TherapyActivityHistoryItem item) {
    final raw = item.responseData['_interpretation'];

    if (raw == null) return null;

    final text = raw.toString().trim();
    if (text.isEmpty || text == 'null') return null;

    return text;
  }

  List<CbtActivityHistoryViewItem> get _historyViewItems {
    return _history.map((entry) {
      final completed = _historyCompleted(entry);
      final score = _historyScore(entry);
      final maxScore = _historyMaxScore(entry);
      final interpretation = _historyInterpretation(entry);

      final lines = <String>[
        completed
            ? '✓ Self-compassion exercise completed'
            : 'Exercise not marked complete',
      ];

      if (interpretation != null) {
        lines.add('Interpretation: $interpretation');
      }

      return CbtActivityHistoryViewItem(
        dateLabel: _historyDateLabel(entry.completedAt),
        trailingText: completed ? 'Done' : '$score/$maxScore',
        lines: lines,
        note: '$score/$maxScore completed',
      );
    }).toList();
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  bool? _readBoolArg(Map args, List<String> keys) {
    for (final key in keys) {
      final raw = args[key];

      if (raw == null) continue;

      if (raw is bool) return raw;

      if (raw is num) return raw != 0;

      final text = raw.toString().trim().toLowerCase();

      if (text == 'true' ||
          text == '1' ||
          text == 'yes' ||
          text == 'done' ||
          text == 'completed') {
        return true;
      }

      if (text == 'false' ||
          text == '0' ||
          text == 'no' ||
          text == 'pending' ||
          text == 'not_completed') {
        return false;
      }
    }

    return null;
  }

  void _readRouteArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is! Map) return;

    _activityId = args['activityId']?.toString();
    _title = (args['title'] ?? 'Self-Compassion').toString();
    _subtitle = (args['subtitle'] ??
            'Practice speaking to yourself with kindness.')
        .toString();

    _completedTodayHint = _readBoolArg(
      args,
      [
        'isCompletedToday',
        'completedToday',
        'completed_today',
        'is_completed_today',
        'activityCompletedToday',
        'isDoneToday',
        'doneToday',
      ],
    );

    _completedThisWeekHint =
      _completedTodayHint == true || _readCurrentWeekProgressHint(args);
  }

  bool _readCurrentWeekProgressHint(Map args) {
    final targetCompleted = _readBoolArg(
      args,
      [
        'isTargetCompleted',
        'targetCompleted',
        'is_target_completed',
        'completedThisPlan',
        'isCompletedThisPlan',
      ],
    );

    if (targetCompleted != null) return targetCompleted;

    final rawProgress = args['progressText'] ??
        args['weeklyProgress'] ??
        args['progress'] ??
        args['completionText'];

    final text = (rawProgress ?? '').toString().trim();

    final match = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(text);

    if (match != null) {
      final completed = int.tryParse(match.group(1) ?? '') ?? 0;
      final target = int.tryParse(match.group(2) ?? '') ?? 0;

      if (target <= 0) return completed >= _targetCompletionsForPlan;

      return completed >= target;
    }

    final rawCount = args['completedThisWeek'] ??
        args['completionsThisWeek'] ??
        args['weeklyCompletions'] ??
        args['currentWeekCompletions'];

    if (rawCount == null) return false;

    if (rawCount is num) return rawCount >= _targetCompletionsForPlan;

    return (int.tryParse(rawCount.toString()) ?? 0) >=
        _targetCompletionsForPlan;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lockedForUi = _lockedForUi;
    final completedTodayForUi = _completedToday;
    final showHistorySkeleton =
        _completedThisWeekHint || completedTodayForUi || lockedForUi;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, AppRoutes.cbt);
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              Row(
                children: [
                  IconButton(
                    onPressed: _submitting
                        ? null
                        : () {
                            Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.cbt,
                            );
                          },
                    icon: Icon(
                      Icons.arrow_back,
                      size: 26,
                      color: isDark ? Colors.white : const Color(0xFF2F2F2F),
                    ),
                  ),
                  Text(
                    _title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF2F2F2F),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: GestureDetector(
                      onTap: () {
                        CbtInfoDialog.show(
                          context: context,
                          title: CbtInfoContent.selfCompassionTitle,
                          description:
                              CbtInfoContent.selfCompassionDescription,
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        Icons.info_outline,
                        size: 23,
                        color: isDark
                            ? AppColors.primaryDark
                            : AppColors.primaryLight,
                      ),
                    ),
                  ),
                ],
              ),

              Expanded(
                child: _loading
                    ? _SelfCompassionSkeleton(
                        isDark: isDark,
                        completedToday: lockedForUi,
                        showHistorySkeleton: showHistorySkeleton,
                      )
                    : SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Self-Compassion',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              _subtitle,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.35,
                                color: isDark
                                    ? Colors.white.withOpacity(0.42)
                                    : Colors.black.withOpacity(0.42),
                              ),
                            ),

                            const SizedBox(height: 38),

                            Opacity(
                              opacity: lockedForUi ? 0.45 : 1,
                              child: Column(
                                children: List.generate(
                                  _steps.length,
                                  (index) => Padding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          index == _steps.length - 1 ? 0 : 10,
                                    ),
                                    child: _SelfCompassionTile(
                                      number: index + 1,
                                      title: _steps[index].title,
                                      description: _steps[index].description,
                                      isDark: isDark,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            CbtActivityHistorySection(
                              isDark: isDark,
                              entries: _historyViewItems,
                              showHistory: _showHistory,
                              onToggle: _toggleHistory,
                            ),

                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
              ),

              if (lockedForUi)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    completedTodayForUi
                      ? CbtActivityLockUtils.completedTodayMessage()
                      : _targetCompletedMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      height: 1.35,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.55),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: Opacity(
                    opacity: (_submitting || lockedForUi) ? 0.5 : 1,
                    child: IgnorePointer(
                      ignoring: _submitting || lockedForUi,
                      child: PrimaryButton(
                        text: lockedForUi
                            ? 'Completed Today'
                            : _submitting
                                ? 'Saving...'
                                : 'I Have Completed This Exercise',
                        onTap: _submit,
                      ),
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

class _SelfCompassionTile extends StatelessWidget {
  final int number;
  final String title;
  final String description;
  final bool isDark;

  const _SelfCompassionTile({
    required this.number,
    required this.title,
    required this.description,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final numberBg = isDark
        ? AppColors.primaryDark.withOpacity(0.28)
        : AppColors.primaryLight.withOpacity(0.20);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.fromLTRB(10, 14, 14, 14),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              color: numberBg,
              shape: BoxShape.circle,
            ),
            child: Text(
              number.toString(),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.0,
                color: primary,
              ),
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: isDark ? Colors.white : const Color(0xFF2F2F2F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                    color: isDark
                        ? Colors.white.withOpacity(0.72)
                        : const Color(0xFF2F2F2F).withOpacity(0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelfCompassionSkeleton extends StatelessWidget {
  final bool isDark;
  final bool completedToday;
  final bool showHistorySkeleton;

  const _SelfCompassionSkeleton({
    required this.isDark,
    required this.completedToday,
    required this.showHistorySkeleton,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
      highlightColor:
          isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF6F8FC),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SkeletonBox(width: 178, height: 26, radius: 8),

            const SizedBox(height: 6),

            const _SkeletonBox(width: double.infinity, height: 19, radius: 6),

            const SizedBox(height: 38),

            Opacity(
              opacity: completedToday ? 0.45 : 1,
              child: const Column(
                children: [
                  _SelfCompassionTileSkeleton(),
                  SizedBox(height: 10),
                  _SelfCompassionTileSkeleton(),
                  SizedBox(height: 10),
                  _SelfCompassionTileSkeleton(),
                ],
              ),
            ),

            if (showHistorySkeleton) ...[
              const SizedBox(height: 30),

              const _SkeletonBox(width: 170, height: 18, radius: 6),

              const SizedBox(height: 14),

              const _SelfCompassionHistorySkeleton(),

              const SizedBox(height: 100),
            ] else ...[
              const SizedBox(height: 100),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelfCompassionTileSkeleton extends StatelessWidget {
  const _SelfCompassionTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.fromLTRB(10, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 3),
            child: _SkeletonCircle(size: 20),
          ),

          SizedBox(width: 18),

          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(
                    width: double.infinity,
                    height: 21,
                    radius: 6,
                  ),
                  SizedBox(height: 4),
                  _SkeletonBox(
                    width: double.infinity,
                    height: 20,
                    radius: 6,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelfCompassionHistorySkeleton extends StatelessWidget {
  const _SelfCompassionHistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _SkeletonBox(height: 16, radius: 6),
          ),
          SizedBox(width: 20),
          _SkeletonBox(width: 52, height: 16, radius: 6),
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

class _SelfCompassionStep {
  final String title;
  final String description;

  const _SelfCompassionStep({
    required this.title,
    required this.description,
  });
}