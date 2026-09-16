import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/data/api/api_error.dart';
import '../../../../routes/app_routes.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typing_indicator.dart';


// API
import '../../../../main.dart';


class HistoryChatScreen extends StatefulWidget {
  final String sessionId;
  final String title;
  final String status;

  const HistoryChatScreen({
    super.key,
    required this.sessionId,
    required this.title,
    required this.status,
  });

  @override
  State<HistoryChatScreen> createState() => _HistoryChatScreenState();
}

class _HistoryChatScreenState extends State<HistoryChatScreen> {
  List<Map<String, dynamic>> _messages = [];
  String? _plainSummary;
  bool _loading = true;
  bool _hasUserSentInActiveChat = false;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasInputText = false;
  bool _isTyping = false;
  bool _isVoiceMode = false;

  late String _currentStatus;
  bool _expiredPopupShown = false;

  @override
  void initState() {
    super.initState();

    _currentStatus = _normalizeStatus(widget.status);

    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasInputText) {
        setState(() => _hasInputText = hasText);
      }
    });

    _loadSession();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  String _normalizeStatus(dynamic value) {
      return _normalizeKnownStatus(value) ?? 'active';
    }

    bool _truthy(dynamic value) {
    if (value == true) return true;

    final s = value?.toString().toLowerCase().trim() ?? '';
    return s == 'true' || s == '1' || s == 'yes';
  }

  Future<String> _fetchCurrentStatus() async {
    try {
      final res = await AppServices.apiClient.dio.get(
        '/chat/sessions/${widget.sessionId}/status',
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

      return _currentStatus;
    } catch (_) {
      return _currentStatus;
    }
  }

  bool get _isActive {
    return _currentStatus == 'active';
  }

  bool get _isCompleted {
    return _currentStatus == 'completed';
  }

  bool get _isExpired {
    return _currentStatus == 'expired';
  }

  String get _expiredPopupSeenKey =>
      'expired_session_popup_seen_${widget.sessionId}';

  Future<bool> _hasSeenExpiredPopupBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_expiredPopupSeenKey) ?? false;
  }

  Future<void> _markExpiredPopupSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_expiredPopupSeenKey, true);
  }

  List<Map<String, dynamic>> _parseMessages(dynamic data) {
    dynamic raw = data;

    if (data is Map) {
      raw = data['messages'] ??
          data['items'] ??
          data['data'] ??
          data['conversation'] ??
          [];
    }

    if (raw is! List) return [];

    return raw.whereType<Map>().map((m) {
      final map = Map<String, dynamic>.from(m);

      return {
        'text': (map['text'] ??
                map['content'] ??
                map['message'] ??
                map['body'] ??
                '')
            .toString(),
        'role': (map['role'] ??
                map['sender'] ??
                map['author'] ??
                'assistant')
            .toString()
            .toLowerCase(),
        'createdAt': (map['createdAt'] ??
                map['created_at'] ??
                map['timestamp'] ??
                DateTime.now().toIso8601String())
            .toString(),
      };
    }).toList();
  }

  Future<void> _loadSession() async {
    try {
      final currentStatus = await _fetchCurrentStatus();

      final sessionRes = await AppServices.apiClient.dio.get(
        '/chat/sessions/${widget.sessionId}',
      );

      final messages = _parseMessages(sessionRes.data);

      String? summary;

      if (currentStatus == 'completed') {
        try {
          final reportRes = await AppServices.apiClient.dio.get(
            '/chat/sessions/${widget.sessionId}/report',
          );

          if (reportRes.data is Map) {
            final data = Map<String, dynamic>.from(reportRes.data);
            summary = (data['plain_summary'] ?? data['plainSummary'])?.toString();
          }
        } catch (_) {
          summary = null;
        }
      }

      if (!mounted) return;

      setState(() {
        _currentStatus = currentStatus;
        _messages = messages;
        _plainSummary = summary;
        _loading = false;
      });

      _scrollToBottom();

      if (currentStatus == 'expired') {
        final alreadyShown = await _hasSeenExpiredPopupBefore();

        if (!alreadyShown && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showExpiredSessionPopupIfNeeded();
          });
        }
      }
    } catch (_) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load this session.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _showExpiredSessionPopupIfNeeded() async {
    if (!mounted || _expiredPopupShown || !_isExpired) return;

    final alreadyShown = await _hasSeenExpiredPopupBefore();
    if (alreadyShown) return;

    _expiredPopupShown = true;
    await _markExpiredPopupSeen();

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                'Session Expired',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'This session has expired due to inactivity. You can review the previous chat, but you cannot continue this session.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.68),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 49,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Text(
                    'Okay',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendMessageInActiveHistoryChat() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _isTyping) return;

    final userCreatedAt = DateTime.now().toIso8601String();

    final userMessage = {
      'text': text,
      'role': 'user',
      'createdAt': userCreatedAt,
    };

    bool assistantAdded = false;

    setState(() {
      _messages.add(userMessage);
      _controller.clear();
      _isTyping = true;

      // Same behavior as original chat screen:
      // after user continues active chat, hide Active tag and show toggle.
      _hasUserSentInActiveChat = true;
      _isVoiceMode = false;
    });

    _scrollToBottom();

    try {
      final res = await AppServices.apiClient.dio.post(
        '/chat/message',
        data: {
          'sessionId': widget.sessionId,
          'message': text,
          'inputMode': 'text',
        },
      );

      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data)
          : <String, dynamic>{};

      final rawAssistant = data['assistantMessage'];

      final assistant = rawAssistant is Map
          ? Map<String, dynamic>.from(rawAssistant)
          : <String, dynamic>{};

      final assistantText = (assistant['text'] ??
              assistant['content'] ??
              assistant['message'] ??
              assistant['body'] ??
              '')
          .toString()
          .trim();

      final assistantCreatedAt = (assistant['createdAt'] ??
              assistant['created_at'] ??
              DateTime.now().toIso8601String())
          .toString();

      if (!mounted) return;

      setState(() {
        if (assistantText.isNotEmpty) {
          _messages.add({
            'text': assistantText,
            'role': 'assistant',
            'createdAt': assistantCreatedAt,
          });

          assistantAdded = true;
        }

        _isTyping = false;
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('HISTORY SEND ERROR: $e');

      if (!mounted) return;

      // Important:
      // If assistant reply already appeared, do NOT show false error.
      if (assistantAdded) {
        setState(() => _isTyping = false);
        return;
      }

      setState(() {
        _messages.removeWhere(
          (m) => m['createdAt'] == userCreatedAt,
        );
        _isTyping = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildBottomArea(bool isDark) {
    if (_loading) {
      return _HistoryBottomSkeleton(
        isDark: isDark,
        status: _currentStatus,
      );
    }

    if (_isActive) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
        child: PrimaryButton(
          text: 'Continue Chat',
          onTap: () {
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.chat,
              arguments: {
                'sessionId': widget.sessionId,
                'source': 'history',
              },
            );
          },
        ),
      );
    }

    if (_isCompleted) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: PrimaryButton(
          text: 'View Report',
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.individualReport,
              arguments: {
                'sessionId': widget.sessionId,
              },
            );
          },
        ),
      );
    }

    if (_isExpired) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
        child: _ExpiredChatNotice(isDark: isDark),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            /// APP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: 32,
                        height: 40,
                        child: Icon(
                          Icons.arrow_back,
                          size: 26,
                          color: textColor,
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    Text(
                      'My Chat',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: textColor,
                      ),
                    ),

                    const Spacer(),

                    if (_isActive && !_hasUserSentInActiveChat)
                      _ChatStatusTag(status: 'active'),

                    if (_isActive && _hasUserSentInActiveChat)
                      _HistoryModeToggle(
                        isDark: isDark,
                        isVoiceMode: _isVoiceMode,
                        onChatTap: () {
                          setState(() => _isVoiceMode = false);
                        },
                        onVoiceTap: () {
                          setState(() => _isVoiceMode = true);
                        },
                      ),

                    if (_isCompleted)
                      _ChatStatusTag(status: 'completed'),

                    if (_isExpired)
                      _ChatStatusTag(status: 'expired'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            if (_loading)
              Expanded(
                child: _HistoryChatSkeleton(
                  isDark: isDark,
                  messageCount: _messages.isNotEmpty ? _messages.length : 6,
                  bottomPadding: (_isCompleted || _isExpired) ? 96 : 16,
                ),
              ),

            if (!_loading)
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    (_isCompleted || _isExpired) ? 96 : 16,
                  ),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isTyping && index == _messages.length) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(top: 6, bottom: 6, right: 50),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2B2B2B)
                                : const Color(0xFFF4F7FD),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const TypingIndicator(),
                        ),
                      );
                    }

                    final m = _messages[index];

                    return _HistoryChatBubble(
                      text: m['text']?.toString() ?? '',
                      fromUser: m['role'] == 'user',
                      isDark: isDark,
                    );
                  },
                ),
              ),

            _buildBottomArea(isDark),
          ],
        ),
      ),
    );
  }
}

