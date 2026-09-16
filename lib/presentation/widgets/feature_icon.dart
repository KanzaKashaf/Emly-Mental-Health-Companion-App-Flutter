import 'package:flutter/material.dart';

class FeatureIcon extends StatelessWidget {
  final String iconPath;
  final String label;

  const FeatureIcon({
    super.key,
    required this.iconPath,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(iconPath, width: 42),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
