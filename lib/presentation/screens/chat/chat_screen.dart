import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/data/chat_store.dart';
import '../../widgets/typing_indicator.dart';
import '../../widgets/primary_button.dart';
import '../../../routes/app_routes.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';
import '../../../../core/data/repositories/chat_session_repository.dart';
import '../../../../core/data/voice/voice_recorder_service.dart';
import '../../../../core/data/voice/stt_service.dart';
import '../../../../core/data/voice/tts_service.dart';

enum VoiceStatus { listening, processing, speaking, idle }

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  bool _chatStarted = false;
  bool _hasInputText = false;
  bool _fromHistory = false;
  bool _sessionExpiredPopupShown = false;
  bool _crisisPopupShown = false;

  /// For future voice screen toggle
  bool _isVoiceMode = false;

  VoiceStatus _voiceStatus = VoiceStatus.listening;

  String _voiceTranscript =
      'Ive been feeling overwhelmed by work\nlately, and I don\'t know where to\nstart...';

  bool get _isVoiceOrbAnimating =>
      _voiceStatus == VoiceStatus.listening ||
      _voiceStatus == VoiceStatus.speaking;

  bool get _isVoiceSpeaking => _voiceStatus == VoiceStatus.speaking;

  final VoiceRecorderService _voiceRecorder = VoiceRecorderService();
  final SttService _sttService = SttService();
  final TtsService _ttsService = TtsService();

  bool get _isVoiceBusy =>
      _voiceStatus == VoiceStatus.processing ||
      _voiceStatus == VoiceStatus.speaking;

  String? _sessionId;
  ChatSession? _currentSession;
  final List<ChatMessage> _messages = [];

  bool _loadingSession = false;
  bool _startFresh = false;
  bool _argsRead = false;
  bool _summaryPopupShown = false;

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasInputText) {
        setState(() => _hasInputText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _voiceRecorder.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_argsRead) return;
    _argsRead = true;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map) {
      _fromHistory = args['source'] == 'history';

      final incomingSessionId = args['sessionId']?.toString();
      final startFresh = args['startFresh'] == true;

      if (startFresh) {
        _startFresh = true;
        _sessionId = null;
        _messages.clear();
        _currentSession = null;
        _chatStarted = false;
        return;
      }

      if (incomingSessionId != null && incomingSessionId.trim().isNotEmpty) {
        _sessionId = incomingSessionId.trim();
        _openExistingSessionWithStatusCheck(_sessionId!);
      }
    }
  }

  void _handleBack() {
    if (_fromHistory) {
      Navigator.pop(context);
      return;
    }

    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  Future<void> _openExistingSessionWithStatusCheck(String sessionId) async {
    try {
      final res = await AppServices.apiClient.dio.get(
        '/chat/sessions/$sessionId/status',
      );

      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data)
          : <String, dynamic>{};

      final forceNewSession = data['forceNewSession'] == true;
      final showOptions = data['showOptions'] == true;

      final gapDescription = (data['gapDescription'] ??
              data['message'] ??
              'Would you like to continue this session or start fresh?')
          .toString();

      if (forceNewSession) {
        _showSessionExpiredDialog(
          message:
              'It has been a while since this session. Please start a fresh session for accurate screening.',
          sessionId: sessionId,
        );
        return;
      }

      if (showOptions) {
        _showWelcomeBackDialog(
          message: gapDescription,
          sessionId: sessionId,
        );
        return;
      }

      await _loadExistingSession(sessionId);
    } catch (_) {
      // If status check fails, still load session normally.
      await _loadExistingSession(sessionId);
    }
  }

  Future<void> _handleStartFreshFromChat({
    String? previousSessionId,
  }) async {
    try {
      final status = await AppServices.subscriptionRepository.getStatus();

      if (!mounted) return;

      if (status.canCreateSession) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.chat,
          arguments: {'startFresh': true},
        );
        return;
      }

      await _showFreeSessionUsedPopupFromChat(
        previousSessionId: previousSessionId,
      );
    } on ApiError catch (e) {
      _showError(
        e.message.isNotEmpty
            ? e.message
            : 'Unable to check subscription status.',
      );
    } catch (_) {
      _showError('Unable to check subscription status.');
    }
  }

  Future<void> _showFreeSessionUsedPopupFromChat({
    String? previousSessionId,
  }) async {
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    void goHome() {
      Navigator.pop(context);
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Free Session Used',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            goHome();
          },
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5.5, sigmaY: 5.5),
                    child: Container(
                      color: isDark
                          ? Colors.black.withOpacity(0.46)
                          : const Color(0xFF7A7692).withOpacity(0.50),
                    ),
                  ),
                ),

                Center(
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.fromLTRB(28, 17, 28, 18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B1B1B) : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE2E2E2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/Star.png',
                              width: 34,
                              height: 34,
                              color: primary,
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        Text(
                          'Free Session Used',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                            color: isDark ? Colors.white : const Color(0xFF252525),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'You’ve already used your free\nscreening session.\nYou can continue your\nunfinished session, or upgrade\nto Premium to start a new one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            height: 1.35,
                            color: isDark
                                ? Colors.white.withOpacity(0.78)
                                : const Color(0xFF676767),
                          ),
                        ),

                        const SizedBox(height: 18),

                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, AppRoutes.subscription);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: double.infinity,
                            height: 49,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: const Text(
                              'Activate Premium',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.0,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        GestureDetector(
                          onTap: () async {
                            Navigator.pop(context);

                            final id = previousSessionId?.trim();

                            if (id != null && id.isNotEmpty) {
                              await _loadExistingSession(id);
                            } else {
                              Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.home,
                              );
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: double.infinity,
                            height: 49,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: const Text(
                              'Continue Previous Session',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.0,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 17),

                        GestureDetector(
                          onTap: goHome,
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Maybe later',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  height: 1.0,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.76)
                                      : const Color(0xFF676767),
                                ),
                              ),
                              const SizedBox(width: 18),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 21,
                                color: isDark
                                    ? Colors.white.withOpacity(0.76)
                                    : const Color(0xFF676767),
                              ),
                            ],
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
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showWelcomeBackDialog({
    required String message,
    required String sessionId,
  }) async {
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
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
                'Welcome Back',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                message,
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
                onTap: () {
                  Navigator.pop(context);
                  _loadExistingSession(sessionId);
                },
                child: Container(
                  height: 49,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _handleStartFreshFromChat(previousSessionId: sessionId);
                },
                child: Container(
                  height: 49,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    'Start Fresh',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      color: isDark
                                    ? Colors.white
                                    : AppColors.primaryLight,
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

  Future<void> _loadExistingSession(String sessionId) async {
    setState(() => _loadingSession = true);

    try {
      final detail = await AppServices.chatSessionRepository.getSessionDetail(
        sessionId,
      );

      final loadedMessages = detail.messages
          .where((m) => m.text.trim().isNotEmpty)
          .map(
            (m) => ChatMessage(
              text: m.text,
              fromUser: m.fromUser,
              time: m.createdAt,
            ),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _sessionId = detail.id;
        _messages
          ..clear()
          ..addAll(loadedMessages);

        _currentSession = ChatSession(
          id: detail.id,
          title: detail.title,
          createdAt: detail.createdAt,
          messages: _messages,
        );

        _chatStarted = _messages.isNotEmpty;
        _loadingSession = false;
      });

      _scrollToBottom();
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() => _loadingSession = false);
      _showError(e.message.isNotEmpty ? e.message : 'Failed to load session.');
    } catch (_) {
      if (!mounted) return;

      setState(() => _loadingSession = false);
      _showError('Failed to load session.');
    }
  }

  // ---------------- SEND MESSAGE ----------------
  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();

    if (trimmed.isEmpty || _isTyping || _loadingSession) return;

    final userTime = DateTime.now();

    final userMsg = ChatMessage(
      text: trimmed,
      fromUser: true,
      time: userTime,
    );

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
      _controller.clear();
      _chatStarted = true;
    });

    _scrollToBottom();

    try {
      final result = await AppServices.chatSessionRepository.sendMessage(
        sessionId: _sessionId,
        message: trimmed,
        inputMode: 'text',
      );

      final assistant = result.assistantMessage;

      final botMsg = ChatMessage(
        text: assistant.text,
        fromUser: false,
        time: assistant.createdAt,
      );

      if (!mounted) return;

      setState(() {
        _sessionId = result.sessionId.isNotEmpty
            ? result.sessionId
            : _sessionId;
        _messages.add(botMsg);
        _isTyping = false;
        _startFresh = false;

        _currentSession = ChatSession(
          id: _sessionId ?? result.sessionId,
          title: result.sessionTitle,
          createdAt: result.sessionCreatedAt,
          messages: List<ChatMessage>.from(_messages),
        );
      });

      if (_currentSession != null) {
        chatStore.upsertSession(_currentSession!);
      }

      _handleAssistantMeta(assistant.meta);

      _scrollToBottom();
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.removeWhere((m) => m.time == userTime && m.fromUser);
        _isTyping = false;
      });

      // 403 from chat can be subscription or email verification.
      if (e.statusCode == 403) {
        final msg = e.message.toLowerCase();

        if (msg.contains('verify')) {
          _showError(e.message);
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.accountCreationOtp,
            arguments: {'email': ''},
          );
          return;
        }

        if (msg.contains('upgrade') ||
            msg.contains('free plan') ||
            msg.contains('subscription')) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
          _showError(
            'Free session used. Please activate Premium or continue your previous session.',
          );
          return;
        }
      }

      _showError(e.message.isNotEmpty ? e.message : 'Failed to send message');
    } catch (_) {
      if (!mounted) return;

      setState(() => _isTyping = false);
      _showError('Failed to send message');
    }
  }

  void _handleAssistantMeta(Map<String, dynamic> meta) {
    if (meta.isEmpty) return;

    final reportReady =
        meta['screeningSummaryReady'] == true ||
        meta['summaryReady'] == true ||
        meta['reportReady'] == true;

    if (reportReady && !_summaryPopupShown) {
      _summaryPopupShown = true;
      _showScreeningSummaryReadyPopup();
    }

    if (meta['therapyPlanCreated'] == true) {
      _showSuccess('Your personalized CBT plan is ready!');
    }

    if (meta['sessionExpired'] == true && !_sessionExpiredPopupShown) {
      _sessionExpiredPopupShown = true;

      _showSessionExpiredDialog(
        message:
            'This session has expired. Please start a fresh session for accurate screening.',
        sessionId: _sessionId,
      );
    }

    if (meta.containsKey('gapType')) {
      // Backend already handles gap wording in assistant text.
    }

    if (meta.containsKey('crisisActions')) {
      final actions = meta['crisisActions'];

      if (actions is Map &&
          actions['showEmergencyButtons'] == true &&
          !_crisisPopupShown) {
        _crisisPopupShown = true;
        _showEmergencySupportPopup();
      }
    }
  }

  Future<void> _showEmergencySupportPopup() async {
    if (!mounted) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Emergency Support',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _EmergencySupportPopup(
          onLikeSupport: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.findDoctor);
          },
          onEmergencyContact: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.emergencyContacts);
          },
          onKeepTalking: () {
            Navigator.pop(context);
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showSessionExpiredDialog({
    required String message,
    required String? sessionId,
  }) async {
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
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
                message,
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
                onTap: () {
                  Navigator.pop(context);
                  _handleStartFreshFromChat(previousSessionId: sessionId);
                },
                child: Container(
                  height: 49,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Text(
                    'Start New Session',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (sessionId != null && sessionId.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      AppRoutes.individualReport,
                      arguments: {
                        'sessionId': sessionId,
                      },
                    );
                  },
                  child: Container(
                    height: 49,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2B2B2B)
                          : const Color(0xFFF4F7FD),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      'View Report',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        color: isDark
                                    ? Colors.white
                                    : AppColors.primaryLight,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showScreeningSummaryReadyPopup() async {
    if (!mounted) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Screening Summary Ready',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _ScreeningSummaryReadyPopup(
          onViewReport: () {
            Navigator.pop(context);

            final id = _sessionId;

            if (id == null || id.trim().isEmpty) {
              _showError('Report is not available yet.');
              return;
            }

            Navigator.pushNamed(
              context,
              AppRoutes.individualReport,
              arguments: {
                'sessionId': id,
              },
            );
          },
          onStartCbt: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.cbt);
          },
          onMaybeLater: () {
            Navigator.pop(context);
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
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

  Future<void> _openVoiceMode() async {
    if (_isTyping || _loadingSession || _isVoiceBusy) return;

    setState(() {
      _isVoiceMode = true;
      _voiceStatus = VoiceStatus.processing;
      _voiceTranscript = 'Preparing microphone...';
    });

    try {
      final started = await _voiceRecorder.startRecording();

      if (!started) {
        if (!mounted) return;

        setState(() {
          _isVoiceMode = false;
          _voiceStatus = VoiceStatus.idle;
        });

        _showError('Microphone permission is required for voice mode.');
        return;
      }

      if (!mounted) return;

      setState(() {
        _voiceStatus = VoiceStatus.listening;
        _voiceTranscript = 'I’m listening... speak naturally.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isVoiceMode = false;
        _voiceStatus = VoiceStatus.idle;
      });

      _showError('Could not start recording. Please try again.');
    }
  }

  Future<void> _closeVoiceMode() async {
    if (_isVoiceBusy) return;

    await _voiceRecorder.cancelRecording();
    await _ttsService.stop();

    if (!mounted) return;

    setState(() {
      _isVoiceMode = false;
      _voiceStatus = VoiceStatus.idle;
      _voiceTranscript =
          'Ive been feeling overwhelmed by work\nlately, and I don\'t know where to\nstart...';
    });
  }

  Future<void> _stopVoiceAndSend() async {
    if (_voiceStatus != VoiceStatus.listening) return;

    setState(() {
      _voiceStatus = VoiceStatus.processing;
      _voiceTranscript = 'Understanding...';
    });

    try {
      final audioPath = await _voiceRecorder.stopRecording();

      if (audioPath == null || audioPath.trim().isEmpty) {
        if (!mounted) return;

        setState(() {
          _voiceStatus = VoiceStatus.listening;
          _voiceTranscript = 'I could not hear anything. Please try again.';
        });

        await _restartListening();
        return;
      }

      final transcribedText = await _sttService.transcribe(audioPath);

      if (!mounted) return;

      setState(() {
        _voiceTranscript = transcribedText;
      });

      await _sendVoiceMessage(transcribedText);
    } on SttException catch (e) {
      if (!mounted) return;

      _showError(e.message);

      setState(() {
        _voiceStatus = VoiceStatus.listening;
        _voiceTranscript = 'Please try speaking again.';
      });

      await _restartListening();
    } catch (_) {
      if (!mounted) return;

      _showError('Voice message failed. Please try again.');

      setState(() {
        _voiceStatus = VoiceStatus.listening;
        _voiceTranscript = 'Please try speaking again.';
      });

      await _restartListening();
    }
  }

  Future<void> _restartListening() async {
    if (!mounted || !_isVoiceMode) return;

    if (_voiceRecorder.isRecording) return;

    try {
      final started = await _voiceRecorder.startRecording();

      if (!mounted || !_isVoiceMode) return;

      setState(() {
        _voiceStatus = started ? VoiceStatus.listening : VoiceStatus.idle;
        _voiceTranscript = started
            ? 'I’m listening... speak naturally.'
            : 'Tap the voice button to try again.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _voiceStatus = VoiceStatus.idle;
        _voiceTranscript = 'Tap the voice button to try again.';
      });
    }
  }

  Future<void> _sendVoiceMessage(String text) async {
    final trimmed = text.trim();

    if (trimmed.isEmpty || _loadingSession) return;

    final userMsg = ChatMessage(
      text: trimmed,
      fromUser: true,
      time: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _chatStarted = true;
      _voiceStatus = VoiceStatus.processing;
      _voiceTranscript = 'EMLY is thinking...';
    });

    _scrollToBottom();

    try {
      final result = await AppServices.chatSessionRepository.sendMessage(
        sessionId: _sessionId,
        message: trimmed,
        inputMode: 'voice',
      );

      final assistant = result.assistantMessage;

      final botMsg = ChatMessage(
        text: assistant.text,
        fromUser: false,
        time: assistant.createdAt,
      );

      if (!mounted) return;

      setState(() {
        _sessionId = result.sessionId.isNotEmpty
            ? result.sessionId
            : _sessionId;
        _messages.add(botMsg);
        _startFresh = false;

        _currentSession = ChatSession(
          id: _sessionId ?? result.sessionId,
          title: result.sessionTitle,
          createdAt: result.sessionCreatedAt,
          messages: List<ChatMessage>.from(_messages),
        );

        _voiceStatus = VoiceStatus.speaking;
        _voiceTranscript = assistant.text;
      });

      if (_currentSession != null) {
        chatStore.upsertSession(_currentSession!);
      }

      _handleAssistantMeta(assistant.meta);
      _scrollToBottom();

      final ttsText =
          (assistant.meta['replyTts'] ??
                  assistant.meta['ttsText'] ??
                  assistant.text)
              .toString();

      final ttsLanguage =
          (assistant.meta['ttsLanguage'] ??
                  assistant.meta['ttsLang'] ??
                  'en-US')
              .toString();

      try {
        await _ttsService.speak(ttsText, ttsLanguage);
      } catch (_) {
        // TTS should never block chat. Text is already visible.
      }

      if (!mounted || !_isVoiceMode) return;

      await _restartListening();
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() {
        _voiceStatus = VoiceStatus.listening;
        _voiceTranscript = 'Please try again.';
      });

      if (e.statusCode == 403) {
        final msg = e.message.toLowerCase();

        if (msg.contains('upgrade') ||
            msg.contains('free plan') ||
            msg.contains('subscription')) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
          _showError(
            'Free session used. Please activate Premium or continue your previous session.',
          );
          return;
        }
      }

      _showError(e.message.isNotEmpty ? e.message : 'Failed to send voice.');
      await _restartListening();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _voiceStatus = VoiceStatus.listening;
        _voiceTranscript = 'Please try again.';
      });

      _showError('Failed to send voice.');
      await _restartListening();
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (keyboardOpen) _scrollToBottom();
    });

    final backgroundColor = isDark
        ? const Color(0xFF191919)
        : AppColors.lightBackground;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
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
                          onTap: _handleBack,
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            width: 32,
                            height: 40,
                            child: Icon(
                              Icons.arrow_back,
                              size: 26,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF252525),
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
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF252525),
                          ),
                        ),
                        const Spacer(),
                        _ModeToggle(
                          isDark: isDark,
                          isVoiceMode: _isVoiceMode,
                          onChatTap: () {
                            setState(() => _isVoiceMode = false);
                          },
                          onVoiceTap: _openVoiceMode,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                Expanded(
                  child: _isVoiceMode
                      ? _VoiceChatBody(
                          isDark: isDark,
                          status: _voiceStatus,
                          transcript: _voiceTranscript,
                          isOrbAnimating: _isVoiceOrbAnimating,
                          buttonsDisabled: _isVoiceBusy,
                          onKeyboardTap: () {
                            _closeVoiceMode();
                          },
                          onCloseTap: () {
                            _closeVoiceMode();
                          },
                          onStopTap: () {
                            _stopVoiceAndSend();
                          },
                        )
                      : (_loadingSession
                            ? const Center(child: CircularProgressIndicator())
                            : _buildChatBody(isDark)),
                ),

                if (!_isVoiceMode)
                  _InputBar(
                    controller: _controller,
                    isDark: isDark,
                    hasInputText: _hasInputText,
                    isTyping: _isTyping,
                    onSend: () => _sendMessage(_controller.text),
                    onMicTap: _openVoiceMode,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatBody(bool isDark) {
    /// ================= EMPTY STATE =================
    if (!_chatStarted) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 70),
            Image.asset('assets/images/Robot2.png', width: 150),
            const SizedBox(height: 28),
            Text(
              'Hi there!\nHow are you feeling today?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: isDark ? Colors.white : const Color(0xFF252525),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This is a safe, non-judgmental space. You can share as much or as little as you like.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: isDark
                    ? Colors.white.withOpacity(0.68)
                    : const Color(0xFF252525).withOpacity(0.65),
              ),
            ),
          ],
        ),
      );
    }

    /// ================= CHAT =================
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isTyping && index == _messages.length) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(top: 6, bottom: 6),
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

        final msg = _messages[index];
        return _ChatBubble(
          text: msg.text,
          fromUser: msg.fromUser,
          isDark: isDark,
        );
      },
    );
  }
}