class _HistoryChatSkeleton extends StatelessWidget {
  final bool isDark;
  final int messageCount;
  final double bottomPadding;

  const _HistoryChatSkeleton({
    required this.isDark,
    required this.messageCount,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
      highlightColor:
          isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF6F8FC),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          bottomPadding,
        ),
        itemCount: messageCount,
        itemBuilder: (context, index) {
          final fromUser = index % 3 == 1;

          if (fromUser) {
            return _HistoryChatBubbleSkeleton(
              fromUser: true,
              width: index.isEven ? 210 : 180,
              lineWidths: index.isEven
                  ? const [165, 108]
                  : const [138],
            );
          }

          return _HistoryChatBubbleSkeleton(
            fromUser: false,
            width: index.isEven ? 260 : 230,
            lineWidths: index.isEven
                ? const [220, 190, 128]
                : const [190, 142],
          );
        },
      ),
    );
  }
}

class _HistoryChatBubbleSkeleton extends StatelessWidget {
  final bool fromUser;
  final double width;
  final List<double> lineWidths;

  const _HistoryChatBubbleSkeleton({
    required this.fromUser,
    required this.width,
    required this.lineWidths,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: width,
        margin: EdgeInsets.only(
          top: 6,
          bottom: 6,
          left: fromUser ? 48 : 0,
          right: fromUser ? 0 : 50,
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            lineWidths.length,
            (index) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == lineWidths.length - 1 ? 0 : 8,
                ),
                child: _SkeletonBox(
                  width: lineWidths[index],
                  height: 16,
                  radius: 6,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HistoryBottomSkeleton extends StatelessWidget {
  final bool isDark;
  final String status;

  const _HistoryBottomSkeleton({
    required this.isDark,
    required this.status,
  });

  bool get _isExpiredStatus {
    return status.toLowerCase().trim() == 'expired';
  }

  @override
  Widget build(BuildContext context) {
    if (_isExpiredStatus) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
        child: Shimmer.fromColors(
          baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
          highlightColor:
              isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF6F8FC),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SkeletonBox(width: 16, height: 16, radius: 4),
              SizedBox(width: 6),
              Flexible(
                child: _SkeletonBox(
                  width: 260,
                  height: 13,
                  radius: 6,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        status.toLowerCase().trim() == 'active' ? 22 : 18,
      ),
      child: Shimmer.fromColors(
        baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
        highlightColor:
            isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF6F8FC),
        child: const _SkeletonBox(
          width: double.infinity,
          height: 54,
          radius: 28,
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

class _ChatStatusTag extends StatelessWidget {
  final String status;

  const _ChatStatusTag({
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
      backgroundColor = const Color(0xFF00B96B).withOpacity(0.10);
    } else if (normalized == 'expired') {
      label = 'Expired';
      color = const Color(0xFFFF3B40);
      backgroundColor = const Color(0xFFFF3B40).withOpacity(0.08);
    } else {
      label = 'completed';
      color = Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withOpacity(0.72)
          : Colors.black.withOpacity(0.56);
      backgroundColor = Colors.transparent;
    }

    return Container(
      height: 23,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.0,
          color: color,
        ),
      ),
    );
  }
}

class _HistoryChatBubble extends StatelessWidget {
  final String text;
  final bool fromUser;
  final bool isDark;

  const _HistoryChatBubble({
    required this.text,
    required this.fromUser,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = fromUser
        ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
        : (isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD));

    final textColor = fromUser
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF252525));

    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 6,
          bottom: 6,
          left: fromUser ? 48 : 0,
          right: fromUser ? 0 : 50,
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.28,
            letterSpacing: -0.1,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _HistoryInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final bool hasInputText;
  final bool isTyping;
  final VoidCallback onSend;
  final VoidCallback onMicTap;

  const _HistoryInputBar({
    required this.controller,
    required this.isDark,
    required this.hasInputText,
    required this.isTyping,
    required this.onSend,
    required this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.08),
                  width: 1,
                ),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                cursorColor: buttonColor,
                enabled: !isTyping,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                  color: isDark ? Colors.white : const Color(0xFF252525),
                ),
                decoration: InputDecoration(
                  hintText: 'Ask me anything...',
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? Colors.white.withOpacity(0.45)
                        : const Color(0xFFB8B8B8),
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (hasInputText && !isTyping) onSend();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              if (isTyping) return;

              if (hasInputText) {
                onSend();
              } else {
                onMicTap();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.only(bottom: 3),
              decoration: BoxDecoration(
                color: buttonColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: hasInputText
                    ? const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 21,
                      )
                    : Image.asset(
                        'assets/images/Mic.png',
                        width: 22,
                        height: 22,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryModeToggle extends StatelessWidget {
  final bool isDark;
  final bool isVoiceMode;
  final VoidCallback onChatTap;
  final VoidCallback onVoiceTap;

  const _HistoryModeToggle({
    required this.isDark,
    required this.isVoiceMode,
    required this.onChatTap,
    required this.onVoiceTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor =
        isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Container(
      width: 61,
      height: 30,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFFF2F2F2) : const Color(0xFFF1F3FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onChatTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: !isVoiceMode ? selectedColor : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/Keyboard.png',
                  width: 16,
                  height: 16,
                  color: !isVoiceMode ? Colors.white : const Color(0xFF9D9D9D),
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(width: 1),
          GestureDetector(
            onTap: onVoiceTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isVoiceMode ? selectedColor : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/Voice.png',
                  width: 16,
                  height: 16,
                  color: isVoiceMode ? Colors.white : const Color(0xFFB8B8B8),
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiredChatNotice extends StatelessWidget {
  final bool isDark;

  const _ExpiredChatNotice({
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDark
        ? Colors.white.withOpacity(0.68)
        : Colors.black.withOpacity(0.58);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/ChatNotAllowed.png',
          width: 16,
          height: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Due to inactivity, this chat has been expired',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.2,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

