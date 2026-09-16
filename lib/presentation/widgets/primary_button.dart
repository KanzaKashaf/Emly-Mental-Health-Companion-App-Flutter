import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool filled;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onTap,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    late Color backgroundColor;
    late Color textColor;

    if (filled) {
      // NEXT / LOGIN BUTTON
      backgroundColor =
          isDark ? AppColors.primaryDark : AppColors.primaryLight;
      textColor = Colors.white;
    } else {
      // SKIP / SIGN UP BUTTON
      backgroundColor = isDark
          ? const Color(0xFF2B2B2B)
          : const Color(0xFFF4F7FD);
      textColor = isDark ? Colors.white : AppColors.primaryLight;
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
