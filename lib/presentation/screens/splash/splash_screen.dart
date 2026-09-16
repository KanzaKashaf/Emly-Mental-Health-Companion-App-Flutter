import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../widgets/splash_loader.dart';
import '../../../../routes/app_routes.dart';
import '../home/home_screen.dart';

// API access
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  void _goToProfileCompletion() {
    if (_navigated) return;
    _navigated = true;

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.profileCompletion,
    );
  }

  Future<void> _boot() async {
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('onboardingCompleted') ?? false;

    try {
      final accessToken = await AppServices.tokenStore.getAccessToken();

      if (accessToken == null || accessToken.trim().isEmpty) {
        _goToGuestStart(hasSeenOnboarding);
        return;
      }

      final profile = await AppServices.userRepository.getMe();

      HomeScreen.resetPopupFlagsForNewAppLaunch();

      if (!mounted) return;

      if (!profile.isEmailVerified) {
        _goToAccountOtp(profile.email);
        return;
      }

      if (profile.needsProfileCompletion) {
        _goToProfileCompletion();
        return;
      }

      _goToHome();
    } on ApiError {
      await AppServices.tokenStore.clear();

      if (!mounted) return;
      _goToGuestStart(hasSeenOnboarding);
    } catch (_) {
      // Unknown boot error: keep user out of authenticated area.
      await AppServices.tokenStore.clear();

      if (!mounted) return;
      _goToGuestStart(hasSeenOnboarding);
    }
  }

  void _goToGuestStart(bool hasSeenOnboarding) {
    if (!hasSeenOnboarding) {
      _goToOnboarding();
    } else {
      _goToWelcome();
    }
  }

  void _goToAccountOtp(String email) {
    if (_navigated) return;
    _navigated = true;

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.accountCreationOtp,
      arguments: {
        'email': email,
      },
    );
  }

  void _goToHome() {
    if (_navigated) return;
    _navigated = true;

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.home,
    );
  }

  void _goToWelcome() {
    if (_navigated) return;
    _navigated = true;

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.welcome,
    );
  }

  void _goToOnboarding() {
    if (_navigated) return;
    _navigated = true;

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.onboarding,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Image.asset(
              isDark
                  ? 'assets/images/Logo_DarkMode.png'
                  : 'assets/images/Logo_LightMode.png',
              width: 360,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            bottom: 70,
            child: SplashLoader(
              backgroundColor:
                  isDark ? AppColors.primaryDark : AppColors.primaryLight,
            ),
          ),
        ],
      ),
    );
  }
}