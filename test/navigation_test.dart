import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wms_windows_listener/core/constants/wms_theme.dart';
import 'package:wms_windows_listener/core/cubit/modules/listener/listener_cubit.dart';
import 'package:wms_windows_listener/core/models/modules/listener/listener_settings.dart';
import 'package:wms_windows_listener/core/models/modules/listener/network_address.dart';
import 'package:wms_windows_listener/core/models/modules/listener/scan_history_entry.dart';
import 'package:wms_windows_listener/core/models/modules/listener/scan_result.dart';
import 'package:wms_windows_listener/core/repository/modules/listener_repository.dart';
import 'package:wms_windows_listener/core/services/preview_window_service.dart';
import 'package:wms_windows_listener/presentation/pages/listener/listener_page.dart';
import 'package:wms_windows_listener/presentation/pages/listener/widgets/file_preview_view.dart';

class PreviewRepository extends ListenerRepository {
  ListenerSettings saved = const ListenerSettings(
    folders: ['D:\\Docs'],
    port: 8765,
    key: 'test-key-123456789',
  );
  void Function(List<ScanHistoryEntry>)? onHistoryChanged;
  List<ScanHistoryEntry> history = const [];
  int starts = 0;
  int stops = 0;

  void emitHistory(List<ScanHistoryEntry> history) {
    this.history = history;
    onHistoryChanged?.call(history);
  }

  @override
  Future<ScanResult> reopenHistoryEntry(String entryId) async {
    final entry = history.firstWhere((item) => item.id == entryId);
    return ScanResult(200, 'Menampilkan ${entry.code}', path: entry.openedPath);
  }

  @override
  Future<ListenerSettings> loadSettings() async => saved;

  @override
  Future<List<NetworkAddress>> networkAddresses() async => [
    const NetworkAddress(name: 'Wi-Fi', ip: '192.168.1.20'),
  ];

  @override
  Future<List<ScanHistoryEntry>> loadHistory() async => [];

  @override
  Future<void> start(
    ListenerSettings settings, {
    void Function(List<ScanHistoryEntry>)? onHistoryChanged,
  }) async {
    starts++;
    this.onHistoryChanged = onHistoryChanged;
  }

