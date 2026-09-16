import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';
import '../../widgets/cbt_info_dialog.dart';
import '../../widgets/cbt_info_content.dart';
import '../../widgets/cbt_activity_saved_dialog.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/cbt_activity_lock_utils.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';
import '../../../../core/data/repositories/therapy_repository.dart';

class ThinkingTrapsScreen extends StatefulWidget {
  const ThinkingTrapsScreen({super.key});

  @override
  State<ThinkingTrapsScreen> createState() => _ThinkingTrapsScreenState();
}

class _ThinkingTrapsScreenState extends State<ThinkingTrapsScreen> {
  bool _argsRead = false;
  bool _loading = true;
  bool _refreshing = false;
  bool _submitting = false;
  bool _forceCompletedToday = false;
  bool? _completedTodayHint;
  bool _completedThisWeekHint = false;

  static const int _targetCompletionsForPlan = 3;

  String? _activityId;
  String _title = 'Thinking Traps';

  List<_ThinkingTrapItem> _items = [];
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

  int _thoughtRecordCount = 0;

  int _currentIndex = 0;
  bool _showReframe = false;

  final Set<int> _reviewedIndexes = {};

  bool get _showPersonalizeCard => _thoughtRecordCount >= 3;

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
    return 'Thinking Traps target is already completed for this CBT plan. You can continue when your plan renews.';
  }

  int get _reviewedCount => _reviewedIndexes.length;

  bool get _canSubmitReview {
    return !_loading &&
        !_submitting &&
        !_refreshing &&
        !_lockedForUi &&
        _reviewedCount > 0;
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
      TherapyPlan? plan;

      if (_activityId == null ||
          _activityId!.trim().isEmpty ||
          _items.isEmpty) {
        plan = await AppServices.therapyRepository.getPlan();

        final thinkingActivity = _findThinkingTrapsActivity(plan);

        if (thinkingActivity != null) {
          _activityId = thinkingActivity.id;
          _title = thinkingActivity.title;
          _items = _cardsFromContent(thinkingActivity.content);
          _completedTodayHint = thinkingActivity.isCompletedToday;
          _completedThisWeekHint =
              thinkingActivity.isTargetCompleted ||
              _readCurrentWeekProgressHint(thinkingActivity.toRouteArgs());
        }
      } else {
        // Still load plan because this screen needs thought-record count.
        plan = await AppServices.therapyRepository.getPlan();
      }

      if (_items.isEmpty) {
        _items = _defaultCards();
      }

      if (_currentIndex >= _items.length) {
        _currentIndex = 0;
      }

      if (_activityId != null && _activityId!.trim().isNotEmpty) {
        _history = await AppServices.therapyRepository.getActivityHistory(
          _activityId!,
        );
      }

      _thoughtRecordCount = await _loadThoughtRecordCount(plan);

      if (!mounted) return;

      setState(() {
        _completedThisWeekHint =
            _completedThisWeekHint || _history.length >= _targetCompletionsForPlan;

        _loading = false;

        if (_items.isNotEmpty && !_lockedForUi) {
          _reviewedIndexes.add(_currentIndex);
        }
      });
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() {
        if (_items.isEmpty) {
          _items = _defaultCards();
        }
        _loading = false;
      });

      _showError(
        e.message.isNotEmpty ? e.message : 'Failed to load Thinking Traps.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (_items.isEmpty) {
          _items = _defaultCards();
        }
        _loading = false;
      });

      _showError('Failed to load Thinking Traps.');
    }
  }

  TherapyActivity? _findThinkingTrapsActivity(TherapyPlan? plan) {
    if (plan == null) return null;

    for (final activity in plan.activities) {
      final type = activity.type.toLowerCase();
      final title = activity.title.toLowerCase();

      if (type.contains('thinking') ||
          type.contains('trap') ||
          type.contains('distortion') ||
          title.contains('thinking traps') ||
          title.contains('traps')) {
        return activity;
      }
    }

    return null;
  }

  TherapyActivity? _findThoughtRecordActivity(TherapyPlan? plan) {
    if (plan == null) return null;

    for (final activity in plan.activities) {
      final type = activity.type.toLowerCase();
      final title = activity.title.toLowerCase();

      if (type.contains('thought_record') ||
          type.contains('thought record') ||
          title.contains('thought record')) {
        return activity;
      }
    }

    for (final activity in plan.activities) {
      final type = activity.type.toLowerCase();
      final title = activity.title.toLowerCase();

      if (type.contains('thought') || title.contains('thought')) {
        return activity;
      }
    }

    return null;
  }

  Future<int> _loadThoughtRecordCount(TherapyPlan? plan) async {
    try {
      final thoughtActivity = _findThoughtRecordActivity(plan);
      final thoughtActivityId = thoughtActivity?.id;

      if (thoughtActivityId == null || thoughtActivityId.trim().isEmpty) {
        return 0;
      }

      final thoughtHistory =
          await AppServices.therapyRepository.getActivityHistory(
        thoughtActivityId,
      );

      return thoughtHistory.length;
    } catch (_) {
      return 0;
    }
  }

  List<_ThinkingTrapItem> _cardsFromContent(Map<String, dynamic> content) {
    final rawList = content['cards'] ??
        content['traps'] ??
        content['items'] ??
        content['thinking_traps'] ??
        content['thinkingTraps'];

    if (rawList is! List) return [];

    return rawList
        .map((item) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);

            return _ThinkingTrapItem(
              distortion: (map['distortion'] ??
                      map['title'] ??
                      map['trap'] ??
                      map['name'] ??
                      'Thinking Trap')
                  .toString(),
              thought: (map['thought'] ??
                      map['automatic_thought'] ??
                      map['automaticThought'] ??
                      map['original'] ??
                      map['example'] ??
                      '')
                  .toString(),
              reframe: (map['reframe'] ??
                      map['balanced_thought'] ??
                      map['balancedThought'] ??
                      map['replacement'] ??
                      '')
                  .toString(),
            );
          }

          return null;
        })
        .whereType<_ThinkingTrapItem>()
        .where((item) =>
            item.distortion.trim().isNotEmpty &&
            item.thought.trim().isNotEmpty &&
            item.reframe.trim().isNotEmpty)
        .toList();
  }

  List<_ThinkingTrapItem> _defaultCards() {
    return const [
      _ThinkingTrapItem(
        distortion: 'All-or-Nothing Thinking',
        thought: 'If I don’t do this perfectly, I’m a complete failure.',
        reframe:
            'Doing something imperfectly is still progress and still counts.',
      ),
      _ThinkingTrapItem(
        distortion: 'Catastrophizing',
        thought: 'I failed once so I’m a total failure.',
        reframe:
            'One setback doesn’t define me. I’ve done well before and can again.',
      ),
      _ThinkingTrapItem(
        distortion: 'Mind Reading',
        thought: 'They didn’t reply, so they must be upset with me.',
        reframe: 'There could be many reasons they haven’t replied yet.',
      ),
      _ThinkingTrapItem(
        distortion: 'Overgeneralization',
        thought: 'Nothing ever works out for me.',
        reframe: 'Some things have gone badly, but not everything always does.',
      ),
      _ThinkingTrapItem(
        distortion: 'Labeling',
        thought: 'I made a mistake, so I’m stupid.',
        reframe: 'Making a mistake means I’m human, not that I am the mistake.',
      ),
    ];
  }

  void _markCurrentCardReviewed() {
    if (_items.isEmpty || _lockedForUi) return;

    setState(() {
      _reviewedIndexes.add(_currentIndex);
    });
  }

  void _toggleCard() {
    if (_loading || _items.isEmpty || _lockedForUi || _submitting) return;

    final wasShowingFront = !_showReframe;

    setState(() {
      _showReframe = !_showReframe;
    });

    // Count as reviewed ONLY when user taps front card to see reframe.
    // If user taps again to return to original thought, don't count again.
    if (wasShowingFront) {
      _markCurrentCardReviewed();
    }
  }

  void _goNext() {
    if (_loading || _items.isEmpty || _submitting) return;

    setState(() {
      _currentIndex = (_currentIndex + 1) % _items.length;
      _showReframe = false;
    });

    // Important:
    // Do NOT mark reviewed here.
    // Skipping card without tapping reframe should not count.
  }

  void _goPrevious() {
    if (_loading || _items.isEmpty || _submitting) return;

    setState(() {
      _currentIndex = (_currentIndex - 1 + _items.length) % _items.length;
      _showReframe = false;
    });

    // Important:
    // Do NOT mark reviewed here.
  }

  Future<void> _submitCardsReviewedIfNeeded() async {
    if (!_canSubmitReview) return;

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
          'cards_reviewed': _reviewedCount,
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
        activityName: 'Thinking Traps',
        streakDays: result.streakCount,
        onDone: () {
          Navigator.pushReplacementNamed(context, AppRoutes.cbt);
        },
      );
    } on ApiError catch (e) {
      if (!mounted) return;

      final message = e.message.isNotEmpty
          ? e.message
          : 'Failed to save Thinking Traps.';

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
      _showError('Failed to save Thinking Traps.');
    }
  }

  Future<void> _refreshPersonalizedCards() async {
    if (_refreshing || _lockedForUi) return;

    final activityId = _activityId;

    if (activityId == null || activityId.trim().isEmpty) {
      _showError('Activity is missing. Please open it from your CBT plan again.');
      return;
    }

    setState(() => _refreshing = true);

    try {
      final data =
          await AppServices.therapyRepository.refreshActivityCards(activityId);

      final refreshed = data['refreshed'] == true;

      final cards = _cardsFromRefreshResponse(data);

      if (!mounted) return;

      if (cards.isNotEmpty) {
        setState(() {
          _items = cards;
          _currentIndex = 0;
          _showReframe = false;
          _reviewedIndexes.clear();
          _refreshing = false;
        });
      } else {
        setState(() => _refreshing = false);
      }

      if (refreshed) {
        _showSuccess('Cards refreshed from your thought records.');
      } else {
        _showError(
          'Personalized cards are not ready yet. Complete at least 3 thought records.',
        );
      }
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() => _refreshing = false);

      _showError(
        e.message.isNotEmpty ? e.message : 'Failed to refresh cards.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _refreshing = false);
      _showError('Failed to refresh cards.');
    }
  }

  List<_ThinkingTrapItem> _cardsFromRefreshResponse(
    Map<String, dynamic> data,
  ) {
    final content = data['content'];

    if (content is Map) {
      final parsed = _cardsFromContent(Map<String, dynamic>.from(content));
      if (parsed.isNotEmpty) return parsed;
    }

    final activity = data['activity'];

    if (activity is Map) {
      final activityContent = activity['content'];
      if (activityContent is Map) {
        final parsed = _cardsFromContent(
          Map<String, dynamic>.from(activityContent),
        );
        if (parsed.isNotEmpty) return parsed;
      }
    }

    final cards = data['cards'] ??
        data['traps'] ??
        data['items'] ??
        data['thinking_traps'] ??
        data['thinkingTraps'];

    if (cards is List) {
      return _cardsFromContent({'cards': cards});
    }

    return [];
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

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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

  void _readRouteArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is! Map) return;

    _activityId = args['activityId']?.toString();
    _title = (args['title'] ?? 'Thinking Traps').toString();

    final content = args['content'];

    if (content is Map) {
      _items = _cardsFromContent(
        Map<String, dynamic>.from(content),
      );
    }

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lockedForUi = _lockedForUi;
    final completedTodayForUi = _completedToday;

    final item = _items.isNotEmpty
        ? _items[_currentIndex]
        : const _ThinkingTrapItem(
            distortion: 'Thinking Trap',
            thought: 'Loading...',
            reframe: 'Loading...',
          );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, AppRoutes.cbt);
        }
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              Row(
                children: [
                  IconButton(
                    onPressed: _submitting || _refreshing
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
                          title: CbtInfoContent.thinkingTrapsTitle,
                          description:
                              CbtInfoContent.thinkingTrapsDescription,
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

              const SizedBox(height: 18),

              Expanded(
                child: _loading
                    ? _ThinkingTrapsSkeleton(
                        isDark: isDark,
                        completedToday: lockedForUi,
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            Opacity(
                              opacity: lockedForUi ? 0.45 : 1,
                              child: GestureDetector(
                                onTap: lockedForUi ? null : _toggleCard,
                                child: _ThinkingTrapCard(
                                  isDark: isDark,
                                  item: item,
                                  showReframe: _showReframe,
                                ),
                              ),
                            ),

                            const SizedBox(height: 13),

                            SizedBox(
                              height: 46,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Opacity(
                                    opacity: completedTodayForUi ? 0.45 : 1,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _ArrowCircleButton(
                                          isDark: isDark,
                                          icon: Icons.chevron_left,
                                          onTap: lockedForUi
                                              ? () {}
                                              : _goPrevious,
                                        ),
                                        const SizedBox(width: 20),
                                        _ArrowCircleButton(
                                          isDark: isDark,
                                          icon: Icons.chevron_right,
                                          onTap:
                                              lockedForUi ? () {} : _goNext,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    right: 2,
                                    top: 10,
                                    child: Text(
                                      '${_currentIndex + 1}/${_items.length}',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white.withOpacity(0.65)
                                            : Colors.black.withOpacity(0.45),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),

                            if (_showPersonalizeCard) ...[
                              _PersonalizeCard(
                                isDark: isDark,
                                thoughtRecordCount: _thoughtRecordCount,
                                isRefreshing: _refreshing,
                                onRefreshTap: _refreshPersonalizedCards,
                              ),
                              const SizedBox(height: 12),
                            ],

                            Text(
                              lockedForUi
                                ? completedTodayForUi
                                    ? CbtActivityLockUtils.completedTodayMessage()
                                    : _targetCompletedMessage
                                : _reviewedCount == 0
                                    ? 'Tap a card to see its reframe before submitting.'
                                    : '$_reviewedCount card${_reviewedCount == 1 ? '' : 's'} reviewed.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                height: 1.35,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                              ),
                            ),

                            const SizedBox(height: 10),

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: Opacity(
                                opacity: _canSubmitReview ? 1 : 0.5,
                                child: IgnorePointer(
                                  ignoring: !_canSubmitReview,
                                  child: PrimaryButton(
                                    text: lockedForUi
                                      ? completedTodayForUi
                                          ? 'Completed Today'
                                          : 'Target Completed'
                                      : _submitting
                                          ? 'Saving...'
                                          : _reviewedCount == 0
                                              ? 'Submit Review'
                                              : 'Submit $_reviewedCount Reviewed',
                                    onTap: _submitCardsReviewedIfNeeded,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                          ],
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

class _ThinkingTrapCard extends StatelessWidget {
  final bool isDark;
  final _ThinkingTrapItem item;
  final bool showReframe;

  const _ThinkingTrapCard({
    required this.isDark,
    required this.item,
    required this.showReframe,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor =
        isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final innerColor = isDark
        ? Colors.black.withOpacity(0.12)
        : Colors.white.withOpacity(0.18);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: 0,
        end: showReframe ? 1 : 0,
      ),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        final angle = value * 3.1415926535; // 180 degrees
        final showBackSide = value >= 0.5;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..rotateY(showBackSide ? 3.1415926535 : 0),
            child: _ThinkingTrapCardFace(
              isDark: isDark,
              item: item,
              showReframe: showBackSide,
            ),
          ),
        );
      },
    );
  }
}

class _ThinkingTrapCardFace extends StatelessWidget {
  final bool isDark;
  final _ThinkingTrapItem item;
  final bool showReframe;

  const _ThinkingTrapCardFace({
    required this.isDark,
    required this.item,
    required this.showReframe,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final innerColor = isDark
        ? Colors.black.withOpacity(0.12)
        : Colors.white.withOpacity(0.18);

    return Container(
      width: double.infinity,
      height: 293,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cognitive Distortion',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.distortion,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 25,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              color: innerColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showReframe ? 'REFRAME:' : 'Your Thoughts:',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  showReframe ? item.reframe : '"${item.thought}"',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Center(
            child: Text(
              showReframe
                  ? 'Tap to see Original Thoughts'
                  : 'Tap to Flip Your Thoughts',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowCircleButton extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final VoidCallback onTap;

  const _ArrowCircleButton({
    required this.isDark,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 28,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _PersonalizeCard extends StatelessWidget {
  final bool isDark;
  final int thoughtRecordCount;
  final bool isRefreshing;
  final VoidCallback onRefreshTap;

  const _PersonalizeCard({
    required this.isDark,
    required this.thoughtRecordCount,
    required this.isRefreshing,
    required this.onRefreshTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(
              Icons.auto_awesome,
              size: 22,
              color: primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personalize from your\nthoughts',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have $thoughtRecordCount thought records\nto draw from.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.55,
                      color: isDark
                          ? Colors.white.withOpacity(0.75)
                          : Colors.black.withOpacity(0.52),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: isRefreshing ? null : onRefreshTap,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: primary,
                  disabledBackgroundColor: primary.withOpacity(0.65),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: Text(
                  isRefreshing ? 'Refreshing...' : 'Refresh',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingTrapsSkeleton extends StatelessWidget {
  final bool isDark;
  final bool completedToday;

  const _ThinkingTrapsSkeleton({
    required this.isDark,
    required this.completedToday,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
      highlightColor:
          isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF6F8FC),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Opacity(
              opacity: completedToday ? 0.45 : 1,
              child: const _ThinkingTrapCardSkeleton(),
            ),

            const SizedBox(height: 13),

            SizedBox(
              height: 46,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: completedToday ? 0.45 : 1,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SkeletonCircle(size: 44),
                        SizedBox(width: 20),
                        _SkeletonCircle(size: 44),
                      ],
                    ),
                  ),
                  const Positioned(
                    right: 2,
                    top: 14,
                    child: _SkeletonBox(width: 34, height: 12, radius: 6),
                  ),
                ],
              ),
            ),

            const Spacer(),

            const _SkeletonBox(width: 260, height: 14, radius: 6),

            const SizedBox(height: 10),

            const _SkeletonBox(
              width: double.infinity,
              height: 54,
              radius: 14,
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ThinkingTrapCardSkeleton extends StatelessWidget {
  const _ThinkingTrapCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 293,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkeletonBox(width: 135, height: 12, radius: 6),

          const SizedBox(height: 8),

          const _SkeletonBox(width: 240, height: 30, radius: 8),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 115, height: 14, radius: 6),
                SizedBox(height: 12),
                _SkeletonBox(width: double.infinity, height: 14, radius: 6),
                SizedBox(height: 8),
                _SkeletonBox(width: 230, height: 14, radius: 6),
              ],
            ),
          ),

          const Spacer(),

          const Center(
            child: _SkeletonBox(width: 190, height: 14, radius: 6),
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

class _ThinkingTrapItem {
  final String distortion;
  final String thought;
  final String reframe;

  const _ThinkingTrapItem({
    required this.distortion,
    required this.thought,
    required this.reframe,
  });
}