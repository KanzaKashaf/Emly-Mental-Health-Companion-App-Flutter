import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../../../routes/app_routes.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 100),

            /// IMAGE AREA (CHAT SKELETON + ICON)
            Expanded(
              flex: 4,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      /// Chat skeleton — full width, full content visible
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            isDark
                                ? 'assets/images/Chat_Skeloton_Dark2.png'
                                : 'assets/images/Chat_Skeloton_Light2.png',
                            width: constraints.maxWidth,
                            fit: BoxFit.fitWidth,
                          ),
                        ),
                      ),

                      /// Center icon
                      Image.asset(
                        isDark
                            ? 'assets/images/Icon_DarkMode.png'
                            : 'assets/images/Icon_LightMode.png',
                        width: constraints.maxWidth * 0.32,
                        fit: BoxFit.contain,
                      ),
                    ],
                  );
                },
              ),
            ),

            /// TEXT + BUTTONS
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    /// HEADING
                    Text(
                      'A safe space made just\nfor you.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.2, // 120%
                        letterSpacing: 0,
                      ),
                    ),

                    const SizedBox(height: 12),

                    /// BODY TEXT
                    Text(
                      'Share your feelings freely and get supportive, understanding responses powered by AI. Start your journey toward emotional clarity and peace.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.4, // 140%
                        letterSpacing: 0,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),

                    const SizedBox(height: 28),

                    /// BUTTONS
                    Column(
                      children: [
                        PrimaryButton(
                          text: 'Log in',
                          onTap: () {
                            Navigator.pushNamed(context, AppRoutes.login);
                          },
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          text: 'Sign Up',
                          filled: false,
                          onTap: () {
                            Navigator.pushNamed(context, AppRoutes.signup);
                          },
                        ),
                      ],
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
}
