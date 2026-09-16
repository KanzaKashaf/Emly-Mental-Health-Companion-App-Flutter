import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/cbt_activity_saved_dialog.dart';
import '../../widgets/cbt_info_dialog.dart';
import '../../widgets/cbt_info_content.dart';
import '../../widgets/cbt_activity_history_section.dart';
import '../../widgets/cbt_activity_lock_utils.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';
import '../../../../core/data/repositories/therapy_repository.dart';

class SleepHabitsScreen extends StatefulWidget {
  const SleepHabitsScreen({super.key});

  @override
  State<SleepHabitsScreen> createState() => _SleepHabitsScreenState();
}

class _SleepHabitsScreenState extends State<SleepHabitsScreen> {
  bool _argsRead = false;
  bool _loading = true;
  bool _submitting = false;
  bool _showHistory = false;
  bool _forceCompletedToday = false;
  bool? _completedTodayHint;
  bool _completedThisWeekHint = false;

  String? _activityId;
  String _title = 'Sleep Habits';
  String _subtitle = 'Build these habits each night.';

  List<_SleepHabitItem> _habits = [];
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
      // Fallback: if screen was opened directly without route args,
      // find Sleep activity from active therapy plan.
      if (_activityId == null || _activityId!.trim().isEmpty) {
        final plan = await AppServices.therapyRepository.getPlan();

        TherapyActivity? sleepActivity;

        if (plan != null) {
          for (final activity in plan.activities) {
            final type = activity.type.toLowerCase();
            final title = activity.title.toLowerCase();

            if (type.contains('sleep') || title.contains('sleep')) {
              sleepActivity = activity;
              break;
            }
          }
        }

        if (sleepActivity != null) {
          _activityId = sleepActivity.id;
          _title = sleepActivity.title;
          _subtitle = sleepActivity.subtitle;
          _habits = _habitsFromContent(sleepActivity.content);
          _completedTodayHint = sleepActivity.isCompletedToday;
          _completedThisWeekHint =
              sleepActivity.isCompletedToday ||
              ((sleepActivity.progressText ?? '').contains(
                RegExp(r'[1-9]\d*\s*/'),
              ));
        }
      }

      if (_habits.isEmpty) {
        _habits = _defaultHabits();
      }

