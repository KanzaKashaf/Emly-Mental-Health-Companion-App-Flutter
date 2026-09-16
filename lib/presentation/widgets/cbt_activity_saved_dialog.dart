import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum CbtSavedDialogType {
  daily,
  weeklyProgress,
  weeklyReview,
}

class CbtActivitySavedDialog {
  static Future<void> show({
    required BuildContext context,
    required CbtSavedDialogType type,
    required String activityName,
    int streakDays = 3,
    int completedCount = 2,
    int totalCount = 3,
    VoidCallback? onDone,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Activity Saved',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _CbtActivitySavedPopup(
          isDark: isDark,
          type: type,
          activityName: activityName,
          streakDays: streakDays,
          completedCount: completedCount,
          totalCount: totalCount,
          onDone: () {
            Navigator.pop(context);
            onDone?.call();
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
}

class _CbtActivitySavedPopup extends StatelessWidget {
  final bool isDark;
  final CbtSavedDialogType type;
  final String activityName;
  final int streakDays;
  final int completedCount;
  final int totalCount;
  final VoidCallback onDone;

  const _CbtActivitySavedPopup({
    required this.isDark,
    required this.type,
    required this.activityName,
    required this.streakDays,
    required this.completedCount,
    required this.totalCount,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final popupColor = isDark ? const Color(0xFF1B1B1B) : Colors.white;

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    final descriptionColor = isDark
        ? Colors.white.withOpacity(0.78)
        : const Color(0xFF676767);

    final smallCardColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

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
              padding: EdgeInsets.fromLTRB(
                28,
                type == CbtSavedDialogType.weeklyReview ? 18 : 17,
                28,
                type == CbtSavedDialogType.weeklyReview ? 28 : 22,
              ),
              decoration: BoxDecoration(
                color: popupColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SavedIcon(primary: primary),

                  SizedBox(
                    height: type == CbtSavedDialogType.weeklyReview ? 26 : 25,
                  ),

                  Text(
                    type == CbtSavedDialogType.weeklyReview
                        ? 'Weekly Review Saved!'
                        : 'Activity saved!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: textColor,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    type == CbtSavedDialogType.weeklyReview
                        ? 'Your reflection for this week has\nbeen saved.'
                        : '$activityName saved\nsuccessfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                      color: descriptionColor,
                    ),
                  ),

                  if (type != CbtSavedDialogType.weeklyReview) ...[
                    const SizedBox(height: 15),
                    _ProgressInfoBox(
                      isDark: isDark,
                      type: type,
                      streakDays: streakDays,
                      completedCount: completedCount,
                      totalCount: totalCount,
                      backgroundColor: smallCardColor,
                    ),
                  ],

                  SizedBox(
                    height: type == CbtSavedDialogType.weeklyReview ? 26 : 23,
                  ),

                  GestureDetector(
                    onTap: onDone,
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
                        'Done',
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
  }
}

class _SavedIcon extends StatelessWidget {
  final Color primary;

  const _SavedIcon({
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFFE2E2E2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(1),
          ),
          child: const Icon(
            Icons.check,
            size: 27,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ProgressInfoBox extends StatelessWidget {
  final bool isDark;
  final CbtSavedDialogType type;
  final int streakDays;
  final int completedCount;
  final int totalCount;
  final Color backgroundColor;

  const _ProgressInfoBox({
    required this.isDark,
    required this.type,
    required this.streakDays,
    required this.completedCount,
    required this.totalCount,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    if (type == CbtSavedDialogType.weeklyProgress) {
      return Container(
        width: double.infinity,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          '$completedCount/$totalCount completed this week',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      );
    }

    return Container(
      width: 73,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Streak 🔥',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w400,
              height: 1.0,
              color: isDark
                  ? Colors.white.withOpacity(0.78)
                  : Colors.black.withOpacity(0.58),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '$streakDays Days',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.0,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}