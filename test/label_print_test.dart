import 'dart:convert';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_windows_listener/core/services/label_print_service.dart';
import 'package:wms_windows_listener/core/services/lan_listener_service.dart';
import 'package:wms_windows_listener/core/models/modules/listener/listener_settings.dart';
import 'package:wms_windows_listener/core/models/modules/listener/scan_result.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('old shared dimensions migrate to both formats', () async {
    final dir = await Directory.systemTemp.createTemp('label-migration-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/printer.json');
    await file.writeAsString(
      jsonEncode({'url': 'POS-58', 'width': 58, 'height': 35}),
    );
    final service = LabelPrintService(configFile: file);
    final settings = await service.load();
    expect(settings.qrWidth, 58);
    expect(settings.qrHeight, 35);
    expect(settings.barcodeWidth, 58);
    expect(settings.barcodeHeight, 35);
    expect(settings.qrPrintText, isTrue);
    expect(settings.barcodePrintText, isTrue);
    for (final type in ['qr', 'barcode']) {
      final format = settings.pageFormat(type);
      expect(
        [
          format.marginLeft,
          format.marginRight,
          format.marginTop,
          format.marginBottom,
        ],
        [0, 0, 0, 0],
      );
    }
    await service.save(settings);
    expect((await service.load()).barcodeWidth, 58);
  });

  test('each print format uses its own page dimensions', () {
    const settings = LabelPrinterSettings(
      url: 'POS-58',
      qrWidth: 50,
      qrHeight: 50,
      barcodeWidth: 80,
      barcodeHeight: 30,
    );
    expect(
      settings.pageFormat('qr').width,
      closeTo(50 * PdfPageFormat.mm, 0.001),
    );
    expect(
      settings.pageFormat('qr').height,
      closeTo(50 * PdfPageFormat.mm, 0.001),
    );
    expect(
      settings.pageFormat('barcode').width,
      closeTo(80 * PdfPageFormat.mm, 0.001),
    );
    expect(
      settings.pageFormat('barcode').height,
      closeTo(30 * PdfPageFormat.mm, 0.001),
    );
    expect(
      const LabelPrinterSettings(url: 'p', barcodeHeight: 0).validate(),
      contains('Barcode'),
    );
    expect(
      const LabelPrinterSettings(url: 'p', qrWidth: 0).validate(),
      contains('QR'),
    );
  });

  test(
    'label printer settings persist separately from listener settings',
    () async {
      final dir = await Directory.systemTemp.createTemp('label-printer-');
      addTearDown(() => dir.delete(recursive: true));
      final service = LabelPrintService(
        configFile: File('${dir.path}/printer.json'),
      );
      expect((await service.load()).qrWidth, 60);
      await service.save(
        const LabelPrinterSettings(
          url: 'usb-printer',
          name: 'Label Printer',
          qrWidth: 70,
          qrHeight: 50,
          barcodeWidth: 80,
          barcodeHeight: 30,
          qrPrintText: false,
          barcodePrintText: true,
          qrMargins: LabelMargins(left: 1, right: 2, top: 3, bottom: 4),
          barcodeMargins: LabelMargins(left: 4, right: 3, top: 2, bottom: 1),
        ),
      );
      final restored = await service.load();
      expect(restored.url, 'usb-printer');
      expect(restored.qrWidth, 70);
      expect(restored.qrHeight, 50);
      expect(restored.barcodeWidth, 80);
      expect(restored.barcodeHeight, 30);
      expect(restored.printText('qr'), isFalse);
      expect(restored.printText('barcode'), isTrue);
      expect(restored.qrMargins.toJson(), {
        'left': 1,
        'right': 2,
        'top': 3,
        'bottom': 4,
      });
      expect(restored.barcodeMargins.toJson(), {
        'left': 4,
        'right': 3,
        'top': 2,
        'bottom': 1,
      });
      expect(
        () => service.save(
          const LabelPrinterSettings(url: 'x', qrWidth: double.nan),
        ),
        throwsFormatException,
      );
    },
  );

  test('rejects empty, oversized and unsupported barcode input', () {
    expect(LabelPrintService.validateLabel(' ', 'qr'), isNotNull);
    expect(LabelPrintService.validateLabel('a' * 201, 'qr'), isNotNull);
    expect(LabelPrintService.validateLabel('hello', 'unknown'), isNotNull);
    expect(
      LabelPrintService.validateLabel('hello\nworld', 'barcode'),
      isNotNull,
    );
    expect(LabelPrintService.validateLabel('hello\nworld', 'qr'), isNull);
    expect(LabelPrintService.validateLabel('ITEM-123', 'barcode'), isNull);
  });

  test(
    'independent margins reduce printable area and reject invalid sizes',
    () async {
      const settings = LabelPrinterSettings(
        url: 'p',
        qrMargins: LabelMargins(left: 1, right: 2, top: 3, bottom: 4),
        barcodeMargins: LabelMargins(left: 5, right: 6, top: 7, bottom: 8),
      );
      final qr = settings.pageFormat('qr');
      final barcode = settings.pageFormat('barcode');
      expect(qr.availableWidth, closeTo(57 * PdfPageFormat.mm, 0.001));
      expect(qr.availableHeight, closeTo(33 * PdfPageFormat.mm, 0.001));
      expect(barcode.availableWidth, closeTo(49 * PdfPageFormat.mm, 0.001));
      expect(barcode.availableHeight, closeTo(25 * PdfPageFormat.mm, 0.001));
      expect(qr.marginLeft, closeTo(PdfPageFormat.mm, 0.001));
      expect(qr.marginTop, closeTo(3 * PdfPageFormat.mm, 0.001));
      expect(barcode.marginRight, closeTo(6 * PdfPageFormat.mm, 0.001));
      expect(barcode.marginBottom, closeTo(8 * PdfPageFormat.mm, 0.001));
      expect(
        const LabelPrinterSettings(
          url: 'p',
          qrMargins: LabelMargins(left: -1),
        ).validate(),
        contains('QR'),
      );
      expect(
        const LabelPrinterSettings(
          url: 'p',
          barcodeMargins: LabelMargins(top: double.nan),
        ).validate(),
        contains('Barcode'),
      );
      expect(
        const LabelPrinterSettings(
          url: 'p',
          qrMargins: LabelMargins(left: 30, right: 30),
        ).validate(),
        contains('area cetak'),
      );
      for (final type in ['qr', 'barcode']) {
        final bytes = await LabelPrintService.buildLabel(
          'ITEM-123',
          type,
          settings,
        );
        expect(ascii.decode(bytes.take(4).toList()), '%PDF');
      }
    },
  );

  test('text-off labels omit the caption font for either code type', () async {
    for (final type in ['qr', 'barcode']) {
      for (final withText in [true, false]) {
        final bytes = await LabelPrintService.buildLabel(
          'ITEM-123',
          type,
          LabelPrinterSettings(
            qrPrintText: withText,
            barcodePrintText: withText,
          ),
        );
        final pdf = latin1.decode(bytes);
        expect(pdf.startsWith('%PDF'), isTrue);
        expect(pdf.contains('/FontFile2'), withText);
      }
    }
  });

  test(
    'generates printable QR and Code 128 labels at supported sizes',
    () async {
      for (final type in ['qr', 'barcode']) {
        for (final dimensions in [(60.0, 40.0), (30.0, 25.0)]) {
          final bytes = await LabelPrintService.buildLabel(
            'ITEM-123',
            type,
            LabelPrinterSettings(
              qrWidth: dimensions.$1,
              qrHeight: dimensions.$2,
              barcodeWidth: dimensions.$1,
              barcodeHeight: dimensions.$2,
            ),
          );
          expect(ascii.decode(bytes.take(4).toList()), '%PDF');
        }
      }
    },
  );

  test(
    'print endpoint authenticates and validates payload without triggering scan',
    () async {
      final server = LanListenerService();
      final received = <String>[];
      server.onPrintLabel = (text, type) async {
        received.add('$type:$text');
        return const ScanResult(200, 'Queued');
      };
      await server.start(
        const ListenerSettings(folders: [], port: 0, key: 'ABCD2345'),
        (_) async {
          fail('Print must not invoke file scan');
        },
      );
      final client = HttpOverrides.runWithHttpOverrides(
        () => HttpClient(),
        _RealHttpOverrides(),
      );
      addTearDown(() async {
        client.close(force: true);
        await server.stop();
      });
      Future<int> send(
        Map<String, dynamic> payload, {
        String key = 'ABCD2345',
      }) async {
        final request = await client.postUrl(
          Uri.parse('http://127.0.0.1:${server.boundPort}/print-label'),
        );
        request.headers.set('X-Listener-Key', key);
        request.write(jsonEncode(payload));
        final response = await request.close();
        await response.drain<void>();
        return response.statusCode;
      }

      expect(await send({'text': 'first'}, key: 'wrong'), 401);
      expect(await send({'text': 123}), 400);
      expect(await send({'text': 'first'}), 200);
      expect(await send({'text': 'second', 'type': 'barcode'}), 200);
      expect(received, ['qr:first', 'barcode:second']);
    },
  );
}
