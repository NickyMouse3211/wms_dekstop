import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/modules/listener/scan_result.dart';
import '../models/modules/listener/printer_connection_status.dart';
import 'storage_services.dart';
import 'windows_printer_connection_service.dart';

class LabelMargins {
  const LabelMargins({
    this.left = 0,
    this.right = 0,
    this.top = 0,
    this.bottom = 0,
  });
  final double left;
  final double right;
  final double top;
  final double bottom;

  factory LabelMargins.fromJson(Map<String, dynamic>? data) => LabelMargins(
    left: (data?['left'] as num?)?.toDouble() ?? 0,
    right: (data?['right'] as num?)?.toDouble() ?? 0,
    top: (data?['top'] as num?)?.toDouble() ?? 0,
    bottom: (data?['bottom'] as num?)?.toDouble() ?? 0,
  );

  Map<String, double> toJson() => {
    'left': left,
    'right': right,
    'top': top,
    'bottom': bottom,
  };

  String? validate(double width, double height, String label) {
    if ([
      left,
      right,
      top,
      bottom,
    ].any((value) => !value.isFinite || value < 0)) {
      return 'Margin $label harus berupa angka 0 atau lebih.';
    }
    if (width - left - right < 5 || height - top - bottom < 5) {
      return 'Margin $label harus menyisakan area cetak minimal 5 × 5 mm.';
    }
    return null;
  }
}

class LabelPrinterSettings {
  const LabelPrinterSettings({
    this.url = '',
    this.name = '',
    this.qrWidth = 60,
    this.qrHeight = 40,
    this.barcodeWidth = 60,
    this.barcodeHeight = 40,
    this.qrPrintText = true,
    this.barcodePrintText = true,
    this.qrMargins = const LabelMargins(),
    this.barcodeMargins = const LabelMargins(),
  });
  final String url;
  final String name;
  final double qrWidth;
  final double qrHeight;
  final double barcodeWidth;
  final double barcodeHeight;
  final bool qrPrintText;
  final bool barcodePrintText;
  final LabelMargins qrMargins;
  final LabelMargins barcodeMargins;

  bool printText(String type) =>
      type == 'barcode' ? barcodePrintText : qrPrintText;

  PdfPageFormat pageFormat(String type) {
    final margins = type == 'barcode' ? barcodeMargins : qrMargins;
    return PdfPageFormat(
      (type == 'barcode' ? barcodeWidth : qrWidth) * PdfPageFormat.mm,
      (type == 'barcode' ? barcodeHeight : qrHeight) * PdfPageFormat.mm,
      marginLeft: margins.left * PdfPageFormat.mm,
      marginRight: margins.right * PdfPageFormat.mm,
      marginTop: margins.top * PdfPageFormat.mm,
      marginBottom: margins.bottom * PdfPageFormat.mm,
    );
  }

  String? validate() {
    if (url.isEmpty) return 'Pilih printer di Pengaturan.';
    for (final size in [
      (qrWidth, qrHeight, 'QR'),
      (barcodeWidth, barcodeHeight, 'Barcode'),
    ]) {
      final (width, height, label) = size;
      if (!width.isFinite ||
          !height.isFinite ||
          width < 30 ||
          width > 200 ||
          height < 25 ||
          height > 200) {
        return 'Ukuran label $label: lebar 30–200 mm, tinggi 25–200 mm.';
      }
    }
    return qrMargins.validate(qrWidth, qrHeight, 'QR') ??
        barcodeMargins.validate(barcodeWidth, barcodeHeight, 'Barcode');
  }
}

class LabelPrintService {
  LabelPrintService({
    File? configFile,
    WindowsPrinterConnectionService? connectionService,
  }) : _connectionService =
           connectionService ?? WindowsPrinterConnectionService(),
       _file =
           configFile ??
           File(
             '${StorageServices().configFile.parent.path}${Platform.pathSeparator}printer.json',
           );
  static final instance = LabelPrintService();
  final File _file;
  final WindowsPrinterConnectionService _connectionService;
  bool _printing = false;
  String? _lastSuccessfulPrinter;

  Future<LabelPrinterSettings> load() async {
    if (!await _file.exists()) return const LabelPrinterSettings();
    final data = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
    return LabelPrinterSettings(
      url: data['url'] as String? ?? '',
      name: data['name'] as String? ?? '',
      qrPrintText: data['qrPrintText'] as bool? ?? true,
      barcodePrintText: data['barcodePrintText'] as bool? ?? true,
      qrMargins: LabelMargins.fromJson(
        data['qrMargins'] as Map<String, dynamic>?,
      ),
      barcodeMargins: LabelMargins.fromJson(
        data['barcodeMargins'] as Map<String, dynamic>?,
      ),
      qrWidth:
          (data['qrWidth'] as num? ?? data['width'] as num?)?.toDouble() ?? 60,
      qrHeight:
          (data['qrHeight'] as num? ?? data['height'] as num?)?.toDouble() ??
          40,
      barcodeWidth:
          (data['barcodeWidth'] as num? ?? data['width'] as num?)?.toDouble() ??
          60,
      barcodeHeight:
          (data['barcodeHeight'] as num? ?? data['height'] as num?)
              ?.toDouble() ??
          40,
    );
  }

