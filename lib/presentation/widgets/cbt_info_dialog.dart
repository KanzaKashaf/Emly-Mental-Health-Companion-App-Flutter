import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class CbtInfoDialog {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String description,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'CBT Activity Info',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _CbtInfoPopup(
          isDark: isDark,
          title: title,
          description: description,
          onGotIt: () => Navigator.pop(context),
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

class _CbtInfoPopup extends StatelessWidget {
  final bool isDark;
  final String title;
  final String description;
  final VoidCallback onGotIt;

  const _CbtInfoPopup({
    required this.isDark,
    required this.title,
    required this.description,
    required this.onGotIt,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

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
              width: 332,
              padding: const EdgeInsets.fromLTRB(30, 28, 30, 20),
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
                    child: const Center(
                      child: Icon(
                        Icons.info_rounded,
                        size: 32,
                        color: Color(0xFFF4AD35),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: isDark ? Colors.white : const Color(0xFF252525),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    description,
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
                    onTap: onGotIt,
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
                        'Got It',
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