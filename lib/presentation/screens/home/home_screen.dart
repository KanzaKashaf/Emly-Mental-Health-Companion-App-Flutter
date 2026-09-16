import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../../routes/app_routes.dart';
import '../../widgets/avatar_utils.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';
import '../../../../core/data/api/models/user_model.dart';
import '../../../../core/data/repositories/chat_session_repository.dart';
import '../../../../core/data/repositories/report_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static void resetPopupFlagsForNewAppLaunch() {
    _HomeScreenState._welcomeBackPopupShownThisAppLaunch = false;
    _HomeScreenState._welcomeBackPopupDismissedThisAppLaunch = false;
    _HomeScreenState._sessionExpiredPopupShownThisAppLaunch = false;
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserModel? _user;
  bool _loading = true;
  bool _error = false;

  static bool _welcomeBackPopupShownThisAppLaunch = false;
  static bool _welcomeBackPopupDismissedThisAppLaunch = false;
  static bool _sessionExpiredPopupShownThisAppLaunch = false;

  ChatSessionSummary? _latestSession;
  ChatSessionStatus? _latestSessionStatus;

  bool _isFirstHomeVisitForUser = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<bool> _checkAndMarkFirstHomeVisit(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'home_seen_user_$userId';

    final hasSeenHome = prefs.getBool(key) ?? false;

    if (!hasSeenHome) {
      await prefs.setBool(key, true);
      return true;
    }

    return false;
  }

  Future<void> _loadUser() async {
    try {
      final user = await AppServices.userRepository.getMe();
      final isFirstHomeVisit = await _checkAndMarkFirstHomeVisit(user.id);

      if (!mounted) return;

      setState(() {
        _user = user;
        _isFirstHomeVisitForUser = isFirstHomeVisit;
        _loading = false;
        _error = false;
      });

      await _loadPreviousSessionAndShowPopupIfNeeded();
    } on ApiError {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _continuePreviousSessionFromHome() async {
    final status = _latestSessionStatus;
    final session = _latestSession;

    if (status == null || session == null) {
      Navigator.pushNamed(context, AppRoutes.chat);
      return;
    }

    if (status.isExpired) {
      await _showSessionExpiredDialogIfNeeded();
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.chat,
      arguments: {'sessionId': session.id},
    );
  }

  Future<void> _loadPreviousSessionAndShowPopupIfNeeded() async {
    try {
      final latestSession = await AppServices.chatSessionRepository
          .getLatestSession();

      if (latestSession == null) return;

      final status = await AppServices.chatSessionRepository.getSessionStatus(
        latestSession.id,
      );

      if (!mounted) return;

      setState(() {
        _latestSession = latestSession;
        _latestSessionStatus = status;
      });

      final shouldShowPopup =
          latestSession.isIncomplete || status.shouldShowWelcomeBack;

      if (shouldShowPopup) {
        await _showWelcomeBackPopupIfNeeded();
      }
    } catch (e) {
      debugPrint('HOME SESSION CHECK ERROR: $e');
    }
  }

  Future<void> _showWelcomeBackPopupIfNeeded() async {
    if (_welcomeBackPopupShownThisAppLaunch) return;
    if (_welcomeBackPopupDismissedThisAppLaunch) return;
    if (_latestSession == null || _latestSessionStatus == null) return;

    final shouldShowPopup =
        _latestSession!.isIncomplete ||
        _latestSessionStatus!.shouldShowWelcomeBack;

    if (!shouldShowPopup) return;

    _welcomeBackPopupShownThisAppLaunch = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showWelcomeBackDialog();
    });
  }

  Future<void> _showWelcomeBackDialog() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Welcome Back',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _WelcomeBackPopup(
          gapDays: _latestSessionStatus?.gapDays,
          onContinueSession: () async {
            await _dismissWelcomeBackPopupByAction();
            if (!mounted) return;

            Navigator.pop(context);

            await _continuePreviousSessionFromHome();
          },
          onStartFresh: () async {
            await _dismissWelcomeBackPopupByAction();
            if (!mounted) return;

            Navigator.pop(context);
            _handleStartSessionFromHome();
          },
          onViewLastReport: () async {
            await _dismissWelcomeBackPopupByAction();
            if (!mounted) return;

            Navigator.pop(context);

            await _handleViewLastReportFromHome();
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

  Future<void> _showSessionExpiredDialogIfNeeded() async {
    if (_sessionExpiredPopupShownThisAppLaunch) return;
    if (_latestSessionStatus?.isExpired != true) return;

    _sessionExpiredPopupShownThisAppLaunch = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showSessionExpiredDialog();
    });
  }

  Future<void> _dismissWelcomeBackPopupByAction() async {
    _welcomeBackPopupDismissedThisAppLaunch = true;
  }

  Future<void> _handleStartSessionFromHome() async {
    try {
      final status = await AppServices.subscriptionRepository.getStatus();

      if (status.canCreateSession) {
        Navigator.pushNamed(
          context,
          AppRoutes.chat,
          arguments: {'startFresh': true},
        );
        return;
      }

      await _showFreeSessionUsedPopup();
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

  Future<void> _handleViewLastReportFromHome() async {
    try {
      final reports = await AppServices.reportRepository.getReports();

      if (!mounted) return;

      if (reports.isEmpty) {
        await _showNoReportYetPopup();
        return;
      }

      final latestCompletedReport = reports.first;

      Navigator.pushNamed(
        context,
        AppRoutes.individualReport,
        arguments: {
          'sessionId': latestCompletedReport.sessionId,
          'report': latestCompletedReport.detail.toJson(),
        },
      );
    } on ApiError catch (e) {
      if (!mounted) return;

      final msg = e.message.toLowerCase();

      if (e.statusCode == 404 ||
          msg.contains('no report') ||
          msg.contains('not found') ||
          msg.contains('report not available')) {
        await _showNoReportYetPopup();
        return;
      }

      _showError(
        e.message.isNotEmpty
            ? e.message
            : 'Unable to load your completed report.',
      );
    } catch (_) {
      if (!mounted) return;
      await _showNoReportYetPopup();
    }
  }

  Future<void> _showNoReportYetPopup() async {
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'No Report Yet',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
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

              Center(
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.fromLTRB(28, 18, 28, 20),
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
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2B2B2B)
                              : const Color(0xFFF4F7FD),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.description_outlined,
                          size: 34,
                          color: primary,
                        ),
                      ),

                      const SizedBox(height: 26),

                      Text(
                        'No Report Yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          color: isDark ? Colors.white : const Color(0xFF252525),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Text(
                        'You do not have any completed\nscreening report yet.\nComplete a session first, and\nyour report will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                          color: isDark
                              ? Colors.white.withOpacity(0.76)
                              : const Color(0xFF676767),
                        ),
                      ),

                      const SizedBox(height: 24),

                      GestureDetector(
                        onTap: () => Navigator.pop(context),
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
                            'Back to Home',
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
                    ],
                  ),
                ),
              ),
            ],
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

  Future<void> _showFreeSessionUsedPopup() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Free Session Used',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
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
                          await _continuePreviousSessionFromHome();
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
                        onTap: () {
                          Navigator.pop(context);
                        },
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

  /// ───────────────── EXIT CONFIRMATION ─────────────────
  Future<bool> _showExitConfirm(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return await showModalBottomSheet<bool>(
          context: context,
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
                    'Exit App',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.15),
                    ),
                  ),
                  const Text(
                    'Are you sure you want to exit the app?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, false),
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2B2B2B)
                                  : const Color(0xFFF4F7FD),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.primaryLight,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, true),
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.primaryDark
                                  : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Text(
                              'Exit',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ) ??
        false;
  }

  Future<void> _showSessionExpiredDialog() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Session Expired',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _SessionExpiredPopup(
          gapDays: _latestSessionStatus?.gapDays,
          onStartNewSession: () async {
            await _dismissSessionExpiredPopupByAction();
            if (!mounted) return;

            Navigator.pop(context);
            _handleStartSessionFromHome();
          },
          onViewLastReport: () async {
            await _dismissSessionExpiredPopupByAction();
            if (!mounted) return;

            Navigator.pop(context);

            await _handleViewLastReportFromHome();
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

  Future<void> _dismissSessionExpiredPopupByAction() async {
    _sessionExpiredPopupShownThisAppLaunch = true;
  }

  Widget _buildBottomNavBar() {
    return BottomNavBar(
      currentIndex: 0,
      onTap: (i) async {
        if (i == 1) {
          await _handleStartSessionFromHome();
        }

        if (i == 2) {
          Navigator.pushReplacementNamed(context, AppRoutes.cbt);
        }

        if (i == 3) {
          Navigator.pushReplacementNamed(context, AppRoutes.history);
        }

        if (i == 4) {
          final updated = await Navigator.pushNamed(
            context,
            AppRoutes.settings,
          );

          if (updated == true) {
            _loadUser();
          }
        }
      },
    );
  }

  /// ───────────────── UI ─────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final shouldExit = await _showExitConfirm(context);
          if (shouldExit) SystemNavigator.pop();
        },
        child: Scaffold(
          backgroundColor: isDark
              ? AppColors.darkBackground
              : AppColors.lightBackground,
          body: SafeArea(
            child: _HomeSkeleton(isDark: isDark),
          ),
          bottomNavigationBar: _buildBottomNavBar(),
        ),
      );
    }

    if (_error || _user == null) {
      return Scaffold(
        body: Center(
          child: TextButton(onPressed: _loadUser, child: const Text('Retry')),
        ),
      );
    }

    final userName = _user!.name ?? 'User';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirm(context);
        if (shouldExit) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                CircleAvatar(
                  radius: 24,
                  backgroundColor: _user!.profileImageUrl == null
                      ? AvatarUtils.colorFromName(userName)
                      : null,
                  backgroundImage: _user!.profileImageUrl != null
                      ? NetworkImage(_user!.profileImageUrl!)
                      : null,
                  child: _user!.profileImageUrl == null
                      ? Text(
                          AvatarUtils.firstLetter(userName),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),

                const SizedBox(height: 10),

                Text(
                  '${_isFirstHomeVisitForUser ? 'Welcome' : 'Welcome Back'},\n$userName',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Your safe space for mental wellness.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),

                const SizedBox(height: 30),

                Center(
                  child: Image.asset('assets/images/Robot1.png', width: 250),
                ),

                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: const [
                    _Feature(
                      icon: 'assets/images/Mind.png',
                      label: 'Mindfulness',
                    ),
                    _Feature(icon: 'assets/images/Growth.png', label: 'Growth'),
                    _Feature(
                      icon: 'assets/images/Privacy.png',
                      label: 'Privacy',
                    ),
                  ],
                ),

                const Spacer(),

                PrimaryButton(
                  text: 'Start your Session!',
                  onTap: () {
                    _handleStartSessionFromHome();
                  },
                ),

                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  final bool isDark;

  const _HomeSkeleton({
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
      highlightColor:
          isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF6F8FC),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SizedBox(height: 12),

            _SkeletonCircle(size: 48),

            SizedBox(height: 10),

            _SkeletonBox(width: 145, height: 26, radius: 8),

            SizedBox(height: 6),

            _SkeletonBox(width: 190, height: 26, radius: 8),

            SizedBox(height: 8),

            _SkeletonBox(width: 245, height: 14, radius: 6),

            SizedBox(height: 40),

            Center(
              child: _SkeletonImageBox(
                asset: 'assets/images/Robot1.png',
                width: 250,
                radius: 26,
              ),
            ),

            SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _FeatureSkeleton(
                  icon: 'assets/images/Mind.png',
                  labelWidth: 66,
                ),
                _FeatureSkeleton(
                  icon: 'assets/images/Growth.png',
                  labelWidth: 46,
                ),
                _FeatureSkeleton(
                  icon: 'assets/images/Privacy.png',
                  labelWidth: 48,
                ),
              ],
            ),

            Spacer(),

            _SkeletonBox(width: double.infinity, height: 54, radius: 28),

            SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