class _EmergencySupportPopup extends StatelessWidget {
  final VoidCallback onLikeSupport;
  final VoidCallback onEmergencyContact;
  final VoidCallback onKeepTalking;

  const _EmergencySupportPopup({
    required this.onLikeSupport,
    required this.onEmergencyContact,
    required this.onKeepTalking,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppColors.primaryDark
        : AppColors.primaryLight;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.5, sigmaY: 5.5),
              child: Container(
                color: isDark
                    ? Colors.black.withOpacity(0.46)
                    : const Color(0xFF7A7692).withOpacity(0.50),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(40, 24, 40, 26),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF191919) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF5E4),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/Heart.png',
                          width: 34,
                          height: 34,
                        ),
                      ),
                    ),

                    const SizedBox(height: 29),

                    Text(
                      'Let\'s pause for a moment',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        color: isDark ? Colors.white : const Color(0xFF252525),
                      ),
                    ),

                    const SizedBox(height: 29),

                    Text(
                      'You mentioned some heavy\nfeelings. There are people ready\nto listen if you need them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                        color: isDark
                            ? Colors.white.withOpacity(0.78)
                            : const Color(0xFF676767),
                      ),
                    ),

                    const SizedBox(height: 28),

                    GestureDetector(
                      onTap: onLikeSupport,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: double.infinity,
                        height: 49,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: const Text(
                          'I’d Like Support',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 11),

                    GestureDetector(
                      onTap: onEmergencyContact,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: double.infinity,
                        height: 49,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: primaryColor, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person, size: 21, color: primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'An Emergency Contact',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 1.0,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 27),

                    GestureDetector(
                      onTap: onKeepTalking,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Keep Talking with EMLY',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                              color: isDark
                                  ? Colors.white.withOpacity(0.76)
                                  : const Color(0xFF676767),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 21,
                            color: isDark
                                ? Colors.white.withOpacity(0.76)
                                : const Color(0xFF676767),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreeningSummaryReadyPopup extends StatelessWidget {
  final VoidCallback onViewReport;
  final VoidCallback onStartCbt;
  final VoidCallback onMaybeLater;

  const _ScreeningSummaryReadyPopup({
    required this.onViewReport,
    required this.onStartCbt,
    required this.onMaybeLater,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppColors.primaryDark
        : AppColors.primaryLight;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.5, sigmaY: 5.5),
              child: Container(
                color: isDark
                    ? Colors.black.withOpacity(0.46)
                    : const Color(0xFF7A7692).withOpacity(0.50),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(40, 24, 40, 26),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF191919) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF5E4),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/StarSummary.png',
                          width: 34,
                          height: 34,
                          color: const Color(0xFFF4AD35),
                        ),
                      ),
                    ),

                    const SizedBox(height: 29),

                    Text(
                      'You did something\nimportant',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: isDark ? Colors.white : const Color(0xFF252525),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Thank you for sharing. Your\nscreening summary is ready, and\nEMLY has prepared next steps for\nyou',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                        color: isDark
                            ? Colors.white.withOpacity(0.78)
                            : const Color(0xFF676767),
                      ),
                    ),

                    const SizedBox(height: 22),

                    GestureDetector(
                      onTap: onViewReport,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: double.infinity,
                        height: 49,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: const Text(
                          'View Screening Report',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 11),

                    GestureDetector(
                      onTap: onStartCbt,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: double.infinity,
                        height: 49,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: primaryColor, width: 1),
                        ),
                        child: Text(
                          'Start CBT Activities',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 27),

                    GestureDetector(
                      onTap: onMaybeLater,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Maybe later',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                              color: isDark
                                  ? Colors.white.withOpacity(0.76)
                                  : const Color(0xFF676767),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 21,
                            color: isDark
                                ? Colors.white.withOpacity(0.76)
                                : const Color(0xFF676767),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool fromUser;
  final bool isDark;

  const _ChatBubble({
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

class _ModeToggle extends StatelessWidget {
  final bool isDark;
  final bool isVoiceMode;
  final VoidCallback onChatTap;
  final VoidCallback onVoiceTap;

  const _ModeToggle({
    required this.isDark,
    required this.isVoiceMode,
    required this.onChatTap,
    required this.onVoiceTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = isDark
        ? AppColors.primaryDark
        : AppColors.primaryLight;

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
                  'assets/images/Keyboard.png', // your keyboard icon path
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
                  'assets/images/Voice.png', // your voice icon path
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

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final bool hasInputText;
  final bool isTyping;
  final VoidCallback onSend;
  final VoidCallback onMicTap;

  const _InputBar({
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

class _VoiceChatBody extends StatelessWidget {
  final bool isDark;
  final VoiceStatus status;
  final String transcript;
  final bool isOrbAnimating;
  final bool buttonsDisabled;
  final VoidCallback onKeyboardTap;
  final VoidCallback onCloseTap;
  final VoidCallback onStopTap;

  const _VoiceChatBody({
    required this.isDark,
    required this.status,
    required this.transcript,
    required this.isOrbAnimating,
    required this.buttonsDisabled,
    required this.onKeyboardTap,
    required this.onCloseTap,
    required this.onStopTap,
  });

  String get _statusText {
    switch (status) {
      case VoiceStatus.listening:
        return 'Listening';
      case VoiceStatus.processing:
        return 'Processing';
      case VoiceStatus.speaking:
        return 'Speaking';
      case VoiceStatus.idle:
        return 'Ready';
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = isDark
        ? AppColors.primaryDark
        : AppColors.primaryLight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallHeight = constraints.maxHeight < 620;

        final topGap = isSmallHeight ? 24.0 : 54.0;
        final orbSize = isSmallHeight ? 145.0 : 188.0;
        final orbToStatusGap = isSmallHeight ? 18.0 : 30.0;
        final statusToTextGap = isSmallHeight ? 22.0 : 38.0;
        final bottomGap = isSmallHeight ? 16.0 : 32.0;

        final smallButtonColor = buttonsDisabled
            ? (isDark ? const Color(0xFF555555) : const Color(0xFFE5E5E5))
            : (isDark ? const Color(0xFF8B8B8B) : const Color(0xFFD9D9D9));

        final stopButtonColor = buttonsDisabled
            ? (isDark ? const Color(0xFF4A4A4A) : const Color(0xFFE3E3E3))
            : primaryColor;

        final iconColor = buttonsDisabled
            ? Colors.white.withOpacity(0.45)
            : Colors.white;

        return Column(
          children: [
            SizedBox(height: topGap),

            _VoiceOrb(
              isDark: isDark,
              isAnimating: isOrbAnimating,
              size: orbSize,
            ),

            SizedBox(height: orbToStatusGap),

            Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF242424) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : const Color(0xFFE2E2E2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: status == VoiceStatus.processing
                          ? const Color(0xFF9D9D9D)
                          : primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _statusText,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.0,
                      color: isDark
                          ? Colors.white.withOpacity(0.74)
                          : const Color(0xFF6A6A6A),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: statusToTextGap),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 34),
                child: Text(
                  transcript,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: isSmallHeight ? 15 : 16,
                    fontWeight: FontWeight.w400,
                    height: 1.42,
                    letterSpacing: -0.1,
                    color: isDark
                        ? Colors.white.withOpacity(0.78)
                        : const Color(0xFF666666),
                  ),
                ),
              ),
            ),

            SizedBox(height: isSmallHeight ? 14 : 22),

            Padding(
              padding: EdgeInsets.only(bottom: bottomGap),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _VoiceControlButton(
                    size: isSmallHeight ? 44 : 49,
                    backgroundColor: smallButtonColor,
                    disabled: buttonsDisabled,
                    onTap: onKeyboardTap,
                    child: Icon(
                      Icons.keyboard_alt_outlined,
                      size: 26,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 31),
                  _VoiceControlButton(
                    size: isSmallHeight ? 68 : 79,
                    backgroundColor: stopButtonColor,
                    disabled: buttonsDisabled,
                    onTap: onStopTap,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: buttonsDisabled
                            ? Colors.white.withOpacity(0.45)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 31),
                  _VoiceControlButton(
                    size: isSmallHeight ? 44 : 49,
                    backgroundColor: smallButtonColor,
                    disabled: buttonsDisabled,
                    onTap: onCloseTap,
                    child: Icon(
                      Icons.close_rounded,
                      size: 34,
                      color: iconColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VoiceOrb extends StatefulWidget {
  final bool isDark;
  final bool isAnimating;
  final double size;

  const _VoiceOrb({
    required this.isDark,
    required this.isAnimating,
    this.size = 188,
  });

  @override
  State<_VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<_VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.96,
      end: 1.045,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _VoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isAnimating && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isAnimating && _controller.isAnimating) {
      _controller.stop();
      _controller.animateTo(
        0.5,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isDark
        ? AppColors.primaryDark
        : AppColors.primaryLight;

    final highlightColor = widget.isDark
        ? const Color(0xFF8F7BFF)
        : const Color(0xFF7A68F5);

    final deepColor = widget.isDark
        ? const Color(0xFF26138F)
        : const Color(0xFF24127F);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 188,
        height: 188,
        decoration: BoxDecoration(
          shape: BoxShape.circle,

          /// No white border now
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(widget.isDark ? 0.34 : 0.22),
              blurRadius: 5,
              offset: const Offset(-2, 4),
            ),
            BoxShadow(
              color: baseColor.withOpacity(widget.isDark ? 0.28 : 0.18),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 0),
            ),
          ],
          gradient: RadialGradient(
            center: const Alignment(-0.34, -0.42),
            radius: 0.92,
            colors: [highlightColor, baseColor, baseColor, deepColor],
            stops: const [0.0, 0.34, 0.72, 1.0],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.42, -0.48),
              radius: 0.36,
              colors: [
                Colors.white.withOpacity(0.28),
                Colors.white.withOpacity(0.05),
                Colors.transparent,
              ],
              stops: const [0.0, 0.52, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceControlButton extends StatelessWidget {
  final double size;
  final Color backgroundColor;
  final Widget child;
  final VoidCallback onTap;
  final bool disabled;

  const _VoiceControlButton({
    required this.size,
    required this.backgroundColor,
    required this.child,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: disabled ? 0.65 : 1,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
