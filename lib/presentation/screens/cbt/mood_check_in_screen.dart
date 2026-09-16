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

class MoodCheckInScreen extends StatefulWidget {
  const MoodCheckInScreen({super.key});

  @override
  State<MoodCheckInScreen> createState() => _MoodCheckInScreenState();
}

class _MoodCheckInScreenState extends State<MoodCheckInScreen> {
  double _moodValue = 5;
  int _selectedMoodIndex = 2;

  bool _argsRead = false;
  bool _loading = true;
  bool _submitting = false;
  bool _showPastEntries = false;
  bool _forceCompletedToday = false;
  bool? _completedTodayHint;

  String? _activityId;
  String _title = 'Mood Check-in';
  String _subtitle = 'No judgment. Just a check in.';

  final TextEditingController _noteController = TextEditingController();

  final List<String> _moods = const ['😞', '😕', '😐', '🙂', '😊'];

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
    _title = (args['title'] ?? 'Mood Check-in').toString();
    _subtitle = (args['subtitle'] ?? 'No judgment. Just a check in.').toString();

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
    _noteController.dispose();
    super.dispose();
  }

  void _syncLockedInputsFromTodayHistory() {
    if (!_completedToday) return;

    TherapyActivityHistoryItem? todayEntry = _todayHistoryEntry;

    if (todayEntry == null && _completedTodayHint == true && _history.isNotEmpty) {
      todayEntry = _history.first;
    }

    if (todayEntry == null) return;

    final score = _historyMoodScore(todayEntry);

    if (score > 0) {
      final safeScore = score.clamp(1, 10);
      _moodValue = safeScore.toDouble();
      _selectedMoodIndex = _emojiIndexForScore(safeScore);
    }

    final note = _historyNote(todayEntry);

    if (note != null && _noteController.text.trim().isEmpty) {
      _noteController.text = note;
    }
  }

  Future<void> _loadActivity() async {
    setState(() => _loading = true);

    try {
      // Fallback if screen opens directly without route args.
      if (_activityId == null || _activityId!.trim().isEmpty) {
        final plan = await AppServices.therapyRepository.getPlan();

        TherapyActivity? moodActivity;

        if (plan != null) {
          for (final activity in plan.activities) {
            final type = activity.type.toLowerCase();
            final title = activity.title.toLowerCase();

            if (type.contains('mood') || title.contains('mood')) {
              moodActivity = activity;
              break;
            }
          }
        }

        if (moodActivity != null) {
          _activityId = moodActivity.id;
          _title = moodActivity.title;
          _subtitle = moodActivity.subtitle;
          _completedTodayHint = moodActivity.isCompletedToday;
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
        e.message.isNotEmpty ? e.message : 'Failed to load Mood Check-in.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showError('Failed to load Mood Check-in.');
    }
  }

  bool get _completedToday {
    return _forceCompletedToday ||
        _completedTodayHint == true ||
        _hasTodayHistoryEntry;
  }

  void _togglePastEntries() {
    setState(() {
      _showPastEntries = !_showPastEntries;
    });
  }

  void _selectMood(int index) {
    const values = [2.0, 4.0, 6.0, 8.0, 10.0];

    setState(() {
      _selectedMoodIndex = index;
      _moodValue = values[index];
    });
  }

  void _onSliderChanged(double value) {
    if (_completedToday || _submitting) return;

    setState(() {
      _moodValue = value;
      _selectedMoodIndex = _emojiIndexForScore(value.round());
    });
  }

  int _emojiIndexForScore(int score) {
    if (score <= 2) return 0;
    if (score <= 4) return 1;
    if (score <= 6) return 2;
    if (score <= 8) return 3;
    return 4;
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

    setState(() => _submitting = true);

    try {
      final moodScore = _moodValue.round();
      final note = _noteController.text.trim();

      final result = await AppServices.therapyRepository.submitProgress(
        activityId: activityId,
        responseData: {
          'mood_score': moodScore,
          'note': note,
        },
      );

      final updatedHistory =
          await AppServices.therapyRepository.getActivityHistory(activityId);

      if (!mounted) return;

      setState(() {
        _history = updatedHistory;
        _forceCompletedToday = true;
        _completedTodayHint = true;
        _submitting = false;
        _syncLockedInputsFromTodayHistory();
      });

      CbtActivitySavedDialog.show(
        context: context,
        type: CbtSavedDialogType.daily,
        activityName: 'Mood Check-in',
        streakDays: result.streakCount,
        onDone: () {
          Navigator.pushReplacementNamed(context, AppRoutes.cbt);
        },
      );
    } on ApiError catch (e) {
        if (!mounted) return;

        final message = e.message.isNotEmpty
            ? e.message
            : 'Failed to save Mood Check-in.';

        if (CbtActivityLockUtils.isDailyLimitError(message)) {
          try {
            final updatedHistory =
                await AppServices.therapyRepository.getActivityHistory(activityId);

            if (!mounted) return;

            setState(() {
              _history = updatedHistory;
              _forceCompletedToday = true;
              _completedTodayHint = true;
              _submitting = false;
              _syncLockedInputsFromTodayHistory();
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

  int _historyMoodScore(TherapyActivityHistoryItem item) {
    final raw = item.responseData['mood_score'] ??
        item.responseData['moodScore'] ??
        item.responseData['score'] ??
        item.responseData['_score'];

    if (raw is int) return raw;

    if (raw is double) return raw.round();

    return int.tryParse((raw ?? '').toString()) ?? 0;
  }

  int _historyMaxScore(TherapyActivityHistoryItem item) {
    final raw = item.responseData['_max_score'] ??
        item.responseData['maxScore'] ??
        item.responseData['max_score'];

    if (raw is int) return raw;

    if (raw is double) return raw.round();

    return int.tryParse((raw ?? '').toString()) ?? 10;
  }

  String? _historyInterpretation(TherapyActivityHistoryItem item) {
    final raw = item.responseData['_interpretation'] ??
        item.responseData['interpretation'];

    if (raw == null) return null;

    final text = raw.toString().trim();
    if (text.isEmpty || text == 'null') return null;

    return text;
  }

  String? _historyNote(TherapyActivityHistoryItem item) {
    final fromResponse = item.responseData['note']?.toString();
    final fromEntry = item.notes;

    final note = fromResponse != null && fromResponse.trim().isNotEmpty
        ? fromResponse.trim()
        : fromEntry?.trim();

    if (note == null || note.isEmpty || note == 'null') return null;

    return note;
  }

  List<CbtActivityHistoryViewItem> get _historyViewItems {
    return _history.map((entry) {
      final score = _historyMoodScore(entry);
      final maxScore = _historyMaxScore(entry);
      final interpretation = _historyInterpretation(entry);
      final note = _historyNote(entry);

      final lines = <String>[
        'Mood score: $score/$maxScore',
      ];

      if (interpretation != null) {
        lines.add('Interpretation: $interpretation');
      }

      return CbtActivityHistoryViewItem(
        dateLabel: _historyDateLabel(entry.completedAt),
        trailingText: score > 0 ? '$score/$maxScore' : '--',
        lines: lines,
        note: note,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completedTodayForUi = _completedToday;

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
                          title: CbtInfoContent.moodCheckInTitle,
                          description: CbtInfoContent.moodCheckInDescription,
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
                        ? _MoodCheckInSkeleton(
                            isDark: isDark,
                            completedToday: completedTodayForUi,
                          )
                    : Scrollbar(
                        thumbVisibility: true,
                        radius: const Radius.circular(10),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'How are you feeling right now?',
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
                                      : Colors.black.withOpacity(0.42),
                                ),
                              ),

                              const SizedBox(height: 17),

                              Center(
                                child: Text(
                                  _moodValue.round().toString(),
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 72,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                    color: isDark
                                        ? AppColors.primaryDark
                                        : AppColors.primaryLight,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              Opacity(
                                opacity: completedTodayForUi ? 0.45 : 1,
                                child: _MoodGradientSlider(
                                  value: _moodValue,
                                  isDark: isDark,
                                  onChanged: _onSliderChanged,
                                ),
                              ),

                              const SizedBox(height: 34),

                              Opacity(
                                opacity: completedTodayForUi ? 0.45 : 1,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: List.generate(
                                    _moods.length,
                                    (index) => _MoodEmojiButton(
                                      emoji: _moods[index],
                                      selected: _selectedMoodIndex == index,
                                      isDark: isDark,
                                      onTap: completedTodayForUi || _submitting
                                          ? () {}
                                          : () => _selectMood(index),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 34),

                              Text(
                                'Anything you want to add? (optional)',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  height: 1.0,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.42)
                                      : Colors.black.withOpacity(0.42),
                                ),
                              ),

                              const SizedBox(height: 14),

                              _MoodNoteBox(
                                controller: _noteController,
                                enabled: !completedTodayForUi && !_submitting,
                                isDark: isDark,
                              ),

                              const SizedBox(height: 28),

                              CbtActivityHistorySection(
                                isDark: isDark,
                                entries: _historyViewItems,
                                showHistory: _showPastEntries,
                                onToggle: _togglePastEntries,
                              ),

                              const SizedBox(height: 100),
                            ],
                          ),
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
                      color:
                          Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
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
                                ? 'Saving...'
                                : 'Save My Mood',
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

class _MoodGradientSlider extends StatelessWidget {
  final double value;
  final bool isDark;
  final ValueChanged<double> onChanged;

  const _MoodGradientSlider({
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Column(
      children: [
        SizedBox(
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF3B3F),
                      Color(0xFFFFB000),
                      Color(0xFFFFEA00),
                      Color(0xFF20E336),
                    ],
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 0,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: Colors.white,
                  overlayColor: primary.withOpacity(0.12),
                  overlayShape: SliderComponentShape.noOverlay,
                  thumbShape: _MoodThumbShape(
                    borderColor: primary,
                    thumbRadius: 9,
                    borderWidth: 2,
                  ),
                ),
                child: Slider(
                  min: 1,
                  max: 10,
                  value: value,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Text(
                'Really low',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: isDark
                      ? Colors.white.withOpacity(0.42)
                      : Colors.black.withOpacity(0.42),
                ),
              ),
              const Spacer(),
              Text(
                'Balanced',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: isDark
                      ? Colors.white.withOpacity(0.42)
                      : Colors.black.withOpacity(0.42),
                ),
              ),
              const Spacer(),
              Text(
                'Great',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: isDark
                      ? Colors.white.withOpacity(0.42)
                      : Colors.black.withOpacity(0.42),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoodEmojiButton extends StatelessWidget {
  final String emoji;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _MoodEmojiButton({
    required this.emoji,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBg = isDark
        ? Colors.white.withOpacity(0.88)
        : AppColors.primaryLight.withOpacity(0.10);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Text(
          emoji,
          style: const TextStyle(
            fontSize: 31,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _MoodNoteBox extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool isDark;

  const _MoodNoteBox({
    required this.controller,
    required this.enabled,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fieldColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      width: double.infinity,
      height: 102,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      decoration: BoxDecoration(
        color: fieldColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLines: null,
        expands: true,
        keyboardType: TextInputType.multiline,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.4,
          color: textColor.withOpacity(0.78),
        ),
        decoration: InputDecoration(
          hintText: 'How did it feel? (optional)',
          hintStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textColor.withOpacity(0.22),
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _MoodCheckInSkeleton extends StatelessWidget {
  final bool isDark;
  final bool completedToday;

  const _MoodCheckInSkeleton({
    required this.isDark,
    required this.completedToday,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
      highlightColor:
          isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF6F8FC),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SkeletonBox(width: double.infinity, height: 26, radius: 8),
            const SizedBox(height: 10),
            const _SkeletonBox(width: 250, height: 14, radius: 6),

            const SizedBox(height: 24),

            const Center(
              child: _SkeletonBox(width: 82, height: 72, radius: 14),
            ),

            const SizedBox(height: 18),

            Opacity(
              opacity: completedToday ? 0.45 : 1,
              child: const Column(
                children: [
                  _MoodSliderSkeleton(),
                  SizedBox(height: 34),
                  _MoodEmojiRowSkeleton(),
                  SizedBox(height: 34),
                ],
              ),
            ),

            const _SkeletonBox(width: 220, height: 12, radius: 6),

            const SizedBox(height: 14),

            Opacity(
              opacity: completedToday ? 0.45 : 1,
              child: const _SkeletonBox(
                width: double.infinity,
                height: 102,
                radius: 8,
              ),
            ),

            const SizedBox(height: 28),

            const _SkeletonBox(width: 140, height: 18, radius: 6),

            const SizedBox(height: 14),

            completedToday
                ? const _MoodHistorySkeleton(hasContent: true)
                : const _MoodHistorySkeleton(hasContent: false),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _MoodSliderSkeleton extends StatelessWidget {
  const _MoodSliderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _SkeletonBox(width: double.infinity, height: 8, radius: 10),
        SizedBox(height: 14),
        Row(
          children: [
            _SkeletonBox(width: 70, height: 11, radius: 5),
            Spacer(),
            _SkeletonBox(width: 64, height: 11, radius: 5),
            Spacer(),
            _SkeletonBox(width: 42, height: 11, radius: 5),
          ],
        ),
      ],
    );
  }
}

class _MoodEmojiRowSkeleton extends StatelessWidget {
  const _MoodEmojiRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SkeletonCircle(size: 56),
        _SkeletonCircle(size: 56),
        _SkeletonCircle(size: 56),
        _SkeletonCircle(size: 56),
        _SkeletonCircle(size: 56),
      ],
    );
  }
}

class _MoodHistorySkeleton extends StatelessWidget {
  final bool hasContent;

  const _MoodHistorySkeleton({
    required this.hasContent,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasContent) {
      return const _SkeletonBox(
        width: double.infinity,
        height: 44,
        radius: 9,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _SkeletonBox(height: 16, radius: 6)),
              SizedBox(width: 20),
              _SkeletonBox(width: 52, height: 16, radius: 6),
            ],
          ),
          SizedBox(height: 12),
          _SkeletonBox(width: 180, height: 13, radius: 6),
          SizedBox(height: 8),
          _SkeletonBox(width: 230, height: 13, radius: 6),
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

class _MoodThumbShape extends SliderComponentShape {
  final Color borderColor;
  final double thumbRadius;
  final double borderWidth;

  const _MoodThumbShape({
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