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

class PleasantActivitiesScreen extends StatefulWidget {
  const PleasantActivitiesScreen({super.key});

  @override
  State<PleasantActivitiesScreen> createState() =>
      _PleasantActivitiesScreenState();
}

class _PleasantActivitiesScreenState extends State<PleasantActivitiesScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _noteController = TextEditingController();

  bool _argsRead = false;
  bool _loading = true;
  bool _submitting = false;
  bool _showPastEntries = false;
  bool _forceCompletedToday = false;
  bool? _completedTodayHint;

  String? _activityId;
  String _title = 'Pleasant Activities';
  String _subtitle = 'Try one each day';

  List<_PleasantActivityItem> _activities = [];
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
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadActivity() async {
    setState(() => _loading = true);

    try {
      // Fallback if opened directly without dashboard route args.
      if (_activityId == null || _activityId!.trim().isEmpty) {
        final plan = await AppServices.therapyRepository.getPlan();

        TherapyActivity? pleasantActivity;

        if (plan != null) {
          for (final activity in plan.activities) {
            final type = activity.type.toLowerCase();
            final title = activity.title.toLowerCase();

            if (type.contains('pleasant') ||
                type.contains('behavioral') ||
                title.contains('pleasant')) {
              pleasantActivity = activity;
              break;
            }
          }
        }

        if (pleasantActivity != null) {
          _activityId = pleasantActivity.id;
          _title = pleasantActivity.title;
          _subtitle = pleasantActivity.subtitle;
          _activities = _activitiesFromContent(pleasantActivity.content);
          _completedTodayHint = pleasantActivity.isCompletedToday;
        }
      }

      if (_activities.isEmpty) {
        _activities = _defaultActivities();
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
        if (_activities.isEmpty) {
          _activities = _defaultActivities();
        }
        _loading = false;
      });

      _showError(
        e.message.isNotEmpty
            ? e.message
            : 'Failed to load Pleasant Activities.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (_activities.isEmpty) {
          _activities = _defaultActivities();
        }
        _loading = false;
      });

      _showError('Failed to load Pleasant Activities.');
    }
  }

  List<_PleasantActivityItem> _activitiesFromContent(
    Map<String, dynamic> content,
  ) {
    final rawList = content['activities'] ??
        content['items'] ??
        content['pleasant_activities'] ??
        content['pleasantActivities'];

    if (rawList is! List) return [];

    return rawList.asMap().entries.map((entry) {
      final item = entry.value;

      if (item is Map) {
        return _PleasantActivityItem(
          title: (item['title'] ??
                  item['label'] ??
                  item['text'] ??
                  'Activity ${entry.key + 1}')
              .toString(),
          isChecked: false,
        );
      }

      return _PleasantActivityItem(
        title: item.toString(),
        isChecked: false,
      );
    }).where((item) => item.title.trim().isNotEmpty).toList();
  }

  List<_PleasantActivityItem> _defaultActivities() {
    return const [
      _PleasantActivityItem(title: '15-min walk', isChecked: false),
      _PleasantActivityItem(title: 'Call a friend', isChecked: false),
      _PleasantActivityItem(title: 'Listen to music', isChecked: false),
      _PleasantActivityItem(title: 'Cook something', isChecked: false),
      _PleasantActivityItem(title: 'Step outside', isChecked: false),
    ];
  }

  bool get _completedToday {
    return _forceCompletedToday ||
        _completedTodayHint == true ||
        _hasTodayHistoryEntry;
  }

  List<int> get _selectedIndices {
    final selected = <int>[];

    for (int i = 0; i < _activities.length; i++) {
      if (_activities[i].isChecked) selected.add(i);
    }

    return selected;
  }

  void _toggleActivity(int index) {
    if (_submitting || _completedToday) return;

    setState(() {
      _activities[index] = _activities[index].copyWith(
        isChecked: !_activities[index].isChecked,
      );
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
      _showError('Activity is missing. Please open it from your CBT plan again.');
      return;
    }

    final completedItems = _selectedIndices;

    if (completedItems.isEmpty) {
      _showError('Select at least one pleasant activity before submitting.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final note = _noteController.text.trim();

      final result = await AppServices.therapyRepository.submitProgress(
        activityId: activityId,
        responseData: {
          'completed_items': completedItems,
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
        activityName: 'Pleasant Activities',
        streakDays: result.streakCount,
        onDone: () {
          Navigator.pushReplacementNamed(context, AppRoutes.cbt);
        },
      );
    } on ApiError catch (e) {
      if (!mounted) return;

      final message = e.message.isNotEmpty
          ? e.message
          : 'Failed to submit Pleasant Activities.';

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

  List<int> _completedIndicesFromHistory(TherapyActivityHistoryItem item) {
    final raw = item.responseData['completed_items'] ??
        item.responseData['completedItems'];

    if (raw is! List) return [];

    return raw
        .map((e) => int.tryParse(e.toString()))
        .whereType<int>()
        .where((index) => index >= 0 && index < _activities.length)
        .toList();
  }

  int _historyScore(TherapyActivityHistoryItem item) {
    final rawScore = item.responseData['_score'];

    if (rawScore is int) return rawScore;
    if (rawScore is double) return rawScore.round();

    final parsed = int.tryParse((rawScore ?? '').toString());
    if (parsed != null) return parsed;

    return _completedIndicesFromHistory(item).length;
  }

  int _historyMaxScore(TherapyActivityHistoryItem item) {
    final rawMax = item.responseData['_max_score'];

    if (rawMax is int) return rawMax;
    if (rawMax is double) return rawMax.round();

    final parsed = int.tryParse((rawMax ?? '').toString());
    if (parsed != null) return parsed;

    return _activities.length;
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
      final completedIndices = _completedIndicesFromHistory(entry);

      final score = _historyScore(entry);
      final maxScore = _historyMaxScore(entry);
      final interpretation = _historyInterpretation(entry);
      final note = _historyNote(entry);

      final lines = <String>[];

      for (final index in completedIndices) {
        lines.add('✓ ${_activities[index].title}');
      }

      if (interpretation != null) {
        lines.add('Interpretation: $interpretation');
      }

      return CbtActivityHistoryViewItem(
        dateLabel: _historyDateLabel(entry.completedAt),
        trailingText: '$score Done',
        lines: lines,
        note: note ?? '$score/$maxScore activities completed',
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
    _title = (args['title'] ?? 'Pleasant Activities').toString();
    _subtitle = (args['subtitle'] ?? 'Try one each day').toString();

    final content = args['content'];

    if (content is Map) {
      _activities = _activitiesFromContent(
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
  }

  void _syncLockedInputsFromTodayHistory() {
    if (!_completedToday) return;

    TherapyActivityHistoryItem? todayEntry = _todayHistoryEntry;

    if (todayEntry == null && _completedTodayHint == true && _history.isNotEmpty) {
      todayEntry = _history.first;
    }

    if (todayEntry == null) return;

    final completedIndices = _completedIndicesFromHistory(todayEntry).toSet();

    if (completedIndices.isNotEmpty) {
      _activities = List.generate(
        _activities.length,
        (index) => _activities[index].copyWith(
          isChecked: completedIndices.contains(index),
        ),
      );
    }

    final note = _historyNote(todayEntry);

    if (note != null && _noteController.text.trim().isEmpty) {
      _noteController.text = note;
    }
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
                    padding: const EdgeInsets.only(right: 26),
                    child: GestureDetector(
                      onTap: () {
                        CbtInfoDialog.show(
                          context: context,
                          title: CbtInfoContent.pleasantActivitiesTitle,
                          description:
                              CbtInfoContent.pleasantActivitiesDescription,
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
                    ? _PleasantActivitiesSkeleton(
                        isDark: isDark,
                        completedToday: completedTodayForUi,
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
                                      : Colors.black.withOpacity(0.42),
                                ),
                              ),

                              const SizedBox(height: 38),

                              Opacity(
                                opacity: completedTodayForUi ? 0.45 : 1,
                                child: Column(
                                  children: List.generate(
                                    _activities.length,
                                    (index) => Padding(
                                      padding: EdgeInsets.only(
                                        bottom:
                                            index == _activities.length - 1
                                                ? 28
                                                : 10,
                                      ),
                                      child: _PleasantActivityTile(
                                        title: _activities[index].title,
                                        isChecked:
                                            _activities[index].isChecked,
                                        isDark: isDark,
                                        onTap: () => _toggleActivity(index),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              Text(
                                'Note? (optional)',
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

                              const SizedBox(height: 12),

                              _PleasantNoteBox(
                                controller: _noteController,
                                enabled: !completedTodayForUi && !_submitting,
                                isDark: isDark,
                              ),

                              const SizedBox(height: 34),

                              CbtActivityHistorySection(
                                isDark: isDark,
                                entries: _historyViewItems,
                                showHistory: _showPastEntries,
                                onToggle: _togglePastEntries,
                              ),

                              const SizedBox(height: 110),
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

class _PleasantActivityTile extends StatelessWidget {
  final String title;
  final bool isChecked;
  final bool isDark;
  final VoidCallback onTap;

  const _PleasantActivityTile({
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
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            _PleasantCheckbox(
              isChecked: isChecked,
              color: primary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
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

class _PleasantCheckbox extends StatelessWidget {
  final bool isChecked;
  final Color color;

  const _PleasantCheckbox({
    required this.isChecked,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
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
    );
  }
}

class _PleasantNoteBox extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool isDark;

  const _PleasantNoteBox({
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
      height: 61,
      padding: const EdgeInsets.fromLTRB(6, 0, 10, 4),
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
          color: textColor.withOpacity(0.74),
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

class _PleasantActivitiesSkeleton extends StatelessWidget {
  final bool isDark;
  final bool completedToday;

  const _PleasantActivitiesSkeleton({
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
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SkeletonBox(width: 230, height: 26, radius: 8),
            const SizedBox(height: 10),
            const _SkeletonBox(width: 180, height: 14, radius: 6),

            const SizedBox(height: 38),

            Opacity(
              opacity: completedToday ? 0.45 : 1,
              child: const Column(
                children: [
                  _PleasantActivityTileSkeleton(),
                  SizedBox(height: 10),
                  _PleasantActivityTileSkeleton(),
                  SizedBox(height: 10),
                  _PleasantActivityTileSkeleton(),
                  SizedBox(height: 10),
                  _PleasantActivityTileSkeleton(),
                  SizedBox(height: 10),
                  _PleasantActivityTileSkeleton(),
                  SizedBox(height: 10),
                  _PleasantActivityTileSkeleton(),
                  SizedBox(height: 28),
                ],
              ),
            ),

            const _SkeletonBox(width: 120, height: 12, radius: 6),

            const SizedBox(height: 12),

            Opacity(
              opacity: completedToday ? 0.45 : 1,
              child: const _SkeletonBox(
                width: double.infinity,
                height: 61,
                radius: 8,
              ),
            ),

            const SizedBox(height: 34),

            const _SkeletonBox(width: 150, height: 18, radius: 6),

            const SizedBox(height: 14),

            completedToday
                ? const _PleasantHistorySkeleton(hasContent: true)
                : const _PleasantHistorySkeleton(hasContent: false),

            const SizedBox(height: 110),
          ],
        ),
      ),
    );
  }
}

class _PleasantActivityTileSkeleton extends StatelessWidget {
  const _PleasantActivityTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
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

class _PleasantHistorySkeleton extends StatelessWidget {
  final bool hasContent;

  const _PleasantHistorySkeleton({
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
              _SkeletonBox(width: 62, height: 16, radius: 6),
            ],
          ),
          SizedBox(height: 12),
          _SkeletonBox(width: 210, height: 13, radius: 6),
          SizedBox(height: 8),
          _SkeletonBox(width: 170, height: 13, radius: 6),
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

class _PleasantActivityItem {
  final String title;
  final bool isChecked;

  const _PleasantActivityItem({
    required this.title,
    required this.isChecked,
  });

  _PleasantActivityItem copyWith({
    String? title,
    bool? isChecked,
  }) {
    return _PleasantActivityItem(
      title: title ?? this.title,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}