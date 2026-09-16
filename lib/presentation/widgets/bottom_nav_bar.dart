import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color itemColor(bool selected) {
      if (selected) {
        return isDark ? AppColors.primaryDark : AppColors.primaryLight;
      }
      return isDark
          ? Colors.white.withOpacity(0.6)
          : Colors.black.withOpacity(0.6);
    }

    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: 'assets/images/Chat - Dark.png',
            label: 'Chat',
            selected: currentIndex == 1,
            color: itemColor(currentIndex == 1),
            onTap: () => onTap(1),
          ),
          _NavItem(
            icon: 'assets/images/CBT.png',
            label: 'CBT',
            selected: currentIndex == 2,
            color: itemColor(currentIndex == 2),
            onTap: () => onTap(2),
          ),
          _NavItem(
            icon: 'assets/images/History - Dark.png',
            label: 'History',
            selected: currentIndex == 3,
            color: itemColor(currentIndex == 3),
            onTap: () => onTap(3),
          ),
          _NavItem(
            icon: 'assets/images/Setting - Dark.png',
            label: 'Settings',
            selected: currentIndex == 4,
            color: itemColor(currentIndex == 4),
            onTap: () => onTap(4),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              icon,
              width: 22,
              height: 22,
              color: color,
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.0,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}