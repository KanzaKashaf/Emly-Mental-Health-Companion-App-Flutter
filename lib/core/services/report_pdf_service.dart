import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/repositories/report_repository.dart';

class ReportPdfResult {
  final String fileName;
  final String path;
  final Uint8List bytes;

  const ReportPdfResult({
    required this.fileName,
    required this.path,
    required this.bytes,
  });
}

class ReportPdfService {
  static Future<ReportPdfResult> generateSaveAndOpen({
    required ReportDetail report,
    required String? sessionId,
  }) async {
    final bytes = await _buildPdf(report: report, sessionId: sessionId);

    final safeDisorder = _safeFilePart(report.disorderName);
    final safeSession = _safeFilePart(sessionId ?? 'session');
    final fileName = 'EMLY_${safeDisorder}_Report_$safeSession.pdf';

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');

    await file.writeAsBytes(bytes, flush: true);

    final openResult = await OpenFilex.open(file.path);

    if (openResult.type != ResultType.done) {
      await Printing.sharePdf(
        bytes: bytes,
        filename: fileName,
      );
    }

    return ReportPdfResult(
      fileName: fileName,
      path: file.path,
      bytes: bytes,
    );
  }

  static Future<Uint8List> _buildPdf({
    required ReportDetail report,
    required String? sessionId,
  }) async {
    final pdf = pw.Document(
      title: 'EMLY Screening Report',
      author: 'EMLY',
      subject: report.disorderName,
      creator: 'EMLY Mobile App',
    );

    final now = DateTime.now();

    final primary = PdfColor.fromHex('#3727AB');
    final primarySoft = PdfColor.fromHex('#EEF0FF');
    final darkText = PdfColor.fromHex('#252525');
    final mutedText = PdfColor.fromHex('#666666');
    final borderColor = PdfColor.fromHex('#E5E7EF');
    final warningBg = PdfColor.fromHex('#FFF1DB');
    final warningText = PdfColor.fromHex('#6B4A00');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 34, 36, 34),
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: borderColor, width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'EMLY Screening Report',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: mutedText,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: mutedText,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            _header(
              primary: primary,
              darkText: darkText,
              mutedText: mutedText,
              report: report,
              generatedAt: now,
              sessionId: sessionId,
            ),

            pw.SizedBox(height: 18),

            _summaryCards(
              primary: primary,
              primarySoft: primarySoft,
              darkText: darkText,
              mutedText: mutedText,
              report: report,
            ),

            pw.SizedBox(height: 22),

            _sectionTitle('Screening Summary', primary),
            pw.SizedBox(height: 8),
            _paragraph(
              report.plainSummary.trim().isNotEmpty
                  ? report.plainSummary.trim()
                  : 'No plain summary was provided for this report.',
              darkText,
            ),

            pw.SizedBox(height: 20),

            _sectionTitle('Symptom Coverage', primary),
            pw.SizedBox(height: 10),
            _symptomCoverage(
              report: report,
              primary: primary,
              darkText: darkText,
              mutedText: mutedText,
              borderColor: borderColor,
            ),

            pw.SizedBox(height: 20),

            _sectionTitle('Criteria Review', primary),
            pw.SizedBox(height: 10),
            _criteriaReview(
              report: report,
              primary: primary,
              darkText: darkText,
              mutedText: mutedText,
              borderColor: borderColor,
            ),

            pw.SizedBox(height: 20),

            _sectionTitle('Next Steps', primary),
            pw.SizedBox(height: 10),
            _nextSteps(
              report: report,
              primary: primary,
              darkText: darkText,
              borderColor: borderColor,
            ),

            pw.SizedBox(height: 20),

            _disclaimerBox(
              text: report.disclaimer.trim().isNotEmpty
                  ? report.disclaimer.trim()
                  : 'This is educational screening support, not a diagnosis. Please consult a qualified mental health professional for clinical guidance.',
              bg: warningBg,
              textColor: warningText,
            ),

            pw.SizedBox(height: 16),

