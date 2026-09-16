import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class CbtActivityHistorySection extends StatelessWidget {
  final bool isDark;
  final bool showHistory;
  final VoidCallback onToggle;
  final List<CbtActivityHistoryViewItem> entries;

  const CbtActivityHistorySection({
    super.key,
    required this.isDark,
    required this.showHistory,
    required this.onToggle,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final visibleEntries = showHistory ? entries : entries.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Past Entries',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 12),

        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Text(
                showHistory ? 'View all' : 'View all',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.62),
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                showHistory ? Icons.arrow_downward : Icons.arrow_forward,
                size: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.62),
              ),
            ],
          ),
        ),

        if (showHistory) ...[
          const SizedBox(height: 16),

          ...visibleEntries.map(
            (entry) => _HistoryEntryCard(
              isDark: isDark,
              primary: primary,
              entry: entry,
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryEntryCard extends StatefulWidget {
  final bool isDark;
  final Color primary;
  final CbtActivityHistoryViewItem entry;

  const _HistoryEntryCard({
    required this.isDark,
    required this.primary,
    required this.entry,
  });

  @override
  State<_HistoryEntryCard> createState() => _HistoryEntryCardState();
}

class _HistoryEntryCardState extends State<_HistoryEntryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.isDark
        ? const Color(0xFF2B2B2B)
        : const Color(0xFFF4F7FD);

    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(3),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.entry.dateLabel,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: onSurface,
                    ),
                  ),
                ),
                Text(
                  widget.entry.trailingText,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: widget.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: widget.primary,
                ),
              ],
            ),

            if (_expanded) ...[
              const SizedBox(height: 6),

              ...widget.entry.lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.18,
                      color: onSurface.withOpacity(0.70),
                    ),
                  ),
                ),
              ),

              if (widget.entry.note != null &&
                  widget.entry.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Note: ${widget.entry.note}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.18,
                    color: onSurface.withOpacity(0.62),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class CbtActivityHistoryViewItem {
  final String dateLabel;
  final String trailingText;
  final List<String> lines;
  final String? note;

  const CbtActivityHistoryViewItem({
    required this.dateLabel,
    required this.trailingText,
    required this.lines,
    this.note,
  });
}
