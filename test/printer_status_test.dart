import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:wms_windows_listener/core/constants/wms_theme.dart';
import 'package:wms_windows_listener/core/cubit/modules/listener/printer_status_cubit.dart';
import 'package:wms_windows_listener/core/models/modules/listener/printer_connection_status.dart';
import 'package:wms_windows_listener/core/services/label_print_service.dart';
import 'package:wms_windows_listener/core/services/windows_printer_connection_service.dart';
import 'package:wms_windows_listener/presentation/pages/listener/widgets/printer_status_badge.dart';

class FakeConnectionService extends WindowsPrinterConnectionService {
  PrinterConnectionStatus status = const PrinterConnectionStatus(
    PrinterAvailability.ready,
    'confirmed',
  );
  @override
  Future<PrinterConnectionStatus> check(String printerName) async => status;
}

class FakePrinterService extends LabelPrintService {
  FakePrinterService({WindowsPrinterConnectionService? probe})
    : super(connectionService: probe ?? FakeConnectionService());
  LabelPrinterSettings settings = const LabelPrinterSettings();
  List<Printer> devices = [];
  bool fail = false;
  bool acceptSubmission = true;
  @override
  Future<bool> submitLabel(
    Printer printer,
    Uint8List bytes,
    PdfPageFormat format,
  ) async => acceptSubmission;
  int checks = 0;
  @override
  Future<LabelPrinterSettings> load() async => settings;
  @override
  Future<List<Printer>> printers() async {
    checks++;
    if (fail) throw StateError('spooler unavailable');
    return devices;
  }
}

class PendingStatusService extends LabelPrintService {
  final pending = Completer<PrinterConnectionStatus>();
  int checks = 0;
  @override
  Future<PrinterConnectionStatus> printerStatus() {
    checks++;
    return pending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'successful submission survives unknown status but clears on disconnect or failed print',
    () async {
      final probe = FakeConnectionService()
        ..status = const PrinterConnectionStatus(
          PrinterAvailability.unknown,
          'unconfirmed',
        );
      final service = FakePrinterService(probe: probe)
        ..settings = const LabelPrinterSettings(url: 'label')
        ..devices = [const Printer(url: 'label', isAvailable: true)];
      expect((await service.printLabel('TEST', 'qr')).status, 200);
      expect(
        (await service.printerStatus()).availability,
        PrinterAvailability.submitted,
      );
      probe.status = const PrinterConnectionStatus(
        PrinterAvailability.offline,
        'off',
      );
      expect(
        (await service.printerStatus()).availability,
        PrinterAvailability.offline,
      );
      probe.status = const PrinterConnectionStatus(
        PrinterAvailability.unknown,
        'unconfirmed',
      );
      expect(
        (await service.printerStatus()).availability,
        PrinterAvailability.unknown,
      );
      await service.printLabel('TEST', 'qr');
      service.acceptSubmission = false;
      expect((await service.printLabel('TEST', 'qr')).status, 500);
      expect(
        (await service.printerStatus()).availability,
        PrinterAvailability.unknown,
      );
      service.acceptSubmission = true;
      await service.printLabel('TEST', 'qr');
      service.settings = const LabelPrinterSettings(url: 'other');
      service.devices = [const Printer(url: 'other', isAvailable: true)];
      expect(
        (await service.printerStatus()).availability,
        PrinterAvailability.unknown,
      );
    },
  );

  test('normal queue does not override unknown physical status', () async {
    final probe = FakeConnectionService()
      ..status = const PrinterConnectionStatus(
        PrinterAvailability.unknown,
        'unconfirmed',
      );
    final service = FakePrinterService(probe: probe)
      ..settings = const LabelPrinterSettings(url: 'label')
      ..devices = [const Printer(url: 'label', isAvailable: true)];
    expect((await service.printerStatus()).ready, isFalse);
    probe.status = const PrinterConnectionStatus(
      PrinterAvailability.offline,
      'unplugged',
    );
    expect(
      (await service.printerStatus()).availability,
      PrinterAvailability.offline,
    );
  });

  test('USB placeholder and unsupported observations never become ready', () {
    for (final value in ['placeholder', 'unknown', 'offline', null]) {
      expect(
        WindowsPrinterConnectionService.fromObservation({'state': value}).ready,
        isFalse,
      );
    }
    expect(
      WindowsPrinterConnectionService.fromObservation({
        'state': 'connected',
      }).ready,
      isTrue,
    );
  });
  test(
    'selected printer status uses availability, not merely installed presence',
    () async {
      final service = FakePrinterService();
      expect(
        (await service.printerStatus()).availability,
        PrinterAvailability.notConfigured,
      );
      expect(service.checks, 0);
      service.settings = const LabelPrinterSettings(url: 'label');
      service.devices = [const Printer(url: 'another', isAvailable: true)];
      expect(
        (await service.printerStatus()).availability,
        PrinterAvailability.offline,
      );
      service.devices = [const Printer(url: 'label', isAvailable: false)];
      expect((await service.printerStatus()).ready, isFalse);
      service.devices = [const Printer(url: 'label', isAvailable: true)];
      expect((await service.printerStatus()).ready, isTrue);
      service.fail = true;
      expect(
        (await service.printerStatus()).availability,
        PrinterAvailability.unknown,
      );
    },
  );

  testWidgets('header badge refreshes from online to offline', (tester) async {
    final service = FakePrinterService()
      ..settings = const LabelPrinterSettings(url: 'label')
      ..devices = [const Printer(url: 'label', isAvailable: true)];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PrinterStatusBadge(service: service)),
      ),
    );
    await tester.pump();
    expect(find.text('PRINTER SIAP'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.print_outlined)).color,
      WmsColors.success,
    );
    service.devices = [const Printer(url: 'label', isAvailable: false)];
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('PRINTER OFFLINE'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.print_outlined)).color,
      WmsColors.textLight,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'status queries do not overlap and ignore completion after close',
    (tester) async {
      final service = PendingStatusService();
      final cubit = PrinterStatusCubit(service: service)..start();
      await tester.pump(const Duration(seconds: 20));
      expect(service.checks, 1);
      await cubit.close();
      service.pending.complete(
        const PrinterConnectionStatus(PrinterAvailability.ready, 'online'),
      );
      await tester.pump();
      expect(cubit.state.availability, PrinterAvailability.checking);
    },
  );
}
