import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../chat/history_chat_screen.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/primary_button.dart';
import '../../../../routes/app_routes.dart';

// API
import '../../../../main.dart';

class HistorySession {
  final String id;
  final String title;
  final DateTime createdAt;
  final String status;

  HistorySession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.status,
  });

  HistorySession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    String? status,
  }) {
    return HistorySession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  factory HistorySession.fromJson(Map<String, dynamic> json) {
    return HistorySession(
      id: (json['id'] ??
              json['_id'] ??
              json['sessionId'] ??
              json['session_id'] ??
              '')
          .toString(),
      title: (json['title'] ??
              json['sessionTitle'] ??
              json['session_title'] ??
              'Untitled Session')
          .toString(),
      createdAt: _parseDate(
        json['createdAt'] ??
            json['created_at'] ??
            json['updatedAt'] ??
            json['updated_at'],
      ),
      status: (json['status'] ??
              json['sessionStatus'] ??
              json['session_status'] ??
              'completed')
          .toString()
          .toLowerCase(),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistorySession> _sessions = [];
  bool _loading = true;
  bool _error = false;
  bool _clearingAll = false;
  String? _deletingSessionId;
  String? _openDeleteSessionId;
  bool _argsRead = false;
  bool _fromMyProfile = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_argsRead) return;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map) {
      _fromMyProfile = args['source'] == 'myProfile';
    }

    _argsRead = true;
  }

  void _handleBack() {
    if (_fromMyProfile) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  String? _normalizeKnownStatus(dynamic value) {
    final s = value?.toString().toLowerCase().trim() ?? '';

    if (s == 'expired' || s == 'session_expired') {
      return 'expired';
    }

    if (s == 'completed' || s == 'complete' || s == 'closed') {
      return 'completed';
    }

    if (s == 'active' || s == 'incomplete' || s == 'ongoing') {
      return 'active';
    }

    return null;
  }

  String _normalizeHistoryStatus(String status) {
    return _normalizeKnownStatus(status) ?? 'completed';
  }

  bool _truthy(dynamic value) {
    if (value == true) return true;

    final s = value?.toString().toLowerCase().trim() ?? '';
    return s == 'true' || s == '1' || s == 'yes';
  }

  Future<String> _resolveCurrentSessionStatus(HistorySession session) async {
    try {
      final res = await AppServices.apiClient.dio.get(
        '/chat/sessions/${session.id}/status',
      );

      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data)
          : <String, dynamic>{};

      final directStatus =
          _normalizeKnownStatus(data['computedStatus']) ??
          _normalizeKnownStatus(data['computed_status']) ??
          _normalizeKnownStatus(data['status']) ??
          _normalizeKnownStatus(data['sessionStatus']) ??
          _normalizeKnownStatus(data['session_status']);

      // Completed must always stay completed.
      // Even if backend sends forceNewSession because time has passed,
      // completed sessions should not become expired.
      if (directStatus == 'completed' ||
          _truthy(data['isCompleted']) ||
          _truthy(data['is_completed']) ||
          _truthy(data['completed']) ||
          _truthy(data['reportReady']) ||
          _truthy(data['report_ready']) ||
          _truthy(data['summaryReady']) ||
          _truthy(data['summary_ready']) ||
          _truthy(data['screeningSummaryReady']) ||
          _truthy(data['screening_summary_ready'])) {
        return 'completed';
      }

      // Expiry applies only to unfinished/active sessions.
      if (directStatus == 'expired' ||
          _truthy(data['forceNewSession']) ||
          _truthy(data['force_new_session']) ||
          _truthy(data['isExpired']) ||
          _truthy(data['is_expired']) ||
          _truthy(data['expired']) ||
          _truthy(data['sessionExpired']) ||
          _truthy(data['session_expired'])) {
        return 'expired';
      }

      if (directStatus == 'active' ||
          _truthy(data['showOptions']) ||
          _truthy(data['show_options']) ||
          _truthy(data['shouldShowWelcomeBack']) ||
          _truthy(data['should_show_welcome_back']) ||
          _truthy(data['isIncomplete']) ||
          _truthy(data['is_incomplete'])) {
        return 'active';
      }

      return _normalizeHistoryStatus(session.status);
    } catch (_) {
      return _normalizeHistoryStatus(session.status);
    }
  }

  Future<List<HistorySession>> _attachCurrentStatuses(
    List<HistorySession> sessions,
  ) async {
    return Future.wait(
      sessions.map((session) async {
        final currentStatus = await _resolveCurrentSessionStatus(session);
        return session.copyWith(status: currentStatus);
      }),
    );
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final res = await AppServices.apiClient.dio.get(
        '/chat/sessions',
        queryParameters: {
          'page': 1,
          'limit': 50,
        },
      );

      dynamic raw = res.data;

      if (raw is Map) {
        raw = raw['items'] ??
            raw['sessions'] ??
            raw['data'] ??
            raw['results'] ??
            [];
      }

      final list = raw is List ? raw : [];

      final sessions = list
          .whereType<Map>()
          .map((e) => HistorySession.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.id.trim().isNotEmpty)
          .toList();

      final sessionsWithCurrentStatus = await _attachCurrentStatuses(sessions);

      sessionsWithCurrentStatus.sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      );

      if (!mounted) return;

      setState(() {
        _sessions = sessionsWithCurrentStatus;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = true;
      });

      _showError('Failed to load chat history.');
    }
  }

  Future<void> _deleteSession(String id) async {
    if (_deletingSessionId != null || _clearingAll) return;

    setState(() => _deletingSessionId = id);

    try {
      await AppServices.apiClient.dio.delete('/chat/sessions/$id');

      if (!mounted) return;

      setState(() {
        _sessions.removeWhere((s) => s.id == id);
        _openDeleteSessionId = null;
        _deletingSessionId = null;
      });

      _showSuccess('Session deleted.');
    } catch (_) {
      if (!mounted) return;

      setState(() => _deletingSessionId = null);
      _showError('Failed to delete session.');
    }
  }

  Future<void> _clearAll() async {
    if (_clearingAll || _deletingSessionId != null) return;

    setState(() => _clearingAll = true);

    try {
      await AppServices.apiClient.dio.delete('/chat/sessions');

      if (!mounted) return;

      setState(() {
        _sessions.clear();
        _openDeleteSessionId = null;
        _clearingAll = false;
      });

      _showSuccess('All chat history cleared.');
    } catch (_) {
      if (!mounted) return;

      setState(() => _clearingAll = false);
      _showError('Failed to clear chat history.');
    }
  }

  bool _isActiveSession(HistorySession session) {
    final status = session.status.toLowerCase().trim();

    return status == 'active' ||
        status == 'incomplete' ||
        status == 'ongoing';
  }

  Future<void> _openHistorySession(HistorySession session) async {
    setState(() => _openDeleteSessionId = null);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryChatScreen(
          sessionId: session.id,
          title: session.title,
          status: session.status,
        ),
      ),
    );

    if (mounted) _loadHistory();
  }

  Widget _buildBody(bool isDark) {
    if (_loading) {
      return _HistoryListSkeleton(
        isDark: isDark,
        itemCount: _sessions.isNotEmpty ? _sessions.length : 3,
      );
    }

    if (_error && _sessions.isEmpty) {
      return _HistoryEmptyState(
        isDark: isDark,
        title: 'Could not load history',
        subtitle: 'Please check your connection and try again.',
        buttonText: 'Retry',
        onTap: _loadHistory,
      );
    }

    if (_sessions.isEmpty) {
      return _HistoryEmptyState(
        isDark: isDark,
        title: 'No chat history yet',
        subtitle:
            'Start a new conversation with EMLY. Your active, completed, and expired sessions will appear here.',
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
      onRefresh: _loadHistory,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final s = _sessions[i];
          final deletingThis = _deletingSessionId == s.id;

          return _HistoryItem(
            session: s,
            isDark: isDark,
            isDeleteOpen: _openDeleteSessionId == s.id,
            onOpen: () => _openHistorySession(s),
            onDelete: deletingThis ? () {} : () => _deleteSession(s.id),
            onOpenDelete: () {
              setState(() => _openDeleteSessionId = s.id);
            },
            onCloseDelete: () {
              setState(() => _openDeleteSessionId = null);
            },
          );
        },
      ),
    );
  }

  void _showClearAllSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Clear All History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to clear all history?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: _sheetButton(context, 'Cancel', filled: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _clearAll();
                      },
                      child: _sheetButton(context, 'Clear All', filled: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              /// APP BAR
              Row(
                children: [
                  IconButton(
                    onPressed: _handleBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Text(
                    _fromMyProfile ? 'My Sessions' : 'History',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_sessions.isNotEmpty)
                    TextButton(
                      onPressed: _showClearAllSheet,
                      child: Text(
                        'Clear All',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              Expanded(child: _buildBody(isDark)),
            ],
          ),
        ),

        /// BOTTOM NAV
        bottomNavigationBar: _fromMyProfile
          ? null
          : BottomNavBar(
              currentIndex: 3,
              onTap: (i) {
                if (i == 1) {
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.chat,
                    arguments: {'startFresh': true},
                  );
                }

                if (i == 2) {
                  Navigator.pushReplacementNamed(context, AppRoutes.cbt);
                }

                if (i == 4) {
                  Navigator.pushReplacementNamed(context, AppRoutes.settings);
                }
              },
            ),
      ),
    );
  }

  static Widget _sheetButton(
    BuildContext context,
    String text, {
    required bool filled,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled
            ? (isDark
                ? AppColors.primaryDark
                : AppColors.primaryLight)
            : (isDark
                ? const Color(0xFF2B2B2B)
                : const Color(0xFFF4F7FD)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: filled
              ? Colors.white
              : (isDark
                  ? Colors.white
                  : AppColors.primaryLight),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onTap;

  const _HistoryEmptyState({
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
              child: PrimaryButton(
                text: buttonText,
                onTap: onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryListSkeleton extends StatelessWidget {
  final bool isDark;
  final int itemCount;

  const _HistoryListSkeleton({
    required this.isDark,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
      highlightColor:
          isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF6F8FC),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const _HistoryItemSkeleton(),
      ),
    );
  }
}

class _HistoryItemSkeleton extends StatelessWidget {
  const _HistoryItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 18, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SkeletonBox(width: 190, height: 14, radius: 6),

                  SizedBox(height: 10),

                  Row(
                    children: [
                      Flexible(
                        child: _SkeletonBox(
                          width: 150,
                          height: 12,
                          radius: 6,
                        ),
                      ),
                      SizedBox(width: 10),
                      _SkeletonBox(width: 66, height: 14, radius: 9),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(width: 12),

            _SkeletonBox(width: 16, height: 14, radius: 4),
          ],
        ),
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

/// ─────────────────────────────────────────
/// HISTORY ITEM WIDGET
/// ─────────────────────────────────────────
class _HistoryItem extends StatelessWidget {
  final HistorySession session;
  final bool isDark;
  final bool isDeleteOpen;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onOpenDelete;
  final VoidCallback onCloseDelete;

  const _HistoryItem({
    required this.session,
    required this.isDark,
    required this.isDeleteOpen,
    required this.onOpen,
    required this.onDelete,
    required this.onOpenDelete,
    required this.onCloseDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDeleteOpen ? onCloseDelete : onOpen,
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2B2B2B)
              : const Color(0xFFF4F7FD),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            if (isDeleteOpen)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 74,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF63A3A),
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(16),
                    ),
                  ),
                  child: IconButton(
                    icon: Image.asset(
                      'assets/images/Delete.png',
                      width: 22,
                      height: 22,
                      color: Colors.white,
                    ),
                    onPressed: onDelete,
                  ),
                ),
              ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              left: 0,
              top: 0,
              bottom: 0,

              right: isDeleteOpen ? 74 : 0,

              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _formatDate(session.createdAt),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _SessionStatusTag(status: session.status),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (!isDeleteOpen)
                      GestureDetector(
                        onTap: onOpenDelete,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Image.asset(
                            'assets/images/LeftArrow.png',
                            width: 16,
                            height: 14,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final amPm = d.hour >= 12 ? 'PM' : 'AM';

    return '${d.day.toString().padLeft(2, '0')} '
        '${_month(d.month)} ${d.year} | '
        '${hour12.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')} $amPm';
  }

  static String _month(int m) => const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ][m - 1];
}

class _SessionStatusTag extends StatelessWidget {
  final String status;

  const _SessionStatusTag({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase().trim();

    late String label;
    late Color color;
    late Color backgroundColor;

    if (normalized == 'active' ||
        normalized == 'incomplete' ||
        normalized == 'ongoing') {
      label = 'Active';
      color = const Color(0xFF00B96B);
      backgroundColor = const Color(0xFF00B96B).withOpacity(0.12);
    } else if (normalized == 'expired') {
      label = 'Expired';
      color = const Color(0xFFFF3B40);
      backgroundColor = const Color(0xFFFF3B40).withOpacity(0.10);
    } else {
      label = 'Completed';
      color = Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withOpacity(0.72)
          : Colors.black.withOpacity(0.56);
      backgroundColor = Colors.transparent;
    }

    return Container(
      height: 14,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: color,
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 9,
          fontWeight: FontWeight.w400,
          height: 1.0,
          color: color,
        ),
      ),
    );
  }
}