      if (_activityId != null && _activityId!.trim().isNotEmpty) {
        _history = await AppServices.therapyRepository.getActivityHistory(
          _activityId!,
        );
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
        _syncLockedInputsFromTodayHistory();
      });
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() {
        if (_habits.isEmpty) {
          _habits = _defaultHabits();
        }
        _loading = false;
      });

      _showError(
        e.message.isNotEmpty ? e.message : 'Failed to load Sleep Habits.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (_habits.isEmpty) {
          _habits = _defaultHabits();
        }
        _loading = false;
      });

      _showError('Failed to load Sleep Habits.');
    }
  }

  List<_SleepHabitItem> _habitsFromContent(Map<String, dynamic> content) {
    final rawList = content['habits'] ??
        content['items'] ??
        content['checklist'] ??
        content['sleep_habits'] ??
        content['sleepHabits'];

    if (rawList is! List) return [];

    return rawList.asMap().entries.map((entry) {
      final item = entry.value;

      if (item is Map) {
        return _SleepHabitItem(
          title: (item['title'] ??
                  item['label'] ??
                  item['text'] ??
                  'Sleep habit ${entry.key + 1}')
              .toString(),
          isChecked: false,
        );
      }

      return _SleepHabitItem(
        title: item.toString(),
        isChecked: false,
      );
    }).where((e) => e.title.trim().isNotEmpty).toList();
  }

  List<_SleepHabitItem> _defaultHabits() {
    return const [
      _SleepHabitItem(
        title: 'Same Bedtime',
        isChecked: false,
      ),
      _SleepHabitItem(
        title: 'No screens 30min before bed',
        isChecked: false,
      ),
      _SleepHabitItem(
        title: 'Cool dark room',
        isChecked: false,
      ),
    ];
  }

  void _toggleHabit(int index) {
    if (_submitting || _completedToday) return;

    setState(() {
      _habits[index] = _habits[index].copyWith(
        isChecked: !_habits[index].isChecked,
      );
    });
  }

  List<int> get _selectedIndices {
    final selected = <int>[];

    for (int i = 0; i < _habits.length; i++) {
      if (_habits[i].isChecked) {
        selected.add(i);
      }
    }

    return selected;
  }

  Future<void> _submit() async {
    if (_submitting) return;

    if (_completedToday) {
      _showError(CbtActivityLockUtils.completedTodayMessage());
      return;
    }

    final activityId = _activityId;

    if (activityId == null || activityId.trim().isEmpty) {
      _showError('Activity is missing. Please open it from your CBT plan again.');
      return;
    }

    final completedItems = _selectedIndices;

    if (completedItems.isEmpty) {
      _showError('Select at least one sleep habit before submitting.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final result = await AppServices.therapyRepository.submitProgress(
        activityId: activityId,
        responseData: {
          'completed_items': completedItems,
        },
      );

      final updatedHistory =
          await AppServices.therapyRepository.getActivityHistory(activityId);

      if (!mounted) return;

      setState(() {
        _history = updatedHistory;
        _forceCompletedToday = true;
        _completedTodayHint = true;
        _completedThisWeekHint = true;
        _submitting = false;
        _syncLockedInputsFromTodayHistory();
      });

      CbtActivitySavedDialog.show(
        context: context,
        type: CbtSavedDialogType.daily,
        activityName: 'Sleep Habits',
        streakDays: result.streakCount,
        onDone: () {
          Navigator.pushReplacementNamed(context, AppRoutes.cbt);
        },
      );
    } on ApiError catch (e) {
      if (!mounted) return;

      final message = e.message.isNotEmpty
          ? e.message
          : 'Failed to submit Sleep Habits.';

      if (CbtActivityLockUtils.isDailyLimitError(message)) {
        try {
          final updatedHistory =
              await AppServices.therapyRepository.getActivityHistory(activityId);

          if (!mounted) return;

          setState(() {
            _history = updatedHistory;
            _forceCompletedToday = true;
            _completedTodayHint = true;
            _completedThisWeekHint = true;
            _submitting = false;
            _syncLockedInputsFromTodayHistory();
          });
        } catch (_) {
          if (!mounted) return;

          setState(() {
            _forceCompletedToday = true;
            _completedTodayHint = true;
            _completedThisWeekHint = true;
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
      _showError('Failed to submit Sleep Habits.');
    }
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

  bool get _completedToday {
    return _forceCompletedToday ||
        _completedTodayHint == true ||
        _hasTodayHistoryEntry;
  }

  List<CbtActivityHistoryViewItem> get _historyViewItems {
    return _history.map((entry) {
      final completedIndices = _completedIndicesFromHistory(entry);

      final score = _historyScore(entry);
      final maxScore = _historyMaxScore(entry);
      final interpretation = _historyInterpretation(entry);
      final note = _historyNote(entry);

      final lines = <String>[];

      for (final index in completedIndices) {
        lines.add('✓ ${_habits[index].title}');
      }

      if (interpretation != null) {
        lines.add('Interpretation: $interpretation');
      }

      return CbtActivityHistoryViewItem(
        dateLabel: _historyDateLabel(entry.completedAt),
        trailingText: '$score Done',
        lines: lines,
        note: note ?? '$score/$maxScore habits completed',
      );
    }).toList();
  }

  List<int> _completedIndicesFromHistory(TherapyActivityHistoryItem item) {
    final raw = item.responseData['completed_items'] ??
        item.responseData['completedItems'];

    if (raw is! List) return [];

    return raw
        .map((e) => int.tryParse(e.toString()))
        .whereType<int>()
        .where((index) => index >= 0 && index < _habits.length)
        .toList();
  }

  int _historyScore(TherapyActivityHistoryItem item) {
    final rawScore = item.responseData['_score'];

    if (rawScore is int) return rawScore;

    final parsed = int.tryParse((rawScore ?? '').toString());
    if (parsed != null) return parsed;

    return _completedIndicesFromHistory(item).length;
  }

  int _historyMaxScore(TherapyActivityHistoryItem item) {
    final rawMax = item.responseData['_max_score'];

    if (rawMax is int) return rawMax;

    final parsed = int.tryParse((rawMax ?? '').toString());
    if (parsed != null) return parsed;

    return _habits.length;
  }

  String? _historyInterpretation(TherapyActivityHistoryItem item) {
    final raw = item.responseData['_interpretation'];

    if (raw == null) return null;

    final text = raw.toString().trim();
    if (text.isEmpty || text == 'null') return null;

    return text;
  }

  String? _historyNote(TherapyActivityHistoryItem item) {
    final responseNote = item.responseData['note']?.toString();
    final entryNote = item.notes;

    final note = responseNote != null && responseNote.trim().isNotEmpty
        ? responseNote.trim()
        : entryNote?.trim();

    if (note == null || note.isEmpty || note == 'null') return null;

    return note;
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
    final rawProgress = args['progressText'] ??
        args['weeklyProgress'] ??
        args['progress'] ??
        args['completionText'];

    final text = (rawProgress ?? '').toString().trim();

    final match = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(text);

    if (match != null) {
      final completed = int.tryParse(match.group(1) ?? '') ?? 0;
      return completed > 0;
    }

    final rawCount = args['completedThisWeek'] ??
        args['completionsThisWeek'] ??
        args['weeklyCompletions'] ??
        args['currentWeekCompletions'];

    if (rawCount == null) return false;

    if (rawCount is num) return rawCount > 0;

    return (int.tryParse(rawCount.toString()) ?? 0) > 0;
  }

  void _readRouteArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is! Map) return;

    _activityId = args['activityId']?.toString();
    _title = (args['title'] ?? 'Sleep Habits').toString();
    _subtitle = (args['subtitle'] ?? 'Build these habits each night.').toString();

    final content = args['content'];

    if (content is Map) {
      _habits = _habitsFromContent(
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

  void _syncLockedInputsFromTodayHistory() {
    if (!_completedToday) return;

    TherapyActivityHistoryItem? todayEntry = _todayHistoryEntry;

    if (todayEntry == null && _completedTodayHint == true && _history.isNotEmpty) {
      todayEntry = _history.first;
    }

    if (todayEntry == null) return;

    final completedIndices = _completedIndicesFromHistory(todayEntry).toSet();

    if (completedIndices.isEmpty) return;

    _habits = List.generate(
      _habits.length,
      (index) => _habits[index].copyWith(
        isChecked: completedIndices.contains(index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completedTodayForUi = _completedToday;
    final showHistorySkeleton =
        _completedThisWeekHint || completedTodayForUi;

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
                          title: CbtInfoContent.sleepHabitsTitle,
                          description: CbtInfoContent.sleepHabitsDescription,
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
                    ? _SleepHabitsSkeleton(
                        isDark: isDark,
                        completedToday: completedTodayForUi,
                        showHistorySkeleton: showHistorySkeleton,
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _subtitle,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.35,
                                color: isDark
                                    ? Colors.white.withOpacity(0.42)
                                    : Colors.black.withOpacity(0.38),
                              ),
                            ),

                            const SizedBox(height: 38),

                            Opacity(
                              opacity: completedTodayForUi ? 0.45 : 1,
                              child: Column(
                                children: List.generate(
                                  _habits.length,
                                  (index) => Padding(
                                    padding: EdgeInsets.only(
                                      bottom: index == _habits.length - 1 ? 0 : 10,
                                    ),
                                    child: _SleepHabitTile(
                                      title: _habits[index].title,
                                      isChecked: _habits[index].isChecked,
                                      isDark: isDark,
                                      onTap: () => _toggleHabit(index),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            CbtActivityHistorySection(
                              isDark: isDark,
                              entries: _historyViewItems,
                              showHistory: _showHistory,
                              onToggle: () {
                                setState(() {
                                  _showHistory = !_showHistory;
                                });
                              },
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
              ),

              if (completedTodayForUi)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    CbtActivityLockUtils.completedTodayMessage(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      height: 1.35,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: Opacity(
                    opacity: (_submitting || completedTodayForUi) ? 0.5 : 1,
                    child: IgnorePointer(
                      ignoring: _submitting || completedTodayForUi,
                      child: PrimaryButton(
                        text: completedTodayForUi
                            ? 'Completed Today'
                            : _submitting
                                ? 'Submitting...'
                                : 'Submit Response',
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

class _SleepHabitTile extends StatelessWidget {
  final String title;
  final bool isChecked;
  final bool isDark;
  final VoidCallback onTap;

  const _SleepHabitTile({
    required this.title,
    required this.isChecked,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 73,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _SleepCheckbox(
              isChecked: isChecked,
              color: primary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white : const Color(0xFF2F2F2F),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepCheckbox extends StatelessWidget {
  final bool isChecked;
  final Color color;

  const _SleepCheckbox({
    required this.isChecked,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: Center(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: isChecked ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(1),
            border: isChecked
                ? null
                : Border.all(
                    color: color,
                    width: 1.4,
                  ),
          ),
          child: isChecked
              ? const Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}

class _SleepHabitsSkeleton extends StatelessWidget {
  final bool isDark;
  final bool completedToday;
  final bool showHistorySkeleton;

  const _SleepHabitsSkeleton({
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
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SkeletonBox(width: 160, height: 26, radius: 8),

            const SizedBox(height: 4),

            const _SkeletonBox(width: 230, height: 19, radius: 6),

            const SizedBox(height: 38),

            Opacity(
              opacity: completedToday ? 0.45 : 1,
              child: const Column(
                children: [
                  _SleepHabitTileSkeleton(),
                  SizedBox(height: 10),
                  _SleepHabitTileSkeleton(),
                  SizedBox(height: 10),
                  _SleepHabitTileSkeleton(),
                  SizedBox(height: 10),
                  _SleepHabitTileSkeleton(),
                  SizedBox(height: 10),
                  _SleepHabitTileSkeleton(),
                  SizedBox(height: 10),
                  _SleepHabitTileSkeleton(),
                ],
              ),
            ),

            if (showHistorySkeleton) ...[
              const SizedBox(height: 24),

              const _SkeletonBox(width: 170, height: 18, radius: 6),

              const SizedBox(height: 14),

              const _SleepHistoryPreviewSkeleton(),

              const SizedBox(height: 24),
            ] else ...[
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _SleepHabitTileSkeleton extends StatelessWidget {
  const _SleepHabitTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 73,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          _SkeletonBox(width: 18, height: 18, radius: 2),
          SizedBox(width: 14),
          Expanded(
            child: _SkeletonBox(height: 16, radius: 6),
          ),
        ],
      ),
    );
  }
}

class _SleepHistoryPreviewSkeleton extends StatelessWidget {
  const _SleepHistoryPreviewSkeleton();

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
          Expanded(child: _SkeletonBox(height: 16, radius: 6)),
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

class _SleepHabitItem {
  final String title;
  final bool isChecked;

  const _SleepHabitItem({
    required this.title,
    required this.isChecked,
  });

  _SleepHabitItem copyWith({
    String? title,
    bool? isChecked,
  }) {
    return _SleepHabitItem(
      title: title ?? this.title,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}