  Future<void> save(LabelPrinterSettings settings) async {
    final error = settings.validate();
    if (error != null) throw FormatException(error);
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      jsonEncode({
        'url': settings.url,
        'name': settings.name,
        'qrWidth': settings.qrWidth,
        'qrHeight': settings.qrHeight,
        'barcodeWidth': settings.barcodeWidth,
        'barcodeHeight': settings.barcodeHeight,
        'qrPrintText': settings.qrPrintText,
        'barcodePrintText': settings.barcodePrintText,
        'qrMargins': settings.qrMargins.toJson(),
        'barcodeMargins': settings.barcodeMargins.toJson(),
      }),
      flush: true,
    );
  }

  Future<List<Printer>> printers() => Printing.listPrinters();

  /// Read Windows printer availability without sending a print job.
  Future<PrinterConnectionStatus> printerStatus() async {
    try {
      final settings = await load();
      if (_lastSuccessfulPrinter != settings.url) _lastSuccessfulPrinter = null;
      if (settings.url.isEmpty) {
        return const PrinterConnectionStatus(
          PrinterAvailability.notConfigured,
          'Pilih printer di Pengaturan.',
        );
      }
      final available = await printers();
      for (final printer in available) {
        if (printer.url == settings.url) {
          if (!printer.isAvailable) {
            _lastSuccessfulPrinter = null;
            return const PrinterConnectionStatus(
              PrinterAvailability.offline,
              'Windows melaporkan printer offline, dijeda, atau mengalami kesalahan.',
            );
          }
          final physical = await _connectionService.check(settings.url);
          if (physical.availability == PrinterAvailability.offline) {
            _lastSuccessfulPrinter = null;
            return physical;
          }
          if (_lastSuccessfulPrinter == settings.url) {
            return const PrinterConnectionStatus(
              PrinterAvailability.submitted,
              'Pengiriman cetak terakhir diterima antrean Windows. Ini bukan konfirmasi printer masih menyala atau label sudah tercetak.',
            );
          }
          return physical;
        }
      }
      _lastSuccessfulPrinter = null;
      return const PrinterConnectionStatus(
        PrinterAvailability.offline,
        'Printer yang dipilih tidak ditemukan di Windows.',
      );
    } catch (_) {
      _lastSuccessfulPrinter = null;
      return const PrinterConnectionStatus(
        PrinterAvailability.unknown,
        'Status printer tidak dapat dibaca. Periksa printer dan layanan Print Spooler Windows.',
      );
    }
  }

  static String? validateLabel(String text, String type) {
    if (text.trim().isEmpty) return 'Masukkan teks label.';
    if (type != 'qr' && type != 'barcode') return 'Pilih QR atau barcode.';
    if (text.length > 200) return 'Teks label maksimal 200 karakter.';
    if (type == 'barcode' &&
        (text.length > 40 || !RegExp(r'^[\x20-\x7E]+$').hasMatch(text))) {
      return 'Barcode Code 128: maksimal 40 karakter ASCII (tanpa baris baru). Gunakan QR untuk teks lainnya.';
    }
    return null;
  }

  static Future<Uint8List> buildLabel(
    String text,
    String type,
    LabelPrinterSettings settings,
  ) async {
    final error = validateLabel(text, type);
    if (error != null) throw FormatException(error);
    final printText = settings.printText(type);
    final font = printText
        ? pw.Font.ttf(
            await rootBundle.load('fonts/poppins/Poppins-Regular.ttf'),
          )
        : null;
    final document = pw.Document();
    final format = settings.pageFormat(type);
    final width = format.availableWidth;
    final height = format.availableHeight;
    final codeHeight = height * 0.65;
    document.addPage(
      pw.Page(
        pageFormat: format,
        build: (_) => pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: type == 'qr'
                    ? pw.Barcode.qrCode()
                    : pw.Barcode.code128(),
                data: text,
                drawText: false,
                width: type == 'qr' ? math.min(width, codeHeight) : width,
                height: codeHeight,
              ),
            ),
            if (printText) pw.SizedBox(height: 3),
            if (printText)
              pw.Expanded(
                child: pw.Center(
                  child: pw.FittedBox(
                    child: pw.SizedBox(
                      width: width,
                      child: pw.Text(
                        text,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: font, fontSize: 10),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return document.save();
  }

  Future<bool> submitLabel(
    Printer printer,
    Uint8List bytes,
    PdfPageFormat format,
  ) async => Printing.directPrintPdf(
    printer: printer,
    onLayout: (_) async => bytes,
    name: 'WMS Label',
    format: format,
    usePrinterSettings: false,
  );

  Future<ScanResult> printLabel(String text, String type) async {
    final error = validateLabel(text, type);
    if (error != null) return ScanResult(400, error);
    if (_printing) {
      return const ScanResult(409, 'Label sebelumnya masih diproses.');
    }
    _printing = true;
    _lastSuccessfulPrinter = null;
    try {
      final settings = await load();
      final settingError = settings.validate();
      if (settingError != null) return ScanResult(503, settingError);
      final available = await printers();
      final matches = available.where((printer) => printer.url == settings.url);
      if (matches.isEmpty || !matches.first.isAvailable) {
        return const ScanResult(
          503,
          'Printer tidak tersedia. Periksa koneksi USB/jaringan dan Pengaturan.',
        );
      }
      final bytes = await buildLabel(text, type, settings);
      final accepted = await submitLabel(
        matches.first,
        bytes,
        settings.pageFormat(type),
      );
      if (accepted) _lastSuccessfulPrinter = settings.url;
      return accepted
          ? const ScanResult(200, 'Label dikirim ke antrean printer.')
          : const ScanResult(500, 'Printer tidak menerima label.');
    } catch (error) {
      return ScanResult(500, 'Gagal mencetak label: $error');
    } finally {
      _printing = false;
    }
  }
}
