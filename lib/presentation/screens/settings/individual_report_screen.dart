import 'package:flutter/material.dart';

import '../../../../routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';
import '../../../../core/data/repositories/report_repository.dart';
import '../../../../core/services/report_pdf_service.dart';

class IndividualReportScreen extends StatefulWidget {
  const IndividualReportScreen({super.key});

  @override
  State<IndividualReportScreen> createState() => _IndividualReportScreenState();
}

class _IndividualReportScreenState extends State<IndividualReportScreen> {
  bool _argsRead = false;
  bool _loading = true;
  bool _isExportingPdf = false;

  String? _sessionId;
  ReportDetail? _report;

  final Set<int> _expandedCriteria = {0};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_argsRead) return;
    _argsRead = true;

    _readArgsAndLoad();
  }

  Future<void> _readArgsAndLoad() async {
    try {
      final args = ModalRoute.of(context)?.settings.arguments;

      if (args is Map) {
        _sessionId = args['sessionId']?.toString();

        final rawReport = args['report'];

        if (rawReport is Map) {
          _report = ReportDetail.fromJson(
            Map<String, dynamic>.from(rawReport),
          );
        }
      }

      if (_report == null &&
          _sessionId != null &&
          _sessionId!.trim().isNotEmpty) {
        _report = await AppServices.reportRepository.getReportBySessionId(
          _sessionId!,
        );
      }

      if (!mounted) return;

      setState(() => _loading = false);
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      _showError(
        e.message.isNotEmpty ? e.message : 'Failed to load report.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showError('Failed to load report.');
    }
  }

  Future<void> _downloadReportPdf(ReportDetail report) async {
    if (_isExportingPdf) return;

    setState(() => _isExportingPdf = true);

    try {
      final result = await ReportPdfService.generateSaveAndOpen(
        report: report,
        sessionId: _sessionId,
      );

      if (!mounted) return;

      setState(() => _isExportingPdf = false);

      _showSuccess('PDF saved: ${result.fileName}');
    } catch (e) {
      if (!mounted) return;

      setState(() => _isExportingPdf = false);

      _showError('Failed to create PDF. Please try again.');
    }
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

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<_SymptomItem> _symptomsFromReport(ReportDetail report) {
    final coverage = report.symptomCoverage;

    if (coverage.isEmpty) return [];

    return coverage.entries.map((entry) {
      return _SymptomItem(
        title: _titleCase(entry.key.replaceAll('_', ' ')),
        status: _statusFromValue(entry.value),
      );
    }).toList();
  }

  List<_CriterionItem> _criteriaFromReport(ReportDetail report) {
    final table = report.criteriaTable;

    if (table.isEmpty) return [];

    final items = <_CriterionItem>[];

    int index = 0;

    for (final entry in table.entries) {
      final raw = entry.value;

      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);

        final label = (map['label'] ??
                map['title'] ??
                map['name'] ??
                'Screening criterion')
            .toString();

        final statusText = (map['status'] ??
                map['result'] ??
                map['state'] ??
                'UNKNOWN')
            .toString();

        final details = _criterionDetails(map);

        items.add(
          _CriterionItem(
            title: 'Criterion ${entry.key}',
            subtitle: label,
            statusText: _formatStatusText(statusText),
            status: _statusFromStatusText(statusText),
            expanded: _expandedCriteria.contains(index),
            details: details,
          ),
        );
      } else {
        final value = raw.toString();

        items.add(
          _CriterionItem(
            title: 'Criterion ${entry.key}',
            subtitle: 'Screening criterion',
            statusText: _formatStatusText(value),
            status: _statusFromStatusText(value),
            expanded: _expandedCriteria.contains(index),
            details: value,
          ),
        );
      }

      index++;
    }

    return items;
  }

  String? _criterionDetails(Map<String, dynamic> map) {
    final lines = <String>[];

    final evidence = map['evidence'];
    if (evidence is List && evidence.isNotEmpty) {
      lines.add('Evidence:');
      for (final item in evidence) {
        final text = item.toString().trim();
        if (text.isNotEmpty) lines.add('• $text');
      }
    } else if (evidence != null && evidence.toString().trim().isNotEmpty) {
      lines.add('Evidence:');
      lines.add('• ${evidence.toString().trim()}');
    }

    final explanation =
        map['explanation'] ?? map['reason'] ?? map['description'] ?? map['note'];

    if (explanation != null && explanation.toString().trim().isNotEmpty) {
      if (lines.isNotEmpty) lines.add('');
      lines.add(explanation.toString().trim());
    }

    if (lines.isEmpty) return null;

    return lines.join('\n');
  }

  _Status _statusFromValue(dynamic value) {
    if (value is bool) {
      return value ? _Status.met : _Status.notMet;
    }

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);

      return _statusFromStatusText(
        (map['status'] ?? map['value'] ?? map['result'] ?? '').toString(),
      );
    }

    return _statusFromStatusText(value?.toString() ?? '');
  }

  _Status _statusFromStatusText(String value) {
    final v = value.trim().toLowerCase();

    if (v == 'true' ||
        v == 'met' ||
        v == 'yes' ||
        v == 'present' ||
        v == 'supported') {
      return _Status.met;
    }

    if (v == 'false' ||
        v == 'not_met' ||
        v == 'not met' ||
        v == 'no' ||
        v == 'absent' ||
        v == 'unsupported') {
      return _Status.notMet;
    }

    return _Status.unknown;
  }

  String _formatOutcome(String value) {
    return _titleCase(
      value.replaceAll('_', ' ').replaceAll('-', ' '),
    );
  }

  String _formatStatusText(String value) {
    final cleaned = value.trim();

    if (cleaned.isEmpty || cleaned.toLowerCase() == 'null') {
      return 'UNKNOWN';
    }

    return cleaned.replaceAll('_', ' ').toUpperCase();
  }

  String _formatConfidence(double value) {
    final normalized = value <= 1 ? value * 100 : value;
    return '${normalized.round()}%';
  }

  String _formatSeverity(String value) {
    final cleaned = value.trim();

    if (cleaned.isEmpty || cleaned.toLowerCase() == 'null') return 'N/A';

    return _titleCase(cleaned);
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

  List<String> _nextStepsFromReport(ReportDetail report) {
    if (report.nextSteps.isNotEmpty) return report.nextSteps;

    if (report.plainSummary.trim().isNotEmpty) {
      return [
        report.plainSummary.trim(),
      ];
    }

    return [
      'Continue monitoring your symptoms and mood patterns.',
      'Consider speaking with a qualified mental health professional.',
      'Use this report as educational screening support, not as a diagnosis.',
    ];
  }

  String _disclaimerFromReport(ReportDetail report) {
    final disclaimer = report.disclaimer.trim();

    if (disclaimer.isNotEmpty) return disclaimer;

    return 'This is educational screening, not a diagnosis. Please consult a professional mental health practitioner.';
  }

  void _toggleCriterion(int index) {
    setState(() {
      if (_expandedCriteria.contains(index)) {
        _expandedCriteria.remove(index);
      } else {
        _expandedCriteria.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    final subTextColor = isDark
        ? Colors.white.withOpacity(0.64)
        : Colors.black.withOpacity(0.46);

    final report = _report;

    final symptoms = report == null ? <_SymptomItem>[] : _symptomsFromReport(report);
    final criteria =
        report == null ? <_CriterionItem>[] : _criteriaFromReport(report);
    final nextSteps =
        report == null ? <String>[] : _nextStepsFromReport(report);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: bgColor,
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
                    'Screening Report',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : report == null
                        ? Center(
                            child: Text(
                              'Report not available',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                color: subTextColor,
                              ),
                            ),
                          )
                        : Scrollbar(
                            thumbVisibility: true,
                            radius: const Radius.circular(10),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(14, 24, 14, 26),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _ReportHeaderCard(
                                    isDark: isDark,
                                    outcome: _formatOutcome(report.outcome),
                                    disorderName: report.disorderName,
                                    confidence:
                                        _formatConfidence(report.confidence),
                                    severity: _formatSeverity(report.severity),
                                  ),

                                  const SizedBox(height: 8),

                                  Text(
                                    'Symptom Coverage',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      height: 1.0,
                                      color: textColor,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  if (symptoms.isEmpty)
                                    _EmptySectionCard(
                                      isDark: isDark,
                                      text:
                                          'No symptom coverage details available for this report.',
                                    )
                                  else
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: symptoms.length,
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 7,
                                        crossAxisSpacing: 14,
                                        childAspectRatio: 4.35,
                                      ),
                                      itemBuilder: (context, index) {
                                        return _SymptomCoverageTile(
                                          item: symptoms[index],
                                          isDark: isDark,
                                        );
                                      },
                                    ),

                                  const SizedBox(height: 10),

                                  Text(
                                    'Why this result?',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      height: 1.0,
                                      color: textColor,
                                    ),
                                  ),

                                  const SizedBox(height: 5),

                                  Text(
                                    'Based on your answers, EMLY checked the screening\ncriteria below.',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      height: 1.35,
                                      color: subTextColor,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  if (criteria.isEmpty)
                                    _EmptySectionCard(
                                      isDark: isDark,
                                      text:
                                          'No criteria details available for this report.',
                                    )
                                  else
                                    ...List.generate(
                                      criteria.length,
                                      (index) => Padding(
                                        padding: EdgeInsets.only(
                                          bottom:
                                              index == criteria.length - 1
                                                  ? 18
                                                  : 6,
                                        ),
                                        child: GestureDetector(
                                          onTap: () => _toggleCriterion(index),
                                          behavior: HitTestBehavior.opaque,
                                          child: _CriterionTile(
                                            item: criteria[index],
                                            isDark: isDark,
                                          ),
                                        ),
                                      ),
                                    ),

                                  Text(
                                    'Next Steps',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      height: 1.0,
                                      color: textColor,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  ...List.generate(
                                    nextSteps.length,
                                    (index) => Padding(
                                      padding: EdgeInsets.only(
                                        bottom:
                                            index == nextSteps.length - 1
                                                ? 20
                                                : 4,
                                      ),
                                      child: _NextStepTile(
                                        number: index + 1,
                                        text: nextSteps[index],
                                        isDark: isDark,
                                      ),
                                    ),
                                  ),

                                  _EducationalNotice(
                                    isDark: isDark,
                                    text: _disclaimerFromReport(report),
                                  ),

                                  const SizedBox(height: 140),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: _BottomActionButton(
                                          isDark: isDark,
                                          filled: false,
                                          text: _isExportingPdf ? 'Preparing...' : 'PDF',
                                          icon: Icons.file_download_outlined,
                                          onTap: _isExportingPdf
                                              ? () {}
                                              : () => _downloadReportPdf(report),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _BottomActionButton(
                                          isDark: isDark,
                                          filled: true,
                                          text: 'Find a Doctor',
                                          onTap: () {
                                            Navigator.pushNamed(
                                              context,
                                              AppRoutes.findDoctor,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportHeaderCard extends StatelessWidget {
  final bool isDark;
  final String outcome;
  final String disorderName;
  final String confidence;
  final String severity;

  const _ReportHeaderCard({
    required this.isDark,
    required this.outcome,
    required this.disorderName,
    required this.confidence,
    required this.severity,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final cardColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    final chipColor =
        isDark ? const Color(0xFF505050) : Colors.white.withOpacity(0.94);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(27, 23, 27, 18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(27),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            outcome,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: primary,
            ),
          ),

          const SizedBox(height: 9),

          Text(
            disorderName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 31,
              fontWeight: FontWeight.w500,
              height: 1.28,
              color: textColor,
            ),
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              Expanded(
                child: _HeaderMetricBox(
                  title: 'Confidence',
                  value: confidence,
                  valueColor: textColor,
                  backgroundColor: chipColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _HeaderMetricBox(
                  title: 'Severity',
                  value: severity,
                  valueColor: const Color(0xFFFFB121),
                  backgroundColor: chipColor,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetricBox extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;
  final Color backgroundColor;
  final bool isDark;

  const _HeaderMetricBox({
    required this.title,
    required this.value,
    required this.valueColor,
    required this.backgroundColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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

          const SizedBox(height: 6),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: value.length > 5 ? 20 : 21,
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

class _SymptomCoverageTile extends StatelessWidget {
  final _SymptomItem item;
  final bool isDark;

  const _SymptomCoverageTile({
    required this.item,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          _StatusIcon(status: item.status, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.0,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CriterionTile extends StatelessWidget {
  final _CriterionItem item;
  final bool isDark;

  const _CriterionTile({
    required this.item,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    final subColor = isDark
        ? Colors.white.withOpacity(0.68)
        : Colors.black.withOpacity(0.52);

    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(11, item.expanded ? 10 : 7, 12, 7),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment:
            item.expanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: item.expanded ? 2 : 0),
            child: _StatusIcon(status: item.status, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.05,
                    color: textColor,
                  ),
                ),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.05,
                    color: subColor,
                  ),
                ),
                if (item.expanded && item.details != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.details!,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                      color: subColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: EdgeInsets.only(top: item.expanded ? 2 : 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.statusText,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  item.expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStepTile extends StatelessWidget {
  final int number;
  final String text;
  final bool isDark;

  const _NextStepTile({
    required this.number,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final numberBg = isDark
        ? AppColors.primaryDark.withOpacity(0.28)
        : AppColors.primaryLight.withOpacity(0.20);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.fromLTRB(11, 14, 14, 14),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              color: numberBg,
              shape: BoxShape.circle,
            ),
            child: Text(
              number.toString(),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.0,
                color: primary,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EducationalNotice extends StatelessWidget {
  final bool isDark;
  final String text;

  const _EducationalNotice({
    required this.isDark,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final boxColor = isDark
        ? const Color(0xFFF4AD35)
        : const Color(0xFFFFF1DB);

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    final bulletColor = isDark ? Colors.white : const Color(0xFFF4AD35);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 9),
            decoration: BoxDecoration(
              color: bulletColor,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  final bool isDark;
  final bool filled;
  final String text;
  final IconData? icon;
  final VoidCallback onTap;

  const _BottomActionButton({
    required this.isDark,
    required this.filled,
    required this.text,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final bgColor = filled
        ? primary
        : (isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD));

    final textColor = filled ? Colors.white : primary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 49,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: textColor),
              const SizedBox(width: 12),
            ],
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.0,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  final bool isDark;
  final String text;

  const _EmptySectionCard({
    required this.isDark,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);
    final fg = isDark
        ? Colors.white.withOpacity(0.68)
        : Colors.black.withOpacity(0.52);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          height: 1.4,
          color: fg,
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final _Status status;
  final double size;

  const _StatusIcon({
    required this.status,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final asset = switch (status) {
      _Status.met => 'assets/images/Tick3.png',
      _Status.notMet => 'assets/images/Cross.png',
      _Status.unknown => 'assets/images/QuestionMark.png',
    };

    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

class _SymptomItem {
  final String title;
  final _Status status;

  const _SymptomItem({
    required this.title,
    required this.status,
  });
}

class _CriterionItem {
  final String title;
  final String subtitle;
  final String statusText;
  final _Status status;
  final bool expanded;
  final String? details;

  const _CriterionItem({
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.status,
    required this.expanded,
    this.details,
  });
}

enum _Status {
  met,
  notMet,
  unknown,
}