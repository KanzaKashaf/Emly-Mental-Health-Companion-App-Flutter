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

class ThoughtRecordScreen extends StatefulWidget {
  const ThoughtRecordScreen({super.key});

  @override
  State<ThoughtRecordScreen> createState() => _ThoughtRecordScreenState();
}

class _ThoughtRecordScreenState extends State<ThoughtRecordScreen> {
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _situationController = TextEditingController();
  final TextEditingController _automaticThoughtController =
      TextEditingController();
  final TextEditingController _evidenceController = TextEditingController();
  final TextEditingController _balancedThoughtController =
      TextEditingController();

  double _intensity = 50;

  bool _argsRead = false;
  bool _loading = true;
  bool _submitting = false;
  bool _showHistory = false;
  bool _forceCompletedToday = false;
  bool? _completedTodayHint;
  bool _completedThisWeekHint = false;

  String? _activityId;
  String _title = 'Thought Record';
  String _subtitle = 'When a strong negative feeling hits, fill this out.';
  static const int _targetCompletionsForPlan = 3;

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

  @override
  void dispose() {
    _scrollController.dispose();
    _situationController.dispose();
    _automaticThoughtController.dispose();
    _evidenceController.dispose();
    _balancedThoughtController.dispose();
    super.dispose();
  }

