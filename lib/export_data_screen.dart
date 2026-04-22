import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Export Data Screen - Choose format (Excel/PDF) and share health records
class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key});

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  List<Map<String, dynamic>> _hrReadings = [];
  List<Map<String, dynamic>> _bpEstimationReadings = [];
  List<Map<String, dynamic>> _bpLogReadings = [];
  String _userName = 'User';
  String _userAge = '';
  String _userHeight = '';
  String _userWeight = '';
  bool _isLoading = true;
  String? _exportingFormat;

  // --- Date range state ---
  bool _exportAll = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedInUserEmail = prefs.getString('loggedInUserEmail') ?? '';
    _userName = prefs.getString('${loggedInUserEmail}_userName') ?? 'User';
    _userAge = prefs.getString('${loggedInUserEmail}_userAge') ?? '';
    _userHeight = prefs.getString('${loggedInUserEmail}_userHeight') ?? '';
    _userWeight = prefs.getString('${loggedInUserEmail}_userWeight') ?? '';

    final hrHistory = loggedInUserEmail.isNotEmpty
        ? prefs.getStringList('${loggedInUserEmail}_hrHistory') ?? []
        : prefs.getStringList('hrHistory') ?? [];
    final bpHistory = loggedInUserEmail.isNotEmpty
        ? prefs.getStringList('${loggedInUserEmail}_bpHistory') ?? []
        : prefs.getStringList('bpHistory') ?? [];

    final hrReadings = <Map<String, dynamic>>[];
    final bpEstimationReadings = <Map<String, dynamic>>[];
    final bpLogReadings = <Map<String, dynamic>>[];

    for (final jsonStr in hrHistory) {
      try {
        final r = jsonDecode(jsonStr) as Map<String, dynamic>;
        hrReadings.add(r);
      } catch (_) {}
    }
    for (final jsonStr in bpHistory) {
      try {
        final r = jsonDecode(jsonStr) as Map<String, dynamic>;
        if ((r['type'] as String? ?? 'BP') == 'BP_LOG') {
          bpLogReadings.add(r);
        } else {
          bpEstimationReadings.add(r);
        }
      } catch (_) {}
    }

    int sortByDate(Map<String, dynamic> a, Map<String, dynamic> b) {
      try {
        return DateTime.parse(b['date'] as String)
            .compareTo(DateTime.parse(a['date'] as String));
      } catch (_) {
        return 0;
      }
    }

    hrReadings.sort(sortByDate);
    bpEstimationReadings.sort(sortByDate);
    bpLogReadings.sort(sortByDate);

    if (mounted) {
      setState(() {
        _hrReadings = hrReadings;
        _bpEstimationReadings = bpEstimationReadings;
        _bpLogReadings = bpLogReadings;
        _isLoading = false;
      });
    }
  }

  bool get _hasData =>
      _hrReadings.isNotEmpty ||
      _bpEstimationReadings.isNotEmpty ||
      _bpLogReadings.isNotEmpty;

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateOnly(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  double? _parseHRV(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // --- Date range filtering ---
  List<Map<String, dynamic>> _filterByDateRange(
      List<Map<String, dynamic>> readings) {
    if (_exportAll || (_startDate == null && _endDate == null)) {
      return readings;
    }
    return readings.where((r) {
      final d = DateTime.tryParse(r['date'] as String? ?? '');
      if (d == null) return false;
      final dateOnly = DateTime(d.year, d.month, d.day);
      if (_startDate != null && dateOnly.isBefore(_startDate!)) return false;
      if (_endDate != null && dateOnly.isAfter(_endDate!)) return false;
      return true;
    }).toList();
  }

  int get _filteredCount {
    if (!_hasData) return 0;
    return _filterByDateRange(_hrReadings).length +
        _filterByDateRange(_bpEstimationReadings).length +
        _filterByDateRange(_bpLogReadings).length;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)),
              end: now,
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4FACFE),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate =
            DateTime(picked.start.year, picked.start.month, picked.start.day);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day);
        _exportAll = false;
      });
    }
  }

  Future<void> _exportAndShare(String format) async {
    if (!_hasData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No health records to export.'),
          backgroundColor: Color(0xFFED8936),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validate that filtered data exists when using date range
    if (!_exportAll && _filteredCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No records found in the selected date range.'),
          backgroundColor: Color(0xFFED8936),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _exportingFormat = format);

    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final baseName =
          'CardioTrack_${_userName.replaceAll(RegExp(r'[^\w]'), '_')}_$timestamp';

      String filePath;
      if (format == 'excel') {
        filePath = '${dir.path}/$baseName.xlsx';
        await _createExcelFile(filePath);
      } else {
        filePath = '${dir.path}/$baseName.pdf';
        await _createPdfFile(filePath);
      }

      // Check the share result status — resolves regardless of whether
      // the user actually completed the share or dismissed the sheet.
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        text: 'My CardioTrack health records - HR, HRV & BP',
        subject: 'CardioTrack Health Data Export',
      );

      if (mounted) {
        if (result.status == ShareResultStatus.success) {
          // User picked a share target and completed the share
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Exported and shared as ${format.toUpperCase()}'),
                ],
              ),
              backgroundColor: const Color(0xFF48BB78),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (result.status == ShareResultStatus.dismissed) {
          // User opened the share sheet but dismissed it without sharing
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${format.toUpperCase()} file was not shared. Tap the button again to retry.',
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFED8936),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          // ShareResultStatus.unavailable — platform couldn't determine outcome
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${format.toUpperCase()} file ready but share status is unknown.',
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF718096),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: const Color(0xFFF56565),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingFormat = null);
    }
  }

  Future<void> _createExcelFile(String path) async {
    final hrReadings = _filterByDateRange(_hrReadings);
    final bpEstimationReadings = _filterByDateRange(_bpEstimationReadings);
    final bpLogReadings = _filterByDateRange(_bpLogReadings);

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Summary');

    // Patient Info at top
    final summarySheet = excel['Summary'];
    summarySheet
        .appendRow([TextCellValue('Patient Information'), TextCellValue('')]);
    summarySheet.appendRow([TextCellValue('Name'), TextCellValue(_userName)]);
    summarySheet.appendRow([
      TextCellValue('Age'),
      TextCellValue(_userAge.isNotEmpty ? _userAge : '-')
    ]);
    summarySheet.appendRow([
      TextCellValue('Height (cm)'),
      TextCellValue(_userHeight.isNotEmpty ? _userHeight : '-')
    ]);
    summarySheet.appendRow([
      TextCellValue('Weight (kg)'),
      TextCellValue(_userWeight.isNotEmpty ? _userWeight : '-')
    ]);
    summarySheet.appendRow([TextCellValue(''), TextCellValue('')]);
    // Date range info
    summarySheet.appendRow([
      TextCellValue('Export Range'),
      TextCellValue(_exportAll
          ? 'All Records'
          : '${_startDate != null ? _formatDateOnly(_startDate!) : '-'} to ${_endDate != null ? _formatDateOnly(_endDate!) : '-'}'),
    ]);

    // HR & HRV sheet - add as new sheet
    final hrSheet = excel['HR & HRV'];
    hrSheet.appendRow([
      TextCellValue('Date & Time'),
      TextCellValue('Heart Rate (BPM)'),
      TextCellValue('HRV (ms)'),
    ]);
    for (final r in hrReadings) {
      final hr = r['hr'];
      final hrv = _parseHRV(r['hrv']);
      hrSheet.appendRow([
        TextCellValue(_formatDate(r['date'] as String?)),
        hr != null
            ? IntCellValue(hr is int ? hr : (hr as num).round())
            : TextCellValue('-'),
        hrv != null ? DoubleCellValue(hrv) : TextCellValue('-'),
      ]);
    }

    // BP Estimation sheet (access by name creates it)
    if (bpEstimationReadings.isNotEmpty) {
      final bpSheet = excel['BP Estimation'];
      bpSheet.appendRow([
        TextCellValue('Date & Time'),
        TextCellValue('Systolic'),
        TextCellValue('Diastolic'),
      ]);
      for (final r in bpEstimationReadings) {
        final s = r['systolic'];
        final d = r['diastolic'];
        bpSheet.appendRow([
          TextCellValue(_formatDate(r['date'] as String?)),
          s != null
              ? IntCellValue(s is int ? s : (s as num).round())
              : TextCellValue('-'),
          d != null
              ? IntCellValue(d is int ? d : (d as num).round())
              : TextCellValue('-'),
        ]);
      }
    }

    // BP Log sheet
    if (bpLogReadings.isNotEmpty) {
      final logSheet = excel['BP Log'];
      logSheet.appendRow([
        TextCellValue('Date & Time'),
        TextCellValue('Systolic'),
        TextCellValue('Diastolic'),
        TextCellValue('Notes'),
      ]);
      for (final r in bpLogReadings) {
        final s = r['systolic'];
        final d = r['diastolic'];
        final notes = r['notes'] as String? ?? '';
        logSheet.appendRow([
          TextCellValue(_formatDate(r['date'] as String?)),
          s != null
              ? IntCellValue(s is int ? s : (s as num).round())
              : TextCellValue('-'),
          d != null
              ? IntCellValue(d is int ? d : (d as num).round())
              : TextCellValue('-'),
          TextCellValue(notes),
        ]);
      }
    }

    final bytes = excel.save();
    if (bytes != null) {
      await File(path).writeAsBytes(bytes);
    }
  }

  Future<void> _createPdfFile(String path) async {
    final hrReadings = _filterByDateRange(_hrReadings);
    final bpEstimationReadings = _filterByDateRange(_bpEstimationReadings);
    final bpLogReadings = _filterByDateRange(_bpLogReadings);

    final pdf = pw.Document();

    final dateRangeLabel = _exportAll
        ? 'All Records'
        : '${_startDate != null ? _formatDateOnly(_startDate!) : '-'} to ${_endDate != null ? _formatDateOnly(_endDate!) : '-'}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'CardioTrack Health Report',
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey700,
            ),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Header(
              level: 0,
              child: pw.Text('CardioTrack Health Report',
                  style: const pw.TextStyle(fontSize: 22))),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Patient Information',
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Name: $_userName'),
                pw.Text('Age: ${_userAge.isNotEmpty ? _userAge : '-'}'),
                pw.Text(
                    'Height: ${_userHeight.isNotEmpty ? '$_userHeight cm' : '-'}'),
                pw.Text(
                    'Weight: ${_userWeight.isNotEmpty ? '$_userWeight kg' : '-'}'),
                pw.SizedBox(height: 8),
                pw.Text('Export Range: $dateRangeLabel',
                    style:
                        pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
              'Export date: ${_formatDate(DateTime.now().toIso8601String())}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 24),
          if (hrReadings.isNotEmpty) ...[
            pw.Header(
                level: 1,
                child: pw.Text('Heart Rate & HRV',
                    style: const pw.TextStyle(fontSize: 16))),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cell('Date & Time'),
                    _cell('HR (BPM)'),
                    _cell('HRV (ms)'),
                  ],
                ),
                ...hrReadings.take(50).map((r) => pw.TableRow(
                      children: [
                        _cell(_formatDate(r['date'] as String?)),
                        _cell(r['hr']?.toString() ?? '-'),
                        _cell(_parseHRV(r['hrv'])?.toStringAsFixed(1) ?? '-'),
                      ],
                    )),
              ],
            ),
            if (hrReadings.length > 50)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8),
                child: pw.Text('... and ${hrReadings.length - 50} more records',
                    style:
                        pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ),
            pw.SizedBox(height: 24),
          ],
          if (bpEstimationReadings.isNotEmpty) ...[
            pw.Header(
                level: 1,
                child: pw.Text('BP Estimation',
                    style: const pw.TextStyle(fontSize: 16))),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cell('Date & Time'),
                    _cell('Systolic'),
                    _cell('Diastolic'),
                  ],
                ),
                ...bpEstimationReadings.take(50).map((r) => pw.TableRow(
                      children: [
                        _cell(_formatDate(r['date'] as String?)),
                        _cell(r['systolic']?.toString() ?? '-'),
                        _cell(r['diastolic']?.toString() ?? '-'),
                      ],
                    )),
              ],
            ),
            if (bpEstimationReadings.length > 50)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8),
                child: pw.Text(
                    '... and ${bpEstimationReadings.length - 50} more records',
                    style:
                        pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ),
            pw.SizedBox(height: 24),
          ],
          if (bpLogReadings.isNotEmpty) ...[
            pw.Header(
                level: 1,
                child: pw.Text('BP Log (Manual)',
                    style: const pw.TextStyle(fontSize: 16))),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cell('Date & Time'),
                    _cell('Systolic'),
                    _cell('Diastolic'),
                    _cell('Notes'),
                  ],
                ),
                ...bpLogReadings.take(50).map((r) => pw.TableRow(
                      children: [
                        _cell(_formatDate(r['date'] as String?)),
                        _cell(r['systolic']?.toString() ?? '-'),
                        _cell(r['diastolic']?.toString() ?? '-'),
                        _cell(r['notes']?.toString() ?? '-'),
                      ],
                    )),
              ],
            ),
            if (bpLogReadings.length > 50)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8),
                child: pw.Text(
                    '... and ${bpLogReadings.length - 50} more records',
                    style:
                        pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ),
          ],
        ],
      ),
    );

    final bytes = await pdf.save();
    await File(path).writeAsBytes(bytes);
  }

  pw.Widget _cell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20,
                right: 20,
                bottom: 32,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 22),
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2)),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Export Data',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose format and share with your doctor',
                    style: TextStyle(
                        fontSize: 15, color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: _isLoading
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF4FACFE))),
                  )
                : !_hasData
                    ? SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.folder_open_rounded,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No records to export',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start measuring HR, HRV or BP to build your history.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── DATE RANGE SELECTOR ──────────────────────────
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Export Range',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // All Records toggle
                                  InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => setState(() {
                                      _exportAll = true;
                                      _startDate = null;
                                      _endDate = null;
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _exportAll
                                            ? const Color(0xFF4FACFE)
                                                .withOpacity(0.12)
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _exportAll
                                              ? const Color(0xFF4FACFE)
                                              : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.select_all_rounded,
                                              size: 20,
                                              color: _exportAll
                                                  ? const Color(0xFF4FACFE)
                                                  : Colors.grey[500]),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Export all records',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: _exportAll
                                                  ? const Color(0xFF4FACFE)
                                                  : Colors.grey[700],
                                            ),
                                          ),
                                          const Spacer(),
                                          if (_exportAll)
                                            const Icon(Icons.check_circle,
                                                color: Color(0xFF4FACFE),
                                                size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Select date range button
                                  InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: _pickDateRange,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: !_exportAll
                                            ? const Color(0xFF4FACFE)
                                                .withOpacity(0.12)
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: !_exportAll
                                              ? const Color(0xFF4FACFE)
                                              : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.date_range_rounded,
                                              size: 20,
                                              color: !_exportAll
                                                  ? const Color(0xFF4FACFE)
                                                  : Colors.grey[500]),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              !_exportAll &&
                                                      _startDate != null &&
                                                      _endDate != null
                                                  ? '${_formatDateOnly(_startDate!)}  →  ${_formatDateOnly(_endDate!)}'
                                                  : 'Select date range',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: !_exportAll
                                                    ? const Color(0xFF4FACFE)
                                                    : Colors.grey[700],
                                              ),
                                            ),
                                          ),
                                          Icon(Icons.chevron_right_rounded,
                                              color: !_exportAll
                                                  ? const Color(0xFF4FACFE)
                                                  : Colors.grey[400],
                                              size: 20),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Show matched count when range is selected
                                  if (!_exportAll &&
                                      _startDate != null &&
                                      _endDate != null) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _filteredCount > 0
                                            ? const Color(0xFF48BB78)
                                                .withOpacity(0.1)
                                            : const Color(0xFFF56565)
                                                .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _filteredCount > 0
                                                ? Icons.check_circle_outline
                                                : Icons.warning_amber_rounded,
                                            size: 14,
                                            color: _filteredCount > 0
                                                ? const Color(0xFF48BB78)
                                                : const Color(0xFFF56565),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _filteredCount > 0
                                                ? '$_filteredCount record${_filteredCount == 1 ? '' : 's'} in range'
                                                : 'No records in this range',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _filteredCount > 0
                                                  ? const Color(0xFF48BB78)
                                                  : const Color(0xFFF56565),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // ────────────────────────────────────────────────
                            const SizedBox(height: 20),
                            Text(
                              'Choose export format',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _FormatCard(
                                    title: 'Excel',
                                    subtitle: 'Best for analysis & charts',
                                    icon: Icons.table_chart_rounded,
                                    colors: const [
                                      Color(0xFF11998E),
                                      Color(0xFF38EF7D)
                                    ],
                                    isExporting: _exportingFormat == 'excel',
                                    onTap: () => _exportAndShare('excel'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _FormatCard(
                                    title: 'PDF',
                                    subtitle: 'Easy to view & print',
                                    icon: Icons.picture_as_pdf_rounded,
                                    colors: const [
                                      Color(0xFFEB3349),
                                      Color(0xFFF45C43)
                                    ],
                                    isExporting: _exportingFormat == 'pdf',
                                    onTap: () => _exportAndShare('pdf'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      color: Colors.blue[400], size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${_hrReadings.length} HR/HRV • ${_bpEstimationReadings.length} BP Estimation • ${_bpLogReadings.length} BP Log',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final bool isExporting;
  final VoidCallback onTap;

  const _FormatCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.isExporting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isExporting ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colors[0].withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withOpacity(0.9)),
              ),
              if (isExporting) ...[
                const SizedBox(height: 16),
                const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}