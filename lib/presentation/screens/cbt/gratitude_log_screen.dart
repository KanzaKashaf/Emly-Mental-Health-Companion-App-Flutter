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

class GratitudeLogScreen extends StatefulWidget {
  const GratitudeLogScreen({super.key});

  @override
  State<GratitudeLogScreen> createState() => _GratitudeLogScreenState();
}

class _GratitudeLogScreenState extends State<GratitudeLogScreen> {
  final ScrollController _scrollController = ScrollController();

  bool _argsRead = false;
  bool _loading = true;
  bool _submitting = false;
  bool _showPastEntries = false;
  bool _forceCompletedToday = false;
  bool? _completedTodayHint;
  bool _completedThisWeekHint = false;

  String? _activityId;
  String _title = 'Gratitude Log';
  String _subtitle = 'Small or big. Whatever felt good.';

  final List<TextEditingController> _logControllers = [];
  final List<FocusNode> _logFocusNodes = [];

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

    return _sameDate(_appDateOnly(value), _todayAppDateOnly());
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

    for (final controller in _logControllers) {
      controller.dispose();
    }

    for (final focusNode in _logFocusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  void _removeLog(int index) {
    if (_completedToday || _submitting) return;
    if (index < 0 || index >= _logControllers.length) return;

    final controller = _logControllers.removeAt(index);
    final focusNode = _logFocusNodes.removeAt(index);

    controller.dispose();
    focusNode.dispose();

    setState(() {});
  }

  bool get _canAddMore {
    return !_completedToday && !_submitting && _logControllers.length < 3;
  }

  Future<void> _loadActivity() async {
    setState(() => _loading = true);

    try {
      // Fallback if opened directly without dashboard route arguments.
      if (_activityId == null || _activityId!.trim().isEmpty) {
        final plan = await AppServices.therapyRepository.getPlan();

        TherapyActivity? gratitudeActivity;

        if (plan != null) {
          for (final activity in plan.activities) {
            final type = activity.type.toLowerCase();
            final title = activity.title.toLowerCase();

            if (type.contains('gratitude') || title.contains('gratitude')) {
              gratitudeActivity = activity;
              break;
            }
          }
        }

        if (gratitudeActivity != null) {
          _activityId = gratitudeActivity.id;
          _title = gratitudeActivity.title;
          _subtitle = gratitudeActivity.subtitle;
          _completedTodayHint = gratitudeActivity.isCompletedToday;
          _completedThisWeekHint =
              gratitudeActivity.isCompletedToday ||
              ((gratitudeActivity.progressText ?? '').contains(
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
        _loading = false;
        _syncLockedInputsFromTodayHistory();
      });
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      _showError(
        e.message.isNotEmpty ? e.message : 'Failed to load Gratitude Log.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showError('Failed to load Gratitude Log.');
    }
  }

  bool get _completedToday {
    return _forceCompletedToday ||
        _completedTodayHint == true ||
        _hasTodayHistoryEntry;
  }

  List<String> get _filledEntries {
    return _logControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .take(3)
        .toList();
  }

  bool get _canSubmit {
    return !_loading &&
        !_submitting &&
        !_completedToday &&
        _filledEntries.isNotEmpty &&
        _filledEntries.length <= 3;
  }

  void _addAnother() {
    if (_completedToday || _submitting) return;
    if (_logControllers.length >= 3) return;

    final controller = TextEditingController();
    final focusNode = FocusNode();

    setState(() {
      _logControllers.add(controller);
      _logFocusNodes.add(focusNode);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      focusNode.requestFocus();
    });
  }

  void _togglePastEntries() {
    setState(() {
      _showPastEntries = !_showPastEntries;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;

    if (_completedToday) {
      _showError(CbtActivityLockUtils.completedTodayMessage());
      return;
    }

    final activityId = _activityId;

    if (activityId == null || activityId.trim().isEmpty) {
      _showError(
        'Activity is missing. Please open it from your CBT plan again.',
      );
      return;
    }

    final entries = _filledEntries;

    if (entries.isEmpty) {
      _showError('Add at least one gratitude entry before saving.');
      return;
    }

    if (entries.length > 3) {
      _showError('You can add up to 3 gratitude entries only.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final result = await AppServices.therapyRepository.submitProgress(
        activityId: activityId,
        responseData: {'entries': entries},
      );

      final updatedHistory = await AppServices.therapyRepository
          .getActivityHistory(activityId);

      if (!mounted) return;

      setState(() {
        _history = updatedHistory;
        _forceCompletedToday = true;
        _completedTodayHint = true;
        _completedThisWeekHint = true;
        _submitting = false;
      });

      _syncLockedInputsFromTodayHistory();

      CbtActivitySavedDialog.show(
        context: context,
        type: CbtSavedDialogType.daily,
        activityName: 'Gratitude Log',
        streakDays: result.streakCount,
        onDone: () {
          Navigator.pushReplacementNamed(context, AppRoutes.cbt);
        },
      );
    } on ApiError catch (e) {
      if (!mounted) return;

      final message = e.message.isNotEmpty
          ? e.message
          : 'Failed to save Gratitude Log.';

      final isDailyLimit = CbtActivityLockUtils.isDailyLimitError(message);

      if (isDailyLimit) {
        try {
          if (activityId.trim().isNotEmpty) {
            final updatedHistory = await AppServices.therapyRepository
                .getActivityHistory(activityId);

            if (!mounted) return;

            setState(() {
              _history = updatedHistory;
              _forceCompletedToday = true;
              _completedTodayHint = true;
              _completedThisWeekHint = true;
              _submitting = false;
            });

            _syncLockedInputsFromTodayHistory();
          } else {
            setState(() {
              _forceCompletedToday = true;
              _completedTodayHint = true;
              _completedThisWeekHint = true;
              _submitting = false;
            });
          }
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
      _showError('Failed to save Gratitude Log.');
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

  List<String> _entriesFromHistory(TherapyActivityHistoryItem item) {
    final raw = item.responseData['entries'];

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

    return _entriesFromHistory(item).length;
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
      final entries = _entriesFromHistory(entry);

      final score = _historyScore(entry);
      final maxScore = _historyMaxScore(entry);
      final interpretation = _historyInterpretation(entry);
      final note = _historyNote(entry);

      final lines = <String>[];

      for (final item in entries) {
        lines.add('✓ $item');
      }

      if (interpretation != null) {
        lines.add('Interpretation: $interpretation');
      }

      return CbtActivityHistoryViewItem(
        dateLabel: _historyDateLabel(entry.completedAt),
        trailingText: '$score Done',
        lines: lines,
        note: note ?? '$score/$maxScore gratitude entries completed',
      );
    }).toList();
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _syncLockedInputsFromTodayHistory() {
    if (!_completedToday) return;
    if (_logControllers.isNotEmpty) return;

    TherapyActivityHistoryItem? todayEntry = _todayHistoryEntry;

    if (todayEntry == null &&
        _completedTodayHint == true &&
        _history.isNotEmpty) {
      todayEntry = _history.first;
    }

    if (todayEntry == null) return;

    final entries = _entriesFromHistory(todayEntry);

    for (final entry in entries.take(3)) {
      _logControllers.add(TextEditingController(text: entry));
      _logFocusNodes.add(FocusNode());
    }
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
    _title = (args['title'] ?? 'Gratitude Log').toString();
    _subtitle = (args['subtitle'] ?? 'Small or big. Whatever felt good.')
        .toString();

    _completedTodayHint = _readBoolArg(args, [
      'isCompletedToday',
      'completedToday',
      'completed_today',
      'is_completed_today',
      'activityCompletedToday',
      'isDoneToday',
      'doneToday',
    ]);

    _completedThisWeekHint =
    _completedTodayHint == true || _readCurrentWeekProgressHint(args);
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
        resizeToAvoidBottomInset: true,
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
                          title: CbtInfoContent.gratitudeLogTitle,
                          description: CbtInfoContent.gratitudeLogDescription,
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
                    ? _GratitudeLogSkeleton(
                        isDark: isDark,
                        completedToday: completedTodayForUi,
                        showHistorySkeleton: showHistorySkeleton,
                      )
                    : Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        radius: const Radius.circular(10),
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Three things, today.',
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
                                opacity: _completedToday ? 0.45 : 1,
                                child: Column(
                                  children: [
                                    ...List.generate(
                                      _logControllers.length,
                                      (index) => Padding(
                                        padding: EdgeInsets.only(
                                          bottom:
                                              index ==
                                                  _logControllers.length - 1
                                              ? 14
                                              : 10,
                                        ),
                                        child: _GratitudeTile(
                                          number: index + 1,
                                          controller: _logControllers[index],
                                          focusNode: _logFocusNodes[index],
                                          enabled:
                                              !_completedToday && !_submitting,
                                          isDark: isDark,
                                          showRemove:
                                              !_completedToday && !_submitting,
                                          onRemove: () => _removeLog(index),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                    ),

                                    if (_canAddMore)
                                      _AddAnotherTile(
                                        isDark: isDark,
                                        text: _logControllers.isEmpty
                                            ? 'Add your gratitude here...'
                                            : 'Add another...',
                                        onTap: _addAnother,
                                      ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 30),

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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.55),
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
                        text: completedTodayForUi
                            ? 'Completed Today'
                            : _submitting
                            ? 'Saving...'
                            : 'Save My Gratitude Logs',
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

class _GratitudeTile extends StatelessWidget {
  final int number;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool isDark;
  final bool showRemove;
  final VoidCallback onRemove;
  final ValueChanged<String> onChanged;

  const _GratitudeTile({
    required this.number,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.isDark,
    required this.showRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = isDark
        ? const Color(0xFF2B2B2B)
        : const Color(0xFFF4F7FD);

    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final numberBg = isDark
        ? AppColors.primaryDark.withOpacity(0.28)
        : AppColors.primaryLight.withOpacity(0.20);

    final textColor = isDark ? Colors.white : const Color(0xFF2F2F2F);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.fromLTRB(8, 10, 10, 10),
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
            margin: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(color: numberBg, shape: BoxShape.circle),
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

          const SizedBox(width: 14),

          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onChanged: onChanged,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: 'Add your gratitude here...',
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  color: textColor.withOpacity(0.32),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          if (showRemove) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: textColor.withOpacity(0.38),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddAnotherTile extends StatelessWidget {
  final bool isDark;
  final String text;
  final VoidCallback onTap;

  const _AddAnotherTile({
    required this.isDark,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withOpacity(0.45)
        : Colors.black.withOpacity(0.28);

    final textColor = isDark
        ? Colors.white.withOpacity(0.50)
        : Colors.black.withOpacity(0.40);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: borderColor,
          radius: 9,
          strokeWidth: 1,
          dashWidth: 2.8,
          dashGap: 3.2,
        ),
        child: Container(
          width: double.infinity,
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(Icons.add, size: 24, color: textColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: textColor,
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

class _GratitudeLogSkeleton extends StatelessWidget {
  final bool isDark;
  final bool completedToday;
  final bool showHistorySkeleton;

  const _GratitudeLogSkeleton({
    required this.isDark,
    required this.completedToday,
    required this.showHistorySkeleton,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
      highlightColor: isDark
          ? const Color(0xFF3A3A3A)
          : const Color(0xFFF6F8FC),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SkeletonBox(width: 220, height: 26, radius: 8),

            const SizedBox(height: 10),

            const _SkeletonBox(width: double.infinity, height: 14, radius: 6),
            const SizedBox(height: 8),
            const _SkeletonBox(width: 240, height: 14, radius: 6),

            const SizedBox(height: 38),

            if (completedToday)
              const Opacity(
                opacity: 0.45,
                child: Column(
                  children: [
                    _GratitudeTileSkeleton(showRemoveSpace: false),
                    SizedBox(height: 10),
                    _GratitudeTileSkeleton(showRemoveSpace: false),
                    SizedBox(height: 10),
                    _GratitudeTileSkeleton(showRemoveSpace: false),
                  ],
                ),
              )
            else
              const _AddGratitudeTileSkeleton(),

            if (showHistorySkeleton) ...[
              const SizedBox(height: 30),

              const _SkeletonBox(width: 170, height: 18, radius: 6),

              const SizedBox(height: 14),

              const _HistoryPreviewSkeleton(),

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

class _GratitudeTileSkeleton extends StatelessWidget {
  final bool showRemoveSpace;

  const _GratitudeTileSkeleton({this.showRemoveSpace = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.fromLTRB(8, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkeletonCircle(size: 20),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                _SkeletonBox(width: double.infinity, height: 16, radius: 6),
                SizedBox(height: 10),
                _SkeletonBox(width: 190, height: 14, radius: 6),
              ],
            ),
          ),

          if (showRemoveSpace) ...[
            const SizedBox(width: 8),
            const _SkeletonCircle(size: 18),
          ],
        ],
      ),
    );
  }
}

class _AddGratitudeTileSkeleton extends StatelessWidget {
  const _AddGratitudeTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: Colors.white,
        radius: 9,
        strokeWidth: 1,
        dashWidth: 2.8,
        dashGap: 3.2,
      ),
      child: Container(
        width: double.infinity,
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Row(
          children: [
            _SkeletonCircle(size: 24),
            SizedBox(width: 14),
            Expanded(child: _SkeletonBox(height: 16, radius: 6)),
          ],
        ),
      ),
    );
  }
}

class _HistoryPreviewSkeleton extends StatelessWidget {
  const _HistoryPreviewSkeleton();

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

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashGap != dashGap;
  }
}
