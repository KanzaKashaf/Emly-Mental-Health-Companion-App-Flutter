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

class WeeklyReviewScreen extends StatefulWidget {
  const WeeklyReviewScreen({super.key});

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  final ScrollController _scrollController = ScrollController();

  final List<TextEditingController> _answerControllers =
      List.generate(4, (_) => TextEditingController());

  bool _argsRead = false;
  bool _loading = true;
  bool _submitting = false;
  bool _showPastEntries = false;
  bool _forceCompletedToday = false;
  bool? _completedTodayHint;
  bool _completedThisWeekHint = false;

  String? _activityId;
  String _title = 'Weekly Review';
  String _subtitle = 'Look back on the week.';

  final List<_WeeklyReviewQuestion> _questions = const [
    _WeeklyReviewQuestion(
      question: 'Q.1: What went well?',
      historyTitle: 'What went well?',
      hint: 'Write what went well this week...',
    ),
    _WeeklyReviewQuestion(
      question: 'Q.2: What was hard?',
      historyTitle: 'What was hard?',
      hint: 'Write what felt difficult this week...',
    ),
    _WeeklyReviewQuestion(
      question: 'Q.3: What did I learn?',
      historyTitle: 'What did I learn?',
      hint: 'Write what you noticed or learned...',
    ),
    _WeeklyReviewQuestion(
      question: 'Q.4: Goal for next week?',
      historyTitle: 'Goal for next week',
      hint: 'Write one small goal for next week...',
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

  String get _weeklyReviewCompletedMessage {
    return 'Weekly Review is already completed for this CBT plan. You can do it again when your plan renews.';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_argsRead) return;
    _argsRead = true;

    _readRouteArgs();
    _loadActivity();
  }

  @override
  void dispose() {
    _scrollController.dispose();

    for (final controller in _answerControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _loadActivity() async {
    setState(() => _loading = true);

    try {
      // Fallback if opened directly without CBT dashboard route arguments.
      if (_activityId == null || _activityId!.trim().isEmpty) {
        final plan = await AppServices.therapyRepository.getPlan();

        TherapyActivity? weeklyReviewActivity;

        if (plan != null) {
          for (final activity in plan.activities) {
            final type = activity.type.toLowerCase();
            final title = activity.title.toLowerCase();

            if (type.contains('weekly') ||
                type.contains('review') ||
                title.contains('weekly review')) {
              weeklyReviewActivity = activity;
              break;
            }
          }
        }

        if (weeklyReviewActivity != null) {
          _activityId = weeklyReviewActivity.id;
          _title = weeklyReviewActivity.title;
          _subtitle = weeklyReviewActivity.subtitle;
          _completedTodayHint = weeklyReviewActivity.isCompletedToday;
          _completedThisWeekHint =
              weeklyReviewActivity.isCompletedToday ||
              ((weeklyReviewActivity.progressText ?? '').contains(
                RegExp(r'[1-9]\d*\s*/'),
              ));
        }
      }

      if (_activityId != null && _activityId!.trim().isNotEmpty) {
        _history = await AppServices.therapyRepository.getActivityHistory(
          _activityId!,
        );
      }

      if (!mounted) return;

      setState(() {
        _completedThisWeekHint = _completedThisWeekHint || _history.isNotEmpty;
        _loading = false;
        _syncLockedInputsFromTodayHistory();
      });
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      _showError(
        e.message.isNotEmpty ? e.message : 'Failed to load Weekly Review.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showError('Failed to load Weekly Review.');
    }
  }

  bool get _completedToday {
    return _forceCompletedToday ||
        _completedTodayHint == true ||
        _hasTodayHistoryEntry;
  }

  bool get _completedForCurrentPlan {
    return _forceCompletedToday ||
        _completedThisWeekHint ||
        _completedToday ||
        _history.isNotEmpty;
  }

  List<String> get _answers {
    return _answerControllers
        .map((controller) => controller.text.trim())
        .toList();
  }

  bool get _canSubmit {
    return !_loading &&
        !_submitting &&
        !_completedForCurrentPlan &&
        _answers.every((answer) => answer.isNotEmpty);
  }

  void _togglePastEntries() {
    setState(() {
      _showPastEntries = !_showPastEntries;
    });
  }

  void _syncLockedInputsFromTodayHistory() {
    if (!_completedForCurrentPlan) return;

    final alreadyFilled = _answerControllers.any(
      (controller) => controller.text.trim().isNotEmpty,
    );

    if (alreadyFilled) return;

    TherapyActivityHistoryItem? lockedEntry = _todayHistoryEntry;

    // Weekly Review may have been completed earlier in the same CBT plan,
    // not necessarily today. In that case, use the latest history entry.
    lockedEntry ??= _history.isNotEmpty ? _history.first : null;

    if (lockedEntry == null) return;

    final answers = _answersFromHistory(lockedEntry);

    for (int i = 0; i < _answerControllers.length; i++) {
      if (i < answers.length) {
        _answerControllers[i].text = answers[i];
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

   if (_completedForCurrentPlan) {
    _showError(_weeklyReviewCompletedMessage);
    return;
  }

    final activityId = _activityId;

    if (activityId == null || activityId.trim().isEmpty) {
      _showError('Activity is missing. Please open it from your CBT plan again.');
      return;
    }

    final answers = _answers;

    if (answers.any((answer) => answer.isEmpty)) {
      _showError('Please answer all weekly review questions before saving.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _submitting = true);

    try {
      final result = await AppServices.therapyRepository.submitProgress(
        activityId: activityId,
        responseData: {
          'answers': answers,
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
        type: CbtSavedDialogType.weeklyReview,
        activityName: 'Weekly Review',
        streakDays: result.streakCount,
        onDone: () {
          Navigator.pushReplacementNamed(context, AppRoutes.cbt);
        },
      );
    } on ApiError catch (e) {
      if (!mounted) return;

      final message = e.message.isNotEmpty
          ? e.message
          : 'Failed to save Weekly Review.';

      if (_isWeeklyLimitError(message)) {
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
      _showError('Failed to save Weekly Review.');
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

  List<String> _answersFromHistory(TherapyActivityHistoryItem item) {
    final raw = item.responseData['answers'];

    if (raw is! List) return [];

    return raw
        .map((e) => e.toString().trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }

  int _historyScore(TherapyActivityHistoryItem item) {
    final rawScore = item.responseData['_score'];

    if (rawScore is int) return rawScore;
    if (rawScore is double) return rawScore.round();

    final parsed = int.tryParse((rawScore ?? '').toString());
    if (parsed != null) return parsed;

    return _answersFromHistory(item).length;
  }

  int _historyMaxScore(TherapyActivityHistoryItem item) {
    final rawMax = item.responseData['_max_score'];

    if (rawMax is int) return rawMax;
    if (rawMax is double) return rawMax.round();

    final parsed = int.tryParse((rawMax ?? '').toString());
    if (parsed != null) return parsed;

    return 4;
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

  List<CbtActivityHistoryViewItem> get _historyViewItems {
    return _history.map((entry) {
      final answers = _answersFromHistory(entry);

      final score = _historyScore(entry);
      final maxScore = _historyMaxScore(entry);
      final interpretation = _historyInterpretation(entry);
      final note = _historyNote(entry);

      final lines = <String>[];

      for (int i = 0; i < answers.length && i < _questions.length; i++) {
        lines.add('${_questions[i].historyTitle}: ${answers[i]}');
      }

      if (interpretation != null) {
        lines.add('Interpretation: $interpretation');
      }

      return CbtActivityHistoryViewItem(
        dateLabel: _historyDateLabel(entry.completedAt),
        trailingText: '$score Done',
        lines: lines,
        note: note ?? '$score/$maxScore answers completed',
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

  bool _isWeeklyLimitError(String message) {
    final lower = message.toLowerCase();

    return CbtActivityLockUtils.isDailyLimitError(message) ||
        lower.contains('weekly') ||
        lower.contains('already submitted') ||
        lower.contains('already completed') ||
        lower.contains('already done') ||
        lower.contains('this activity is weekly');
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

      if (target <= 0) return completed > 0;

      return completed >= target;
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
    _title = (args['title'] ?? 'Weekly Review').toString();
    _subtitle = (args['subtitle'] ?? 'Look back on the week.').toString();

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
    final completedForPlanUi = _completedForCurrentPlan;
    final showHistorySkeleton =
        _completedThisWeekHint || completedForPlanUi;

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
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
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
                            title: CbtInfoContent.weeklyReviewTitle,
                            description: CbtInfoContent.weeklyReviewDescription,
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
                      ? _WeeklyReviewSkeleton(
                          isDark: isDark,
                          completedToday: completedForPlanUi,
                          showHistorySkeleton: showHistorySkeleton,
                        )
                      : Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          radius: const Radius.circular(10),
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _subtitle.isNotEmpty
                                      ? _subtitle
                                      : 'Look back on the week',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),

                                const SizedBox(height: 18),

                                Opacity(
                                  opacity: completedForPlanUi ? 0.45 : 1,
                                  child: Column(
                                    children: List.generate(
                                      _questions.length,
                                      (index) => Padding(
                                        padding: EdgeInsets.only(
                                          bottom: index == _questions.length - 1
                                              ? 22
                                              : 12,
                                        ),
                                        child: _WeeklyQuestionBlock(
                                          question: _questions[index].question,
                                          controller: _answerControllers[index],
                                          enabled:
                                              !completedForPlanUi && !_submitting,
                                          isDark: isDark,
                                          hintText: _questions[index].hint,
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                CbtActivityHistorySection(
                                  isDark: isDark,
                                  entries: _historyViewItems,
                                  showHistory: _showPastEntries,
                                  onToggle: _togglePastEntries,
                                ),

                                const SizedBox(height: 120),
                              ],
                            ),
                          ),
                        ),
                ),

                if (completedForPlanUi)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      _weeklyReviewCompletedMessage,
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
                      opacity: _canSubmit ? 1 : 0.5,
                      child: IgnorePointer(
                        ignoring: !_canSubmit,
                        child: PrimaryButton(
                          text: completedForPlanUi
                            ? 'Completed This Week'
                            : _submitting
                                ? 'Saving...'
                                : 'Save My Answers',
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
      ),
    );
  }
}

class _WeeklyQuestionBlock extends StatelessWidget {
  final String question;
  final TextEditingController controller;
  final bool enabled;
  final bool isDark;
  final String hintText;
  final ValueChanged<String> onChanged;

  const _WeeklyQuestionBlock({
    required this.question,
    required this.controller,
    required this.enabled,
    required this.isDark,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fieldColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    final textColor = isDark ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.0,
            color: textColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Answer:',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w400,
            height: 1.0,
            color: isDark
                ? Colors.white.withOpacity(0.42)
                : Colors.black.withOpacity(0.38),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          decoration: BoxDecoration(
            color: fieldColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            minLines: 1,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            onChanged: onChanged,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.45,
              color: textColor.withOpacity(0.78),
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: textColor.withOpacity(0.28),
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _WeeklyReviewSkeleton extends StatelessWidget {
  final bool isDark;
  final bool completedToday;
  final bool showHistorySkeleton;

  const _WeeklyReviewSkeleton({
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
            const _SkeletonBox(width: 260, height: 26, radius: 8),

            const SizedBox(height: 18),

            Opacity(
              opacity: completedToday ? 0.45 : 1,
              child: const Column(
                children: [
                  _WeeklyQuestionBlockSkeleton(),
                  SizedBox(height: 12),
                  _WeeklyQuestionBlockSkeleton(),
                  SizedBox(height: 12),
                  _WeeklyQuestionBlockSkeleton(),
                  SizedBox(height: 12),
                  _WeeklyQuestionBlockSkeleton(),
                  SizedBox(height: 22),
                ],
              ),
            ),

            if (showHistorySkeleton) ...[
              const _SkeletonBox(width: 170, height: 18, radius: 6),
              const SizedBox(height: 14),
              const _WeeklyHistoryPreviewSkeleton(),
              const SizedBox(height: 120),
            ] else ...[
              const SizedBox(height: 120),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeeklyQuestionBlockSkeleton extends StatelessWidget {
  const _WeeklyQuestionBlockSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _SkeletonBox(width: 180, height: 14, radius: 6),
        SizedBox(height: 6),
        _SkeletonBox(width: 70, height: 11, radius: 5),
        SizedBox(height: 10),
        _SkeletonBox(width: double.infinity, height: 56, radius: 8),
      ],
    );
  }
}

class _WeeklyHistoryPreviewSkeleton extends StatelessWidget {
  const _WeeklyHistoryPreviewSkeleton();

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

class _WeeklyReviewQuestion {
  final String question;
  final String historyTitle;
  final String hint;

  const _WeeklyReviewQuestion({
    required this.question,
    required this.historyTitle,
    required this.hint,
  });
}