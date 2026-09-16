import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/theme/app_colors.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../../../routes/app_routes.dart';
import '../../../core/data/chat_store.dart';

// API
import '../../../../main.dart';

class SettingsScreen extends StatelessWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final ThemeMode currentTheme;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
    required this.currentTheme,
  });

  /// ───────────────── LOGOUT CONFIRMATION ─────────────────
  Future<bool> _showLogoutConfirm(BuildContext context) async {
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
                    'Logout',
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
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.15),
                    ),
                  ),
                  const Text(
                    'Are you sure you want to logout?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
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
                              'Logout',
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

  /// ───────────────── ACCOUNT DELETE CONFIRMATION ─────────────────
  Future<bool> _showAccountDeleteConfirm(BuildContext context) async {
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
                    'Account Delete',
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
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.15),
                    ),
                  ),
                  const Text(
                    'Are you sure you want to delete your account?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
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
                              color: const Color(0xFFF63A3A),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Text(
                              'Delete',
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

  /// ───────────────── UI ─────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ThemeMode resolvedTheme = isDark ? ThemeMode.dark : ThemeMode.light;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushReplacementNamed(context, AppRoutes.home);
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
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, AppRoutes.home);
                    },
                    icon: Icon(
                      Icons.arrow_back,
                      size: 26,
                      color: isDark ? Colors.white : const Color(0xFF2F2F2F),
                    ),
                  ),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF2F2F2F),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// ACCOUNT
                      _sectionTitle('Account'),
                      _settingsItem(
                        context,
                        icon: 'assets/images/Profile.png',
                        label: 'Profile Settings',
                        onTap: () async {
                          final updated = await Navigator.pushNamed(
                            context,
                            AppRoutes.myProfile,
                          );

                          if (updated == true) {
                            Navigator.pop(context, true);
                          }
                        },
                      ),

                      const SizedBox(height: 10),

                      /// SUPPORT
                      _sectionTitle('Support'),
                      _settingsItem(
                        context,
                        icon: 'assets/images/Question.png',
                        label: 'Help center',
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.helpCenter,
                          );
                        },
                      ),
                      _settingsItem(
                        context,
                        icon: 'assets/images/Doctor.png',
                        label: 'Find a Doctor',
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.findDoctor);
                        },
                      ),

                      const SizedBox(height: 10),

                      /// PRIVACY & SAFETY
                      _sectionTitle('Privacy & Safety'),
                      _settingsItem(
                        context,
                        icon: 'assets/images/Data.png',
                        label: 'Data Controls',
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.dataControls);
                        },
                      ),
                      _settingsItem(
                        context,
                        icon: 'assets/images/Lock.png',
                        label: 'Emergency Contacts',
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.emergencyContacts);
                        },
                      ),
                      _settingsItem(
                        context,
                        icon: 'assets/images/Term.png',
                        label: 'Terms and Condition',
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.termsConditions);
                        },
                      ),

                      const SizedBox(height: 10),

                      /// APP PREFERENCES
                      _sectionTitle('App Preferences'),

                      _themeItem(
                        context,
                        resolvedTheme: resolvedTheme,
                      ),

                      _settingsMaterialIconItem(
                        context,
                        icon: Icons.notifications_none_rounded,
                        label: 'CBT Notifications',
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.cbtNotificationSettings);
                        },
                      ),

                      _settingsInfoItem(
                        context,
                        icon: 'assets/images/Subscription.png',
                        label: 'Subscription',
                        value: 'Free Tier',
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.subscription,
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      _logoutItem(
                        context,
                        onTap: () async {
                          final shouldLogout = await _showLogoutConfirm(context);
                          if (!shouldLogout) return;

                          try {
                            await AppServices.authRepository.logout();
                          } catch (_) {
                            await AppServices.tokenStore.clear();
                          }

                          try {
                            await GoogleSignIn.instance.signOut();
                          } catch (_) {}

                          chatStore.clearAll();

                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.welcome,
                              (route) => false,
                            );
                          }
                        },
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        /// BOTTOM NAV
        bottomNavigationBar: BottomNavBar(
          currentIndex: 4,
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

            if (i == 3) {
              Navigator.pushReplacementNamed(context, AppRoutes.history);
            }
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.0,
          color: Color(0xFF7A7A7A),
        ),
      ),
    );
  }

  Widget _settingsItem(
    BuildContext context, {
    required String icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemColor = color ?? (isDark ? Colors.white : const Color(0xFF2F2F2F));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 18, top: 9, bottom: 9),
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
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
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

  Widget _settingsInfoItem(
    BuildContext context, {
    required String icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemColor = isDark ? Colors.white : const Color(0xFF2F2F2F);
    final valueColor = isDark
        ? Colors.white.withOpacity(0.62)
        : Colors.black.withOpacity(0.55);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 18, top: 9, bottom: 9),
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
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.0,
                  color: itemColor,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.0,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsMaterialIconItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemColor = isDark ? Colors.white : const Color(0xFF2F2F2F);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 18, top: 9, bottom: 9),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: itemColor,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
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

  Widget _logoutItem(
    BuildContext context, {
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemColor = isDark ? Colors.white : const Color(0xFF2F2F2F);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 9, bottom: 9),
        child: Row(
          children: [
            Image.asset(
              'assets/images/Logout.png',
              width: 22,
              height: 22,
              fit: BoxFit.contain,
              color: itemColor,
            ),
            const SizedBox(width: 12),
            Text(
              'Logout',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
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

  Widget _themeItem(
    BuildContext context, {
    required ThemeMode resolvedTheme,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemColor = isDark ? Colors.white : const Color(0xFF2F2F2F);
    final valueColor = isDark
        ? Colors.white.withOpacity(0.62)
        : Colors.black.withOpacity(0.55);

    return Padding(
      padding: const EdgeInsets.only(left: 18, top: 9, bottom: 9),
      child: Row(
        children: [
          Image.asset(
            'assets/images/Theme.png',
            width: 22,
            height: 22,
            fit: BoxFit.contain,
            color: itemColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Theme',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.0,
                color: itemColor,
              ),
            ),
          ),
          PopupMenuButton<ThemeMode>(
            onSelected: onThemeChanged,
            color: isDark ? const Color(0xFF2B2B2B) : Colors.white,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: ThemeMode.light,
                child: Text('Light'),
              ),
              PopupMenuItem(
                value: ThemeMode.dark,
                child: Text('Dark'),
              ),
            ],
            child: Row(
              children: [
                Text(
                  resolvedTheme == ThemeMode.dark ? 'Dark' : 'Light',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: valueColor,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: valueColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}