import 'package:flutter/material.dart';

class QuickReplyChips extends StatelessWidget {
  final ValueChanged<String> onTap;

  const QuickReplyChips({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final replies = [
      'I feel anxious',
      'I feel stressed',
      'I want to relax',
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          return ActionChip(
            label: Text(replies[i]),
            onPressed: () => onTap(replies[i]),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: replies.length,
      ),
    );
  }
}
