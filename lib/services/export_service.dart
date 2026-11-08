import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/trip_model.dart';

class ExportService {
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

  static String _duration(Duration d) {
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }

  static String _fileName(String label, String extension) {
    final safeLabel = label.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return 'iv_trips_${safeLabel}_$stamp.$extension';
  }

  static Future<void> _share(
    List<int> bytes,
    String fileName,
    String mimeType,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        subject: fileName,
      ),
    );
  }

  static void _boldHeader(Sheet sheet, int columns) {
    for (var c = 0; c < columns; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = CellStyle(bold: true);
    }
  }

  static Future<void> exportExcel(
    List<IvTripModel> trips, {
    required String label,
  }) async {
    final excel = Excel.createExcel();
    final tripsSheet = excel['IV Trips'];
    final eventsSheet = excel['Stoppage Events'];
    excel.delete('Sheet1');

    tripsSheet.appendRow([
      TextCellValue('Trip ID'),
      TextCellValue('Device ID'),
      TextCellValue('Device Name'),
      TextCellValue('Patient'),
      TextCellValue('Condition / Fluid'),
      TextCellValue('Started'),
      TextCellValue('Ended'),
      TextCellValue('Duration'),
      TextCellValue('Stoppage Count'),
      TextCellValue('Completed By'),
    ]);
    _boldHeader(tripsSheet, 10);

    eventsSheet.appendRow([
      TextCellValue('Trip ID'),
      TextCellValue('Device Name'),
      TextCellValue('Patient'),
      TextCellValue('Stopped At'),
      TextCellValue('Resolved At'),
      TextCellValue('Resolved By'),
    ]);
    _boldHeader(eventsSheet, 6);

    for (final t in trips) {
      tripsSheet.appendRow([
        TextCellValue(t.tripId),
        TextCellValue(t.deviceId),
        TextCellValue(t.deviceName),
        TextCellValue(t.patientName),
        TextCellValue(t.issue),
        TextCellValue(_dateTimeFormat.format(t.startTime)),
        TextCellValue(_dateTimeFormat.format(t.endTime)),
        TextCellValue(_duration(t.totalDuration)),
        IntCellValue(t.stoppedEvents.length),
        TextCellValue(t.completedBy),
      ]);

      for (final e in t.stoppedEvents) {
        eventsSheet.appendRow([
          TextCellValue(t.tripId),
          TextCellValue(t.deviceName),
          TextCellValue(t.patientName),
          TextCellValue(_dateTimeFormat.format(e.time)),
          TextCellValue(
            e.resolvedTime != null
                ? _dateTimeFormat.format(e.resolvedTime!)
                : 'Unresolved',
          ),
          TextCellValue(e.resolvedBy ?? ''),
        ]);
      }
    }

    final bytes = excel.save();
    if (bytes == null) return;

    await _share(
      bytes,
      _fileName(label, 'xlsx'),
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  static Future<void> exportPdf(
    List<IvTripModel> trips, {
    required String label,
  }) async {
    final doc = pw.Document();

    final headers = [
      'Trip ID',
      'Device',
      'Patient',
      'Condition / Fluid',
      'Started',
      'Ended',
      'Duration',
      'Stops',
      'Completed By',
    ];

    pw.Widget cell(String text, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: headers.map((h) => cell(h, bold: true)).toList(),
      ),
      ...trips.map(
        (t) => pw.TableRow(
          children: [
            cell(t.tripId),
            cell('${t.deviceName} (${t.deviceId})'),
            cell(t.patientName),
            cell(t.issue),
            cell(_dateTimeFormat.format(t.startTime)),
            cell(_dateTimeFormat.format(t.endTime)),
            cell(_duration(t.totalDuration)),
            cell(t.stoppedEvents.length.toString()),
            cell(t.completedBy),
          ],
        ),
      ),
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'IV Infusion Records - $label',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated ${_dateTimeFormat.format(DateTime.now())} - ${trips.length} record(s)',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            children: rows,
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await _share(bytes, _fileName(label, 'pdf'), 'application/pdf');
  }
}