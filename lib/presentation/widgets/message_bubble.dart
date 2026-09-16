import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool fromUser;
  final DateTime time;

  const MessageBubble({
    super.key,
    required this.text,
    required this.fromUser,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bubbleColor = fromUser
        ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
        : (isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD));

    final textColor = fromUser
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                fromUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight:
                fromUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textSpan = TextSpan(
              text: text,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                height: 1.35,
                color: textColor,
              ),
            );

            final textPainter = TextPainter(
              text: textSpan,
              maxLines: 1,
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: constraints.maxWidth);

            final isSingleLine = !textPainter.didExceedMaxLines;

            if (isSingleLine) {
              /// SINGLE LINE → text + time on SAME line
              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text.rich(textSpan),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(time),
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                ],
              );
            }

            /// MULTI LINE → timestamp on its own bottom-right row
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(textSpan),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    _formatTime(time),
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}