            _smallNote(mutedText),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _header({
    required PdfColor primary,
    required PdfColor darkText,
    required PdfColor mutedText,
    required ReportDetail report,
    required DateTime generatedAt,
    required String? sessionId,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'EMLY',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: primary,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Mental Health Screening Report',
                  style: pw.TextStyle(
                    fontSize: 13,
                    color: mutedText,
                  ),
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: pw.BoxDecoration(
                color: primary,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                _formatOutcome(report.outcome),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 22),
        pw.Text(
          report.disorderName.trim().isNotEmpty
              ? report.disorderName.trim()
              : 'Screening Report',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: darkText,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Generated on ${_formatDateTime(generatedAt)}',
          style: pw.TextStyle(
            fontSize: 10,
            color: mutedText,
          ),
        ),
      ],
    );
  }

  static pw.Widget _summaryCards({
    required PdfColor primary,
    required PdfColor primarySoft,
    required PdfColor darkText,
    required PdfColor mutedText,
    required ReportDetail report,
  }) {
    return pw.Row(
      children: [
        _metricCard(
          title: 'Outcome',
          value: _formatOutcome(report.outcome),
          primary: primary,
          bg: primarySoft,
          darkText: darkText,
          mutedText: mutedText,
        ),
        pw.SizedBox(width: 10),
        _metricCard(
          title: 'Confidence',
          value: _formatConfidence(report.confidence),
          primary: primary,
          bg: PdfColor.fromHex('#F4F7FD'),
          darkText: darkText,
          mutedText: mutedText,
        ),
        pw.SizedBox(width: 10),
        _metricCard(
          title: 'Severity',
          value: _formatSeverity(report.severity),
          primary: PdfColor.fromHex('#F4AD35'),
          bg: PdfColor.fromHex('#FFF7E8'),
          darkText: darkText,
          mutedText: mutedText,
        ),
      ],
    );
  }

  static pw.Widget _metricCard({
    required String title,
    required String value,
    required PdfColor primary,
    required PdfColor bg,
    required PdfColor darkText,
    required PdfColor mutedText,
  }) {
    return pw.Expanded(
      child: pw.Container(
        height: 72,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 9,
                color: mutedText,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              value,
              maxLines: 2,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _sectionTitle(String text, PdfColor primary) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 5),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: primary, width: 1.2),
        ),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 15,
          fontWeight: pw.FontWeight.bold,
          color: primary,
        ),
      ),
    );
  }

  static pw.Widget _paragraph(String text, PdfColor color) {
    return pw.Text(
      text,
      textAlign: pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 11,
        height: 1.45,
        color: color,
      ),
    );
  }

  static pw.Widget _symptomCoverage({
    required ReportDetail report,
    required PdfColor primary,
    required PdfColor darkText,
    required PdfColor mutedText,
    required PdfColor borderColor,
  }) {
    if (report.symptomCoverage.isEmpty) {
      return _emptyCard(
        'No symptom coverage details available.',
        mutedText,
        borderColor,
      );
    }

    final widgets = report.symptomCoverage.entries.map((entry) {
      final label = _titleCase(entry.key.replaceAll('_', ' '));
      final status = _statusLabel(entry.value);
      final statusColor = _statusColor(status);

      return pw.Container(
        width: 162,
        margin: const pw.EdgeInsets.only(right: 8, bottom: 8),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: borderColor, width: 0.8),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          children: [
            pw.Container(
              width: 9,
              height: 9,
              decoration: pw.BoxDecoration(
                color: statusColor,
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Text(
                label,
                maxLines: 1,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: darkText,
                ),
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Text(
              status,
              style: pw.TextStyle(
                fontSize: 8,
                color: statusColor,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }).toList();

    return pw.Wrap(children: widgets);
  }

  static pw.Widget _criteriaReview({
    required ReportDetail report,
    required PdfColor primary,
    required PdfColor darkText,
    required PdfColor mutedText,
    required PdfColor borderColor,
  }) {
    if (report.criteriaTable.isEmpty) {
      return _emptyCard(
        'No criteria details available.',
        mutedText,
        borderColor,
      );
    }

    return pw.Column(
      children: report.criteriaTable.entries.map((entry) {
        final raw = entry.value;

        String label = 'Screening criterion';
        String status = 'UNKNOWN';
        String details = '';

        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);

          label = (map['label'] ??
                  map['title'] ??
                  map['name'] ??
                  'Screening criterion')
              .toString();

          status = (map['status'] ??
                  map['result'] ??
                  map['state'] ??
                  'UNKNOWN')
              .toString();

          details = _criterionDetails(map);
        } else {
          status = raw.toString();
        }

        final formattedStatus = _formatStatus(status);
        final statusColor = _statusColor(formattedStatus);

        return pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderColor, width: 0.8),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Criterion ${entry.key}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: darkText,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          label,
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color: statusColor,
                      borderRadius: pw.BorderRadius.circular(14),
                    ),
                    child: pw.Text(
                      formattedStatus,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ],
              ),
              if (details.trim().isNotEmpty) ...[
                pw.SizedBox(height: 9),
                pw.Text(
                    _cleanPdfText(details),
                    style: pw.TextStyle(
                    fontSize: 9.5,
                    height: 1.35,
                    color: darkText,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  static String _cleanPdfText(String value) {
    return value
        .replaceAll('•', '-')
        .replaceAll('✓', 'Yes')
        .replaceAll('✗', 'No')
        .replaceAll('×', 'x')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '')
        .trim();
  }

  static String _criterionDetails(Map<String, dynamic> map) {
    final lines = <String>[];

    final evidence = map['evidence'];

    if (evidence is List && evidence.isNotEmpty) {
      lines.add('Evidence:');
      for (final item in evidence) {
        final text = _cleanPdfText(item.toString().trim());
        if (text.isNotEmpty) lines.add('- $text');
      }
    } else if (evidence is Map && evidence.isNotEmpty) {
      lines.add('Evidence:');

      final parts = evidence.entries.map((entry) {
        final key = _cleanPdfText(entry.key.toString());
        final value = _cleanPdfText(entry.value.toString());
        return '$key: $value';
      }).join(', ');

      if (parts.trim().isNotEmpty) {
        lines.add('- $parts');
      }
    } else if (evidence != null && evidence.toString().trim().isNotEmpty) {
      lines.add('Evidence:');
      lines.add('- ${_cleanPdfText(evidence.toString().trim())}');
    }

    final explanation =
        map['explanation'] ?? map['reason'] ?? map['description'] ?? map['note'];

    if (explanation != null && explanation.toString().trim().isNotEmpty) {
      if (lines.isNotEmpty) lines.add('');
      lines.add(_cleanPdfText(explanation.toString().trim()));
    }

    return lines.join('\n');
  }

  static pw.Widget _nextSteps({
    required ReportDetail report,
    required PdfColor primary,
    required PdfColor darkText,
    required PdfColor borderColor,
  }) {
    final steps = report.nextSteps.isNotEmpty
        ? report.nextSteps
        : [
            'Continue monitoring your mood and symptoms.',
            'Consider speaking with a qualified mental health professional.',
            'Use this report as educational screening support, not as a diagnosis.',
          ];

    return pw.Column(
      children: List.generate(steps.length, (index) {
        return pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 7),
          padding: const pw.EdgeInsets.all(11),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderColor, width: 0.8),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 18,
                height: 18,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: primary,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Text(
                  '${index + 1}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Text(
                  steps[index],
                  style: pw.TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: darkText,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  static pw.Widget _disclaimerBox({
    required String text,
    required PdfColor bg,
    required PdfColor textColor,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Important Disclaimer',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 10.5,
              height: 1.35,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _emptyCard(
    String text,
    PdfColor mutedText,
    PdfColor borderColor,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor, width: 0.8),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          color: mutedText,
        ),
      ),
    );
  }

  static pw.Widget _smallNote(PdfColor mutedText) {
    return pw.Text(
      'Generated by EMLY. This report summarizes structured screening responses and should be reviewed with a qualified professional when needed.',
      style: pw.TextStyle(
        fontSize: 8.5,
        height: 1.35,
        color: mutedText,
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
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

    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '${months[value.month - 1]} ${value.day}, ${value.year} at $hour:$minute';
  }

  static String _formatConfidence(double value) {
    final normalized = value <= 1 ? value * 100 : value;
    return '${normalized.round()}%';
  }

  static String _formatSeverity(String value) {
    final cleaned = value.trim();

    if (cleaned.isEmpty || cleaned.toLowerCase() == 'null') return 'N/A';

    return _titleCase(cleaned);
  }

  static String _formatOutcome(String value) {
    return _titleCase(value.replaceAll('_', ' ').replaceAll('-', ' '));
  }

  static String _formatStatus(String value) {
    final cleaned = value.trim();

    if (cleaned.isEmpty || cleaned.toLowerCase() == 'null') {
      return 'UNKNOWN';
    }

    return cleaned.replaceAll('_', ' ').replaceAll('-', ' ').toUpperCase();
  }

  static String _statusLabel(dynamic value) {
    if (value is bool) return value ? 'MET' : 'NOT MET';

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return _formatStatus(
        (map['status'] ?? map['value'] ?? map['result'] ?? 'UNKNOWN')
            .toString(),
      );
    }

    return _formatStatus(value?.toString() ?? 'UNKNOWN');
  }

  static PdfColor _statusColor(String status) {
    final s = status.toLowerCase();

    if (s.contains('met') && !s.contains('not')) {
      return PdfColor.fromHex('#18B663');
    }

    if (s.contains('not') || s.contains('false') || s.contains('absent')) {
      return PdfColor.fromHex('#F63A3A');
    }

    return PdfColor.fromHex('#F4AD35');
  }

  static String _titleCase(String value) {
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

  static String _safeFilePart(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    if (cleaned.isEmpty) return 'report';

    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }
}