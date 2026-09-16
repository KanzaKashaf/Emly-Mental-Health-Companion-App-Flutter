import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';
import '../../widgets/primary_button.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';
import '../../../../core/data/repositories/report_repository.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true;
  bool _error = false;
  List<ReportListItem> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final reports = await AppServices.reportRepository.getReports();

      if (!mounted) return;

      setState(() {
        _reports = reports;
        _loading = false;
        _error = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = true;
      });

      _showError(
        e.message.isNotEmpty ? e.message : 'Failed to load reports.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = true;
      });

      _showError('Failed to load reports.');
    }
  }

  void _openReport(ReportListItem report) {
    Navigator.pushNamed(
      context,
      AppRoutes.individualReport,
      arguments: {
        'sessionId': report.sessionId,
        'report': report.detail.toJson(),
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) {
      return _ReportsSkeleton(
        isDark: isDark,
        reportCount: _reports.isNotEmpty ? _reports.length : 3,
      );
    }

    if (_error && _reports.isEmpty) {
      return _ReportsEmptyState(
        isDark: isDark,
        title: 'Could not load reports',
        subtitle: 'Please check your connection and try again.',
        buttonText: 'Retry',
        onTap: _loadReports,
      );
    }

    if (_reports.isEmpty) {
      return _ReportsEmptyState(
        isDark: isDark,
        title: 'No reports yet',
        subtitle:
            'Complete a screening session first. When your session report is ready, it will appear here.',
        buttonText: 'Start Session',
        onTap: () {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.chat,
            arguments: {'startFresh': true},
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final report = _reports[index];

          return _ReportCard(
            report: report,
            isDark: isDark,
            onViewReport: () => _openReport(report),
          );
        },
      ),
    );
  }

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
                    'Reports',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),

              Expanded(child: _buildBody(isDark)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportsEmptyState extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onTap;

  const _ReportsEmptyState({
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/Robot2.png',
              width: 138,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: onSurface.withOpacity(0.62),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: PrimaryButton(
                text: buttonText,
                onTap: onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsSkeleton extends StatelessWidget {
  final bool isDark;
  final int reportCount;

  const _ReportsSkeleton({
    required this.isDark,
    required this.reportCount,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
      highlightColor:
          isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF6F8FC),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: reportCount,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const _ReportCardSkeleton(),
      ),
    );
  }
}

class _ReportCardSkeleton extends StatelessWidget {
  const _ReportCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 168,
      padding: const EdgeInsets.fromLTRB(15, 10, 7, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: _SkeletonBox(width: 105, height: 14, radius: 6),
          ),

          SizedBox(height: 10),

          _SkeletonBox(width: 220, height: 12, radius: 6),

          SizedBox(height: 8),

          _SkeletonBox(width: 180, height: 16, radius: 6),

          SizedBox(height: 4),

          _SkeletonBox(width: 145, height: 16, radius: 6),

          Spacer(),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ReportMetricChipSkeleton(),
              SizedBox(width: 8),
              _ReportMetricChipSkeleton(),
              Spacer(),
              _SkeletonBox(width: 119, height: 30, radius: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportMetricChipSkeleton extends StatelessWidget {
  const _ReportMetricChipSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 48,
      padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(width: 60, height: 11, radius: 5),
          SizedBox(height: 5),
          _SkeletonBox(width: 38, height: 14, radius: 6),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.height,
    this.width = double.infinity,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportListItem report;
  final bool isDark;
  final VoidCallback onViewReport;

  const _ReportCard({
    required this.report,
    required this.isDark,
    required this.onViewReport,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    final textColor = isDark ? Colors.white : const Color(0xFF202020);
    final secondaryText = isDark
        ? Colors.white.withOpacity(0.72)
        : Colors.black.withOpacity(0.56);

    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final chipColor =
        isDark ? const Color(0xFF505050) : Colors.white.withOpacity(0.94);

    return Container(
      width: double.infinity,
      height: 168,
      padding: const EdgeInsets.fromLTRB(15, 10, 7, 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _formatDate(report.completedAt),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.0,
                color: secondaryText,
              ),
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'Session : “${report.sessionTitle}”',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.0,
              color: primary,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            report.disorderName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.0,
              color: textColor,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            _formatOutcome(report.outcome),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.0,
              color: secondaryText,
            ),
          ),

          const Spacer(),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ReportMetricChip(
                title: 'Confidence',
                value: _formatConfidence(report.confidence),
                valueColor: textColor,
                backgroundColor: chipColor,
              ),
              const SizedBox(width: 8),
              _ReportMetricChip(
                title: 'Severity',
                value: _formatSeverity(report.severity),
                valueColor: const Color(0xFFFFB121),
                backgroundColor: chipColor,
              ),
              const Spacer(),
              GestureDetector(
                onTap: onViewReport,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 119,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'View Report',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';

    final local = date.toLocal();

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  String _formatConfidence(double value) {
    final normalized = value <= 1 ? value * 100 : value;
    return '${normalized.round()}%';
  }

  String _formatSeverity(String value) {
    final cleaned = value.trim();

    if (cleaned.isEmpty || cleaned.toLowerCase() == 'null') {
      return 'N/A';
    }

    return _titleCase(cleaned);
  }

  String _formatOutcome(String value) {
    return _titleCase(
      value.replaceAll('_', ' ').replaceAll('-', ' '),
    );
  }

  String _titleCase(String value) {
    final cleaned = value.trim().toLowerCase();

    if (cleaned.isEmpty) return 'N/A';

    return cleaned
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }
}

class _ReportMetricChip extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;
  final Color backgroundColor;

  const _ReportMetricChip({
    required this.title,
    required this.value,
    required this.valueColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 82,
      height: 48,
      padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.0,
              color: isDark
                  ? Colors.white.withOpacity(0.78)
                  : Colors.black.withOpacity(0.56),
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.0,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}