  Future<void> _loadActivity() async {
    setState(() => _loading = true);

    try {
      // Fallback if opened directly without CBT dashboard route arguments.
      if (_activityId == null || _activityId!.trim().isEmpty) {
        final plan = await AppServices.therapyRepository.getPlan();

        TherapyActivity? thoughtActivity;

        if (plan != null) {
          for (final activity in plan.activities) {
            final type = activity.type.toLowerCase();
            final title = activity.title.toLowerCase();

            if (type.contains('thought') ||
                title.contains('thought record') ||
                title.contains('thought')) {
              thoughtActivity = activity;
              break;
            }
          }
        }

        if (thoughtActivity != null) {
          _activityId = thoughtActivity.id;
          _title = thoughtActivity.title;
          _subtitle = thoughtActivity.subtitle;
          _completedTodayHint = thoughtActivity.isCompletedToday;
          _completedThisWeekHint =
          thoughtActivity.isTargetCompleted ||
          _readCurrentWeekProgressHint(thoughtActivity.toRouteArgs());
        }
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

      setState(() => _loading = false);

      _showError(
        e.message.isNotEmpty ? e.message : 'Failed to load Thought Record.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showError('Failed to load Thought Record.');
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
    return 'Thought Record target is already completed for this CBT plan. You can continue when your plan renews.';
  }

  bool get _canSubmit {
    return !_loading &&
        !_submitting &&
        !_lockedForUi &&
        _situationController.text.trim().isNotEmpty &&
        _automaticThoughtController.text.trim().isNotEmpty &&
        _evidenceController.text.trim().isNotEmpty &&
        _balancedThoughtController.text.trim().isNotEmpty;
  }

  void _toggleHistory() {
    setState(() {
      _showHistory = !_showHistory;
    });
  }

  void _onIntensityChanged(double value) {
    if (_lockedForUi || _submitting) return;

    setState(() => _intensity = value);
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

    if (!_canSubmit) {
      _showError('Please complete all thought record fields before saving.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _submitting = true);

    try {
      final result = await AppServices.therapyRepository.submitProgress(
        activityId: activityId,
        responseData: {
          'situation': _situationController.text.trim(),
          'automatic_thought': _automaticThoughtController.text.trim(),
          'emotion': _intensity.round(),
          'evidence': _evidenceController.text.trim(),
          'balanced_thought': _balancedThoughtController.text.trim(),
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
        activityName: 'Thought Record',
        streakDays: result.streakCount,
        onDone: () {
          Navigator.pushReplacementNamed(context, AppRoutes.cbt);
        },
      );
    } on ApiError catch (e) {
      if (!mounted) return;

      final message = e.message.isNotEmpty
          ? e.message
          : 'Failed to save Thought Record.';

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
      _showError('Failed to save Thought Record.');
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

  int _historyScore(TherapyActivityHistoryItem item) {
    final rawScore = item.responseData['_score'];

    if (rawScore is int) return rawScore;
    if (rawScore is double) return rawScore.round();

    final parsed = int.tryParse((rawScore ?? '').toString());
    if (parsed != null) return parsed;

    int score = 0;

    if ((item.responseData['situation'] ?? '').toString().trim().isNotEmpty) {
      score++;
    }
    if ((item.responseData['automatic_thought'] ?? '')
        .toString()
        .trim()
        .isNotEmpty) {
      score++;
    }
    if ((item.responseData['balanced_thought'] ?? '')
        .toString()
        .trim()
        .isNotEmpty) {
      score++;
    }

    return score;
  }

  int _historyMaxScore(TherapyActivityHistoryItem item) {
    final rawMax = item.responseData['_max_score'];

    if (rawMax is int) return rawMax;
    if (rawMax is double) return rawMax.round();

    final parsed = int.tryParse((rawMax ?? '').toString());
    if (parsed != null) return parsed;

    return 3;
  }

  String? _historyInterpretation(TherapyActivityHistoryItem item) {
    final raw = item.responseData['_interpretation'];

    if (raw == null) return null;

    final text = raw.toString().trim();
    if (text.isEmpty || text == 'null') return null;

    return text;
  }

  String _historyText(
    TherapyActivityHistoryItem item,
    String key,
  ) {
    return (item.responseData[key] ?? '').toString().trim();
  }

  int _historyEmotion(TherapyActivityHistoryItem item) {
    final raw = item.responseData['emotion'];

    if (raw is int) return raw;
    if (raw is double) return raw.round();

    return int.tryParse((raw ?? '').toString()) ?? 0;
  }

  List<CbtActivityHistoryViewItem> get _historyViewItems {
    return _history.map((entry) {
      final score = _historyScore(entry);
      final maxScore = _historyMaxScore(entry);
      final interpretation = _historyInterpretation(entry);

      final situation = _historyText(entry, 'situation');
      final automaticThought = _historyText(entry, 'automatic_thought');
      final evidence = _historyText(entry, 'evidence');
      final balancedThought = _historyText(entry, 'balanced_thought');
      final emotion = _historyEmotion(entry);

      final lines = <String>[];

      if (situation.isNotEmpty) {
        lines.add('Situation: $situation');
      }

      if (automaticThought.isNotEmpty) {
        lines.add('Automatic thought: $automaticThought');
      }

      if (emotion > 0) {
        lines.add('Emotion: $emotion/100');
      }

      if (evidence.isNotEmpty) {
        lines.add('Evidence: $evidence');
      }

      if (balancedThought.isNotEmpty) {
        lines.add('Balanced thought: $balancedThought');
      }

      if (interpretation != null) {
        lines.add('Interpretation: $interpretation');
      }

      return CbtActivityHistoryViewItem(
        dateLabel: _historyDateLabel(entry.completedAt),
        trailingText: '$score Done',
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
    _title = (args['title'] ?? 'Thought Record').toString();
    _subtitle = (args['subtitle'] ??
            'When a strong negative feeling hits, fill this out.')
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

  void _syncLockedInputsFromTodayHistory() {
    if (!_completedToday) return;

    TherapyActivityHistoryItem? todayEntry = _todayHistoryEntry;

    if (todayEntry == null && _completedTodayHint == true && _history.isNotEmpty) {
      todayEntry = _history.first;
    }

    if (todayEntry == null) return;

    if (_situationController.text.trim().isEmpty) {
      _situationController.text = _historyText(todayEntry, 'situation');
    }

    if (_automaticThoughtController.text.trim().isEmpty) {
      _automaticThoughtController.text =
          _historyText(todayEntry, 'automatic_thought');
    }

    if (_evidenceController.text.trim().isEmpty) {
      _evidenceController.text = _historyText(todayEntry, 'evidence');
    }

    if (_balancedThoughtController.text.trim().isEmpty) {
      _balancedThoughtController.text =
          _historyText(todayEntry, 'balanced_thought');
    }

    final emotion = _historyEmotion(todayEntry);
    if (emotion > 0) {
      _intensity = emotion.toDouble().clamp(0, 100);
    }
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
                      padding: const EdgeInsets.only(right: 20),
                      child: GestureDetector(
                        onTap: () {
                          CbtInfoDialog.show(
                            context: context,
                            title: CbtInfoContent.thoughtRecordTitle,
                            description:
                                CbtInfoContent.thoughtRecordDescription,
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
                      ? _ThoughtRecordSkeleton(
                          isDark: isDark,
                          completedToday: completedTodayForUi,
                          showHistorySkeleton: showHistorySkeleton,
                        )
                      : SingleChildScrollView(
                          controller: _scrollController,
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'When a strong negative feeling\nhits, fill this out.',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                  height: 1.28,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),

                              const SizedBox(height: 18),

                              Opacity(
                                opacity: lockedForUi ? 0.45 : 1,
                                child: Column(
                                  children: [
                                    _ThoughtInputBlock(
                                      isDark: isDark,
                                      title: 'Situation',
                                      helper: 'What happened?',
                                      controller: _situationController,
                                      enabled: !lockedForUi && !_submitting,
                                      hintText: 'Describe what happened...',
                                      onChanged: (_) => setState(() {}),
                                    ),

                                    const SizedBox(height: 14),

                                    _ThoughtInputBlock(
                                      isDark: isDark,
                                      title: 'Automatic thought',
                                      helper: 'What went through your mind?',
                                      controller: _automaticThoughtController,
                                      enabled: !lockedForUi && !_submitting,
                                      hintText: 'Write the thought you noticed...',
                                      onChanged: (_) => setState(() {}),
                                    ),

                                    const SizedBox(height: 14),

                                    _EmotionSliderBlock(
                                      isDark: isDark,
                                      value: _intensity,
                                      onChanged: _onIntensityChanged,
                                    ),

                                    const SizedBox(height: 14),

                                    _ThoughtInputBlock(
                                      isDark: isDark,
                                      title: 'Evidence against',
                                      helper: 'Any counter-facts?',
                                      controller: _evidenceController,
                                      enabled: !lockedForUi && !_submitting,
                                      hintText: 'What evidence gives a fairer view?',
                                      onChanged: (_) => setState(() {}),
                                    ),

                                    const SizedBox(height: 14),

                                    _ThoughtInputBlock(
                                      isDark: isDark,
                                      title: 'Balanced thought',
                                      helper: 'A fairer way to see this',
                                      controller: _balancedThoughtController,
                                      enabled: !lockedForUi && !_submitting,
                                      hintText: 'Write a balanced thought...',
                                      onChanged: (_) => setState(() {}),
                                    ),

                                    const SizedBox(height: 28),
                                  ],
                                ),
                              ),

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
                      opacity: _canSubmit ? 1 : 0.5,
                      child: IgnorePointer(
                        ignoring: !_canSubmit,
                        child: PrimaryButton(
                          text: lockedForUi
                            ? completedTodayForUi
                                ? 'Completed Today'
                                : 'Target Completed'
                            : _submitting
                                ? 'Saving...'
                                : 'Save My Thought',
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

class _ThoughtInputBlock extends StatelessWidget {
  final bool isDark;
  final String title;
  final String helper;
  final TextEditingController controller;
  final bool enabled;
  final String hintText;
  final ValueChanged<String> onChanged;

  const _ThoughtInputBlock({
    required this.isDark,
    required this.title,
    required this.helper,
    required this.controller,
    required this.enabled,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fieldColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    final bodyTextColor =
        isDark ? Colors.white.withOpacity(0.78) : const Color(0xFF2F2F2F);

    final helperColor =
        isDark ? Colors.white.withOpacity(0.42) : Colors.black.withOpacity(0.38);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.0,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          helper,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w400,
            height: 1.0,
            color: helperColor,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          decoration: BoxDecoration(
            color: fieldColor,
            borderRadius: BorderRadius.circular(10),
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
              color: bodyTextColor,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: bodyTextColor.withOpacity(0.28),
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmotionSliderBlock extends StatelessWidget {
  final bool isDark;
  final double value;
  final ValueChanged<double> onChanged;

  const _EmotionSliderBlock({
    required this.isDark,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final fieldColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    final helperColor =
        isDark ? Colors.white.withOpacity(0.42) : Colors.black.withOpacity(0.38);

    final bodyColor =
        isDark ? Colors.white.withOpacity(0.72) : Colors.black.withOpacity(0.52);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emotion',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.0,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'How strong was the emotion? How intense? 0-100',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w400,
            height: 1.0,
            color: helperColor,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: fieldColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Intensity',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: bodyColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    value.round().toString(),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 22,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: primary,
                    inactiveTrackColor:
                        isDark ? Colors.white : const Color(0xFFFFFFFF),
                    thumbColor: Colors.white,
                    overlayColor: primary.withOpacity(0.10),
                    overlayShape: SliderComponentShape.noOverlay,
                    thumbShape: _OutlinedThumbShape(
                      borderColor: primary,
                      thumbRadius: 10,
                      borderWidth: 2,
                    ),
                  ),
                  child: Slider(
                    min: 0,
                    max: 100,
                    value: value,
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThoughtRecordSkeleton extends StatelessWidget {
  final bool isDark;
  final bool completedToday;
  final bool showHistorySkeleton;

  const _ThoughtRecordSkeleton({
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
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SkeletonBox(width: double.infinity, height: 54, radius: 8),

            const SizedBox(height: 18),

            Opacity(
              opacity: completedToday ? 0.45 : 1,
              child: const Column(
                children: [
                  _ThoughtInputBlockSkeleton(),
                  SizedBox(height: 14),
                  _ThoughtInputBlockSkeleton(),
                  SizedBox(height: 14),
                  _EmotionSliderBlockSkeleton(),
                  SizedBox(height: 14),
                  _ThoughtInputBlockSkeleton(),
                  SizedBox(height: 14),
                  _ThoughtInputBlockSkeleton(),
                  SizedBox(height: 28),
                ],
              ),
            ),

            if (showHistorySkeleton) ...[
              const _SkeletonBox(width: 170, height: 18, radius: 6),
              const SizedBox(height: 14),
              const _ThoughtHistoryPreviewSkeleton(),
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

class _ThoughtInputBlockSkeleton extends StatelessWidget {
  const _ThoughtInputBlockSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _SkeletonBox(width: 150, height: 14, radius: 6),
        SizedBox(height: 6),
        _SkeletonBox(width: 210, height: 11, radius: 5),
        SizedBox(height: 10),
        _SkeletonBox(width: double.infinity, height: 56, radius: 10),
      ],
    );
  }
}

class _EmotionSliderBlockSkeleton extends StatelessWidget {
  const _EmotionSliderBlockSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _SkeletonBox(width: 90, height: 14, radius: 6),
        SizedBox(height: 6),
        _SkeletonBox(width: 260, height: 11, radius: 5),
        SizedBox(height: 10),
        _SkeletonBox(width: double.infinity, height: 70, radius: 10),
      ],
    );
  }
}

class _ThoughtHistoryPreviewSkeleton extends StatelessWidget {
  const _ThoughtHistoryPreviewSkeleton();

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

class _OutlinedThumbShape extends SliderComponentShape {
  final Color borderColor;
  final double thumbRadius;
  final double borderWidth;

  const _OutlinedThumbShape({
    required this.borderColor,
    required this.thumbRadius,
    required this.borderWidth,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, thumbRadius, fillPaint);
    canvas.drawCircle(center, thumbRadius, borderPaint);
  }
}