  @override
  Future<void> saveSettings(ListenerSettings settings) async {
    saved = settings;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

class RecordingPreviewWindows implements PreviewWindowService {
  final shown = <String>[];
  int closed = 0;
  String? current;

  @override
  Future<void> show(String path) async {
    if (current != null) closed++;
    current = path;
    shown.add(path);
  }

  @override
  Future<void> close() async {
    if (current != null) closed++;
    current = null;
  }
}

void main() {
  testWidgets('dashboard service switch appears after first activation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final folder = Directory.systemTemp.createTempSync('wms-first-start-');
    final repository = PreviewRepository()
      ..saved = const ListenerSettings(
        folders: [],
        port: 8765,
        key: 'test-key-123456789',
        enabled: false,
      );
    final cubit = ListenerCubit(repository);
    addTearDown(() async {
      await cubit.close();
      folder.deleteSync(recursive: true);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: WmsTheme.light,
        home: BlocProvider.value(
          value: cubit,
          child: ListenerPage(previewWindows: RecordingPreviewWindows()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Layanan listener'), findsNothing);
    await tester.tap(find.text('Buka Pengaturan'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNWidgets(4));
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Folder dokumen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, folder.path);
    await tester.tap(find.text('Folder dokumen'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Folder dokumen'));
    await tester.pumpAndSettle();
    expect(find.text(folder.path), findsOneWidget);
    await tester.ensureVisible(find.text('Simpan dan aktifkan'));
    await tester.tap(find.text('Simpan dan aktifkan'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(cubit.state.active, isTrue);
    expect(repository.saved.activatedOnce, isTrue);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Dashboard'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Layanan listener'), findsOneWidget);
  });

  testWidgets('dashboard QR and service switch use saved connection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final folder = Directory.systemTemp.createTempSync('wms-dashboard-');
    final repository = PreviewRepository()
      ..saved = ListenerSettings(
        folders: [folder.path],
        port: 8765,
        key: 'test-key-123456789',
      );
    final cubit = ListenerCubit(repository);
    addTearDown(() async {
      await cubit.close();
      folder.deleteSync(recursive: true);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: WmsTheme.light,
        home: BlocProvider.value(
          value: cubit,
          child: ListenerPage(previewWindows: RecordingPreviewWindows()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.starts, 1);
    expect(find.text('Hubungkan mobile dengan QR'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('IP 192.168.1.20 • Port 8765'), findsOneWidget);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Layanan listener'));
    await tester.pumpAndSettle();
    expect(repository.saved.enabled, isFalse);
    expect(cubit.state.active, isFalse);
    expect(find.byType(QrImageView), findsNothing);
    expect(
      find.text('Aktifkan listener untuk menampilkan QR koneksi.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(SwitchListTile, 'Layanan listener'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(repository.saved.enabled, isTrue);
    expect(cubit.state.active, isTrue);
    expect(repository.starts, 2);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('file scan switches save choices and stay on file scan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = PreviewRepository();
    final previews = RecordingPreviewWindows();
    final cubit = ListenerCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: WmsTheme.light,
        home: BlocProvider.value(
          value: cubit,
          child: ListenerPage(previewWindows: previews),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buka di aplikasi'), findsNothing);
    expect(find.text('Full screen'), findsNothing);
    expect(find.text('Trim nilai scan'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('File Scan'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buka di aplikasi'), findsOneWidget);
    expect(find.text('Full screen'), findsOneWidget);
    expect(find.text('Trim nilai scan'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Trim nilai scan'),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.text('Trim nilai scan'));
    await tester.pumpAndSettle();
    expect(repository.saved.trimScanValue, isFalse);
    await tester.tap(find.text('Buka di aplikasi'));
    await tester.pumpAndSettle();
    expect(repository.saved.openInApp, isFalse);
    expect(find.text('Full screen'), findsNothing);
    await tester.tap(find.text('Buka di aplikasi'));
    await tester.pumpAndSettle();
    expect(find.text('Full screen'), findsOneWidget);
    await tester.tap(find.text('Full screen'));
    await tester.pumpAndSettle();
    expect(repository.saved.previewFullScreen, isFalse);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Full screen'),
          )
          .value,
      isFalse,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Pengaturan'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buka di aplikasi'), findsNothing);
    expect(find.text('Full screen'), findsNothing);
    expect(find.text('Trim nilai scan'), findsNothing);
  });

  testWidgets('new scans replace popup and duplicates show choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const filePath = 'E:\\Docs\\SPEC.docx';
    final repository = PreviewRepository();
    final previews = RecordingPreviewWindows();
    final cubit = ListenerCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: WmsTheme.light,
        home: BlocProvider.value(
          value: cubit,
          child: ListenerPage(previewWindows: previews),
        ),
      ),
    );
    await tester.pumpAndSettle();

    repository.emitHistory([
      ScanHistoryEntry(
        id: 'single',
        code: 'SPEC',
        scannedAt: DateTime.now(),
        status: 200,
        message: 'Menampilkan SPEC.docx',
        openedPath: filePath,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(previews.shown, [filePath]);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('File Scan'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full screen'));
    await tester.pumpAndSettle();
    expect(repository.saved.previewFullScreen, isFalse);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Dashboard'),
      ),
    );
    await tester.pumpAndSettle();
    const nextPath = 'E:\\Docs\\NEXT.docx';
    repository.emitHistory([
      ScanHistoryEntry(
        id: 'next',
        code: 'NEXT',
        scannedAt: DateTime.now(),
        status: 200,
        message: 'Menampilkan NEXT.docx',
        openedPath: nextPath,
      ),
      ScanHistoryEntry(
        id: 'single',
        code: 'SPEC',
        scannedAt: DateTime.now(),
        status: 200,
        message: 'Menampilkan SPEC.docx',
        openedPath: filePath,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(previews.shown, [filePath]);
    expect(previews.closed, 1);
    expect(find.text('File Scan'), findsWidgets);
    expect(find.byType(FilePreviewView), findsOneWidget);
    expect(find.text('NEXT.docx'), findsOneWidget);
    await tester.tap(find.byTooltip('Tutup pratinjau'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('history-single')));
    await tester.tap(find.byKey(const ValueKey('history-single')));
    await tester.pumpAndSettle();
    expect(find.byType(FilePreviewView), findsOneWidget);
    expect(find.text('SPEC.docx'), findsOneWidget);
    expect(previews.shown, [filePath]);

    repository.emitHistory([
      ScanHistoryEntry(
        id: 'multiple',
        code: 'SPEC',
        scannedAt: DateTime.now(),
        status: 409,
        message: 'Ditemukan 2 file',
        matches: [
          const ScanFileMatch(name: 'SPEC.docx', path: filePath),
          const ScanFileMatch(name: 'SPEC.pdf', path: 'E:\\Docs\\SPEC.pdf'),
        ],
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Pilih file yang ingin dibuka:'), findsOneWidget);
    expect(find.byType(FilePreviewView), findsNothing);
    expect(previews.closed, 1);
  });

  testWidgets('desktop and narrow navigation show saved folders', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cubit = ListenerCubit(PreviewRepository());
    final previews = RecordingPreviewWindows();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: WmsTheme.light,
        home: BlocProvider.value(
          value: cubit,
          child: ListenerPage(previewWindows: previews),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alamat IP PC'), findsOneWidget);
    expect(find.text('192.168.1.20'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('File Scan'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Baru saja di scan'), findsOneWidget);
    expect(find.text('Riwayat'), findsOneWidget);

    tester.view.physicalSize = const Size(560, 820);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Pengaturan'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Folder dokumen'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    await tester.tap(find.text('Hubungkan mobile dengan QR'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.ensureVisible(find.text('Hubungkan mobile dengan QR'));
    await tester.tap(find.text('Hubungkan mobile dengan QR'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan dan aktifkan ulang'), findsOneWidget);
    await tester.ensureVisible(find.text('Matikan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matikan'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan dan aktifkan'), findsOneWidget);
    expect(find.text('Matikan'), findsNothing);
    await tester.ensureVisible(find.text('Folder dokumen'));
    await tester.tap(find.text('Folder dokumen'));
    await tester.pumpAndSettle();
    expect(find.text('D:\\Docs'), findsOneWidget);
    await tester.ensureVisible(find.text('Tambah folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah folder'));
    await tester.pumpAndSettle();
    expect(find.text('Folder 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