class _FeatureSkeleton extends StatelessWidget {
  final String icon;
  final double labelWidth;

  const _FeatureSkeleton({
    required this.icon,
    required this.labelWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SkeletonImageBox(
          asset: icon,
          width: 40,
          radius: 10,
        ),
        const SizedBox(height: 8),
        _SkeletonBox(width: labelWidth, height: 12, radius: 6),
      ],
    );
  }
}

class _SkeletonImageBox extends StatelessWidget {
  final String asset;
  final double width;
  final double radius;

  const _SkeletonImageBox({
    required this.asset,
    required this.width,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Opacity(
          opacity: 0,
          child: Image.asset(
            asset,
            width: width,
            fit: BoxFit.contain,
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ),
      ],
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

  const _SkeletonCircle({
    required this.size,
  });

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

// ───────────────── WELCOME BACK POPUP ─────────────────

class _WelcomeBackPopup extends StatelessWidget {
  final int? gapDays;
  final VoidCallback onContinueSession;
  final VoidCallback onStartFresh;
  final VoidCallback onViewLastReport;

  const _WelcomeBackPopup({
    required this.gapDays,
    required this.onContinueSession,
    required this.onStartFresh,
    required this.onViewLastReport,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          Center(
            child: Container(
              width: 320,
              padding: const EdgeInsets.fromLTRB(27, 17, 28, 15),
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
                      color: Color(0xFFD9D9D9),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/Star.png',
                        width: 34,
                        height: 34,
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: isDark ? Colors.white : const Color(0xFF252525),
                    ),
                  ),

                  const SizedBox(height: 25),

                  Text(
                    gapDays == null
                        ? 'You have an unfinished session.\nPick up where you left off, or\nstart fresh.'
                        : 'It\'s been $gapDays ${gapDays == 1 ? 'day' : 'days'}.\nPick up where you left off, or\nstart fresh.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.34,
                      color: isDark
                          ? Colors.white.withOpacity(0.76)
                          : const Color(0xFF676767),
                    ),
                  ),

                  const SizedBox(height: 27),

                  _WelcomeBackButton(
                    text: 'Continue session',
                    onTap: onContinueSession,
                  ),

                  const SizedBox(height: 17),

                  _WelcomeBackButton(text: 'Start fresh', onTap: onStartFresh),

                  const SizedBox(height: 11),

                  GestureDetector(
                    onTap: onViewLastReport,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View last report',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                              color: isDark
                                  ? Colors.white.withOpacity(0.74)
                                  : const Color(0xFF676767),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 21,
                            color: isDark
                                ? Colors.white.withOpacity(0.74)
                                : const Color(0xFF676767),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────── SESSION EXPIRED POPUP ─────────────────

class _SessionExpiredPopup extends StatelessWidget {
  final int? gapDays;
  final VoidCallback onStartNewSession;
  final VoidCallback onViewLastReport;

  const _SessionExpiredPopup({
    required this.gapDays,
    required this.onStartNewSession,
    required this.onViewLastReport,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          Center(
            child: Container(
              width: 333,
              padding: const EdgeInsets.fromLTRB(28, 16, 29, 20),
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
                      color: Color(0xFFFFF1DB),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/Clock.png',
                        width: 34,
                        height: 34,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Text(
                    'This session has expired',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: isDark ? Colors.white : const Color(0xFF252525),
                    ),
                  ),

                  const SizedBox(height: 26),

                  Text(
                    gapDays == null
                        ? 'This previous screening is too old.\nFor accuracy, start a fresh\nsession.'
                        : 'It\'s been $gapDays ${gapDays == 1 ? 'day' : 'days'} since you\nstarted this screening. For\naccuracy, start a fresh session.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.37,
                      color: isDark
                          ? Colors.white.withOpacity(0.76)
                          : const Color(0xFF676767),
                    ),
                  ),

                  const SizedBox(height: 27),

                  _WelcomeBackButton(
                    text: 'Start new session',
                    onTap: onStartNewSession,
                  ),

                  const SizedBox(height: 11),

                  GestureDetector(
                    onTap: onViewLastReport,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View last report',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                              color: isDark
                                  ? Colors.white.withOpacity(0.74)
                                  : const Color(0xFF676767),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 21,
                            color: isDark
                                ? Colors.white.withOpacity(0.74)
                                : const Color(0xFF676767),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBackButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _WelcomeBackButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.0,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// Icon + Label Widget

class _Feature extends StatelessWidget {
  final String icon;
  final String label;

  const _Feature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Image.asset(icon, width: 40),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacity(isDark ? 0.8 : 0.7),
          ),
        ),
      ],
    );
  }
}
