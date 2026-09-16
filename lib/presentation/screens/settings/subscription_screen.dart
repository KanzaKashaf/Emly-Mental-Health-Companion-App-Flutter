import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';
import '../../../../core/data/repositories/subscription_repository.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isPremiumActivated = false;
  bool _isActivating = false;
  bool _isLoadingStatus = true;
  bool _isCancelling = false;

  SubscriptionStatus? _subscriptionStatus;

  @override
  void initState() {
    super.initState();
    _loadPremiumStatus();
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

  DateTime _addOneMonth(DateTime date) {
    final nextMonth = date.month == 12 ? 1 : date.month + 1;
    final nextYear = date.month == 12 ? date.year + 1 : date.year;

    final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
    final safeDay = date.day > lastDayOfNextMonth
        ? lastDayOfNextMonth
        : date.day;

    return DateTime(
      nextYear,
      nextMonth,
      safeDay,
      date.hour,
      date.minute,
      date.second,
    );
  }

  DateTime _premiumEndDate() {
    final raw = _subscriptionStatus?.expiresAt;

    if (raw != null && raw.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(raw.trim());

      if (parsed != null) {
        return parsed.toLocal();
      }
    }

    // Fallback only if backend does not return valid expiresAt.
    return _addOneMonth(DateTime.now());
  }

  String _formatPremiumDate(DateTime date, {bool includeYear = false}) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final text = '${months[date.month - 1]} ${date.day}';

    if (includeYear) {
      return '$text, ${date.year}';
    }

    return text;
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _loadPremiumStatus() async {
    setState(() => _isLoadingStatus = true);

    try {
      final status = await AppServices.subscriptionRepository.getStatus();

      if (!mounted) return;

      setState(() {
        _subscriptionStatus = status;
        _isPremiumActivated = status.isPremium;
        _isLoadingStatus = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() => _isLoadingStatus = false);
      _showError(e.message.isNotEmpty
          ? e.message
          : 'Failed to load subscription status.');
    } catch (_) {
      if (!mounted) return;

      setState(() => _isLoadingStatus = false);
      _showError('Failed to load subscription status.');
    }
  }

  Future<void> _showActivatingPremiumPopup(BuildContext context) async {
    if (_isActivating) return;

    setState(() => _isActivating = true);

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Activating Premium',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const _ActivatingPremiumPopup();
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

    try {
      // Keep your existing 5 second spinner behavior.
      await Future.delayed(const Duration(seconds: 5));

      final status = await AppServices.subscriptionRepository.activatePremium();

      if (!mounted) return;

      Navigator.pop(context);

      setState(() {
        _subscriptionStatus = status;
        _isPremiumActivated = status.isPremium;
        _isActivating = false;
      });

      await _showPremiumActivatedPopup(
        context,
        expiryDateText: _formatPremiumDate(
          _premiumEndDate(),
          includeYear: true,
        ),
      );
    } on ApiError catch (e) {
      if (!mounted) return;

      Navigator.pop(context);

      setState(() => _isActivating = false);

      _showError(
        e.message.isNotEmpty
            ? e.message
            : 'Failed to activate premium. Please try again.',
      );
    } catch (_) {
      if (!mounted) return;

      Navigator.pop(context);

      setState(() => _isActivating = false);

      _showError('Failed to activate premium. Please try again.');
    }
  }

  Future<void> _showPremiumActivatedPopup(
    BuildContext context, {
    required String expiryDateText,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Premium Activated',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _PremiumActivatedPopup(
          expiryDateText: expiryDateText,
          onStartNewSession: () {
            Navigator.pop(context);
            Navigator.pushReplacementNamed(context, AppRoutes.chat);
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

  Future<void> _cancelPremium() async {
    final confirmed = await _showCancelPremiumConfirmation(context);

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isCancelling = true);

    try {
      final status = await AppServices.subscriptionRepository.deactivatePremium();

      if (!mounted) return;

      setState(() {
        _subscriptionStatus = status;
        _isPremiumActivated = status.isPremium;
      });

      _showSuccess('Premium cancelled. You are now on the free plan.');
    } on ApiError catch (e) {
      _showError(
        e.message.isNotEmpty
            ? e.message
            : 'Failed to cancel premium. Please try again.',
      );
    } catch (_) {
      _showError('Failed to cancel premium. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  Future<bool?> _showCancelPremiumConfirmation(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final endDateText = _formatPremiumDate(
      _premiumEndDate(),
      includeYear: false,
    );

    return showModalBottomSheet<bool>(
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
                'Cancel Premium?',
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

              Text(
                'You’ll keep Premium until $endDateText, then revert to the free plan with 1 screening/month.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      behavior: HitTestBehavior.opaque,
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
                          'No, Keep It',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
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
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF63A3A),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'Yes, Cancel',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoadingStatus) {
      return Scaffold(
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              /// APP BAR
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Subscription Plan',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Expanded(
                child: _SubscriptionSkeleton(isDark: isDark),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            /// APP BAR
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Subscription Plan',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    /// BASIC PLAN
                    _PlanCard(
                      isDark: isDark,
                      title: 'Basic Plan',
                      price: 'Free',
                      background: isDark
                          ? const Color(0xFF2B2B2B)
                          : const Color(0xFFF4F7FD),
                      textColor: isDark ? Colors.white : Colors.black,
                      bullets: const [
                        'AI assistant helps with creating, organizing, and reminding you of tasks and deadlines',
                        'Integrates with your calendar to set up meetings and send reminders.',
                        'Provides quick answers to general knowledge questions and weather updates.',
                      ],
                    ),

                    const SizedBox(height: 20),

                    /// PREMIUM PLAN
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// HEADER
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'Premium Plan',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '\$10/month',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            'Includes all features from the Basic and Standard Plans, plus:',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 14),

                          _premiumBullet(
                            'Analyzes personal and business data to provide insights and actionable reports.',
                          ),

                          if (_subscriptionStatus != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _subscriptionStatus!.isPremium
                                ? 'Current plan: Premium • Active until ${_formatPremiumDate(_premiumEndDate(), includeYear: true)}'
                                : 'Current plan: Free • ${_subscriptionStatus!.sessionsUsed}/${_subscriptionStatus!.sessionsAllowed ?? '1'} sessions used',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.5,
                                color: Colors.white,
                                height: 1.4,
                              ),
                            ),
                          ],

                          const SizedBox(height: 22),

                          /// CONTINUE / CANCEL PREMIUM BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primaryDark,
                                disabledBackgroundColor: Colors.white,
                                disabledForegroundColor: AppColors.primaryDark,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              onPressed: (_isActivating || _isCancelling)
                                ? null
                                : () {
                                    if (_isPremiumActivated) {
                                      _cancelPremium();
                                    } else {
                                      _showActivatingPremiumPopup(context);
                                    }
                                  },
                            child: Text(
                              _isActivating
                                  ? 'Activating...'
                                  : _isCancelling
                                      ? 'Cancelling...'
                                      : _isPremiumActivated
                                          ? 'Cancel Premium'
                                          : 'Continue',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PREMIUM BULLET
  Widget _premiumBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/Tick.png',
          width: 18,
          height: 18,
          color: Colors.white,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _SubscriptionSkeleton extends StatelessWidget {
  final bool isDark;

  const _SubscriptionSkeleton({
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
      highlightColor:
          isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF6F8FC),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Column(
          children: [
            _BasicPlanCardSkeleton(),

            SizedBox(height: 20),

            _PremiumPlanCardSkeleton(),

            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _BasicPlanCardSkeleton extends StatelessWidget {
  const _BasicPlanCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 19,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SkeletonBox(width: 90, height: 16, radius: 6),
                _SkeletonBox(width: 42, height: 16, radius: 6),
              ],
            ),
          ),

          SizedBox(height: 14),

          _PlanBulletSkeleton(
            lineWidths: [230, 250, 165],
            tickColor: Colors.white,
          ),

          _PlanBulletSkeleton(
            lineWidths: [240, 250, 150],
            tickColor: Colors.white,
          ),

          _PlanBulletSkeleton(
            lineWidths: [245, 235, 130],
            tickColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _PremiumPlanCardSkeleton extends StatelessWidget {
  const _PremiumPlanCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 19,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SkeletonBox(width: 110, height: 16, radius: 6),
                _SkeletonBox(width: 82, height: 16, radius: 6),
              ],
            ),
          ),

          SizedBox(height: 10),

          _SkeletonBox(width: double.infinity, height: 13, radius: 6),
          SizedBox(height: 6),
          _SkeletonBox(width: 260, height: 13, radius: 6),

          SizedBox(height: 14),

          _PlanBulletSkeleton(
            lineWidths: [245, 245, 160],
            tickColor: Colors.white,
          ),

          SizedBox(height: 2),

          _SkeletonBox(width: double.infinity, height: 13, radius: 6),
          SizedBox(height: 6),
          _SkeletonBox(width: 230, height: 13, radius: 6),

          SizedBox(height: 22),

          _SkeletonBox(
            width: double.infinity,
            height: 44,
            radius: 22,
          ),
        ],
      ),
    );
  }
}

class _PlanBulletSkeleton extends StatelessWidget {
  final List<double> lineWidths;
  final Color tickColor;

  const _PlanBulletSkeleton({
    required this.lineWidths,
    required this.tickColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkeletonBox(width: 18, height: 18, radius: 9),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                lineWidths.length,
                (index) => Padding(
                  padding: EdgeInsets.only(
                    bottom: index == lineWidths.length - 1 ? 0 : 6,
                  ),
                  child: _SkeletonBox(
                    width: lineWidths[index],
                    height: 13,
                    radius: 6,
                  ),
                ),
              ),
            ),
          ),
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

/// ───────────────── ACTIVATING PREMIUM POPUP ─────────────────

class _ActivatingPremiumPopup extends StatelessWidget {
  const _ActivatingPremiumPopup();

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
              width: 286,
              height: 225,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PremiumSpinner(isDark: isDark),

                  const SizedBox(height: 23),

                  Text(
                    'Activating Premium...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: isDark ? Colors.white : const Color(0xFF252525),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    'Unlocking unlimited sessions\nand your AI\nvoice companion.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                      color: isDark
                          ? Colors.white.withOpacity(0.78)
                          : const Color(0xFF676767),
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

/// ───────────────── PREMIUM ACTIVATED POPUP ─────────────────

class _PremiumActivatedPopup extends StatelessWidget {
  final String expiryDateText;
  final VoidCallback onStartNewSession;

  const _PremiumActivatedPopup({
    required this.expiryDateText,
    required this.onStartNewSession,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final popupColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final iconCircleColor = isDark
        ? const Color(0xFF8C54F3)
        : const Color(0xFF247BD5);

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
              padding: const EdgeInsets.fromLTRB(28, 21, 28, 37),
              decoration: BoxDecoration(
                color: popupColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: iconCircleColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/Star.png',
                        width: 34,
                        height: 34,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 31),

                  const Text(
                    'PREMIUM ACTIVATED',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.0,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'Welcome to unlimited\ncare.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'You have unlimited screenings,\nvoice conversations, and personalized CBT plans until $expiryDateText.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),

                  GestureDetector(
                    onTap: onStartNewSession,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: double.infinity,
                      height: 49,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Text(
                        'Start a new session',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                          color: popupColor,
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
  }
}

/// ───────────────── CUSTOM SPINNER ─────────────────

class _PremiumSpinner extends StatefulWidget {
  final bool isDark;

  const _PremiumSpinner({required this.isDark});

  @override
  State<_PremiumSpinner> createState() => _PremiumSpinnerState();
}

class _PremiumSpinnerState extends State<_PremiumSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inactiveColor = widget.isDark
        ? Colors.white.withOpacity(0.88)
        : const Color(0xFFE1E1E1);

    final activeColor = widget.isDark
        ? AppColors.primaryDark
        : AppColors.primaryLight;

    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        size: const Size(64, 64),
        painter: _PremiumSpinnerPainter(
          inactiveColor: inactiveColor,
          activeColor: activeColor,
        ),
      ),
    );
  }
}

class _PremiumSpinnerPainter extends CustomPainter {
  final Color inactiveColor;
  final Color activeColor;

  const _PremiumSpinnerPainter({
    required this.inactiveColor,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 4.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, 0, 2 * pi, false, inactivePaint);

    canvas.drawArc(arcRect, pi * 0.78, pi * 0.74, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant _PremiumSpinnerPainter oldDelegate) {
    return oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.activeColor != activeColor;
  }
}

/// ───────────────── BASIC PLAN CARD ─────────────────

class _PlanCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final String price;
  final Color background;
  final Color textColor;
  final List<String> bullets;

  const _PlanCard({
    required this.isDark,
    required this.title,
    required this.price,
    required this.background,
    required this.textColor,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/Tick.png',
                    width: 18,
                    height: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      b,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: textColor,
                        height: 1.45,
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
