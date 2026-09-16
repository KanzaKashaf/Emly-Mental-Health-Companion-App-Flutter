import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textColor = isDark ? Colors.white : const Color(0xFF2F2F2F);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pop(context);
        }
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
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back,
                      size: 26,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'My Profile',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 38),
                  child: Column(
                    children: [
                      _ProfileMenuItem(
                        isDark: isDark,
                        icon: 'assets/images/Profile.png',
                        title: 'Personal Info',
                        onTap: () async {
                          final updated = await Navigator.pushNamed(
                            context,
                            AppRoutes.personalInfo,
                          );

                          if (updated == true && context.mounted) {
                            Navigator.pop(context, true);
                          }
                        },
                      ),

                      _ProfileMenuItem(
                        isDark: isDark,
                        icon: 'assets/images/Report.png',
                        title: 'My Reports',
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.reports);
                        },
                      ),

                      _ProfileMenuItem(
                        isDark: isDark,
                        icon: 'assets/images/Session.png',
                        title: 'My Sessions',
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.history,
                            arguments: {
                              'source': 'myProfile',
                            },
                          );
                        },
                      ),

                      _ProfileMenuItem(
                        isDark: isDark,
                        icon: 'assets/images/CBTArrow.png',
                        title: 'CBT Progress',
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.progressEvaluation,
                            arguments: {
                              'source': 'myProfile',
                            },
                          );
                        },
                      ),

                      _ProfileMenuItem(
                        isDark: isDark,
                        icon: 'assets/images/Appointment.png',
                        title: 'My Appointments',
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.myAppointments);
                        },
                      ),
                    ],
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

class _ProfileMenuItem extends StatelessWidget {
  final bool isDark;
  final String icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = isDark ? Colors.white : const Color(0xFF2F2F2F);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 23),
        child: Row(
          children: [
            Image.asset(
              icon,
              width: 22,
              height: 22,
              fit: BoxFit.contain,
              color: itemColor,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w400,
                height: 1.0,
                color: itemColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}