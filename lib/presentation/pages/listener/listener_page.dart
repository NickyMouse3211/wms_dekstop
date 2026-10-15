import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/listener_constants.dart';
import '../../../core/constants/wms_theme.dart';
import '../../../core/cubit/modules/listener/listener_cubit.dart';
import '../../../core/cubit/modules/listener/listener_state.dart';
import '../../../core/services/preview_window_service.dart';
import '../../../core/services/file_opener_service.dart';
import 'widgets/dashboard_view.dart';
import 'widgets/file_preview_view.dart';
import 'widgets/listener_navigation.dart';
import 'widgets/settings_view.dart';
import 'widgets/file_scan_view.dart';
import 'widgets/print_label_view.dart';
import 'widgets/printer_status_badge.dart';

class ListenerPage extends StatefulWidget {
  const ListenerPage({super.key, this.previewWindows});

  final PreviewWindowService? previewWindows;

  @override
  State<ListenerPage> createState() => _ListenerPageState();
}

class _ListenerPageState extends State<ListenerPage> {
  final folders = <TextEditingController>[];
  final port = TextEditingController(
    text: ListenerConstants.defaultPort.toString(),
  );
  final key = TextEditingController();
  final testCode = TextEditingController();
  late final PreviewWindowService previewWindows =
      widget.previewWindows ?? DesktopPreviewWindowService();
  bool populated = false;
  bool historyReady = false;
  int selectedIndex = 0;
  String? lastHandledHistoryId;
  String? inlinePreviewPath;

  static const titles = ['Dashboard', 'File Scan', 'Pengaturan', 'Print label'];
  static const subtitles = [
    'Pantau koneksi PC dan hasil scan terbaru.',
    'Pantau scan file dari mobile dan pilih hasil yang cocok.',
    'Atur folder dokumen dan koneksi lokal.',
    'Cetak label dari PC atau kirim teks dari mobile.',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ListenerCubit>().initialize();
    });
  }

  void showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void addFolder() {
    setState(() => folders.add(TextEditingController()));
  }

  void removeFolder(int index) {
    final removed = folders[index];
    setState(() => folders.removeAt(index));
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  Future<void> saveSettings() async {
    final error = await context.read<ListenerCubit>().saveSettings(
      folders: folders.map((controller) => controller.text).toList(),
      port: port.text,
      key: key.text,
    );
    showMessage(error ?? 'Pengaturan disimpan dan listener aktif.');
  }

  Future<void> stopListener() async {
    final error = await context.read<ListenerCubit>().stopListener();
    showMessage(error ?? 'Listener dimatikan.');
  }

  Future<void> toggleService(bool value) async {
    final cubit = context.read<ListenerCubit>();
    final error = value
        ? await cubit.startListener()
        : await cubit.stopListener();
    if (error != null) {
      showMessage(error);
    } else {
      showMessage(value ? 'Listener aktif.' : 'Listener dimatikan.');
    }
  }

  Future<void> tryCode() async {
    final result = await context.read<ListenerCubit>().tryCode(testCode.text);
    showMessage(result.message);
  }

  Future<void> openMatch(String entryId, String path) async {
    final cubit = context.read<ListenerCubit>();
    final result = await cubit.openMatch(entryId, path);
    if (result.ok &&
        result.path != null &&
        (cubit.state.settings?.openInApp ?? true)) {
      await showPreview(result.path!);
    }
    showMessage(result.message);
  }

  Future<void> reopenHistory(String entryId) async {
    final cubit = context.read<ListenerCubit>();
    final result = await cubit.reopenHistoryEntry(entryId);
    if (!mounted) return;
    if (result.ok &&
        result.path != null &&
        (cubit.state.settings?.openInApp ?? true)) {
      await showPreview(result.path!);
    }
    showMessage(result.message);
  }

  Future<void> showPreview(String path) async {
    try {
      final fullScreen =
          context.read<ListenerCubit>().state.settings?.previewFullScreen ??
          true;
      if (fullScreen) {
        if (mounted) setState(() => inlinePreviewPath = null);
        await previewWindows.show(path);
      } else {
        await previewWindows.close();
        if (mounted) {
          setState(() {
            inlinePreviewPath = path;
            selectedIndex = 1;
          });
        }
      }
    } catch (error) {
      showMessage('Gagal membuka pratinjau: $error');
    }
  }

  Future<void> closePreview() async {
    if (mounted && inlinePreviewPath != null) {
      setState(() => inlinePreviewPath = null);
    }
    try {
      await previewWindows.close();
    } catch (error) {
      showMessage('Gagal menutup pratinjau: $error');
    }
  }

  Future<void> openPreviewExternal(String path) async {
    try {
      await FileOpenerService().open(path);
    } catch (error) {
      showMessage('Gagal membuka file: $error');
    }
  }

  Future<void> toggleOpenInApp(bool value) async {
    final error = await context.read<ListenerCubit>().setOpenInApp(value);
    if (error != null) {
      showMessage(error);
    } else if (!value) {
      await closePreview();
    }
  }

  Future<void> togglePreviewFullScreen(bool value) async {
    final error = await context.read<ListenerCubit>().setPreviewFullScreen(
      value,
    );
    if (error != null) showMessage(error);
  }

  Future<void> toggleTrimScanValue(bool value) async {
    final error = await context.read<ListenerCubit>().setTrimScanValue(value);
    if (error != null) showMessage(error);
  }

  Widget content(ListenerState state) => switch (selectedIndex) {
    0 => DashboardView(
      state: state,
      onTest: () => setState(() => selectedIndex = 1),
      onSettings: () => setState(() => selectedIndex = 2),
      onServiceChanged: toggleService,
    ),
    1 => FileScanView(
      state: state,
      codeController: testCode,
      onRun: tryCode,
      onOpenMatch: openMatch,
      onReopenHistory: reopenHistory,
      onOpenInAppChanged: toggleOpenInApp,
      onPreviewFullScreenChanged: togglePreviewFullScreen,
      onTrimScanValueChanged: toggleTrimScanValue,
      onFileSearchOperatorChanged: context
          .read<ListenerCubit>()
          .setFileSearchOperator,
      onFileSearchModeChanged: (value) async {
        final error = await context.read<ListenerCubit>().setFileSearchMode(
          value,
        );
        if (error != null && mounted) showMessage(error);
      },
    ),
    3 => const PrintLabelView(),
    _ => SettingsView(
      state: state,
      folderControllers: folders,
      portController: port,
      keyController: key,
      onAddFolder: addFolder,
      onRemoveFolder: removeFolder,
      onSave: saveSettings,
      onStop: stopListener,
    ),
  };

  @override
  void dispose() {
    for (final controller in folders) {
      controller.dispose();
    }
    port.dispose();
    key.dispose();
    testCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 800;
    return Scaffold(
      body: BlocConsumer<ListenerCubit, ListenerState>(
        listener: (_, state) {
          if (!populated && state.settings != null) {
            folders.addAll(
              state.settings!.folders.map(
                (path) => TextEditingController(text: path),
              ),
            );
            if (folders.isEmpty) folders.add(TextEditingController());
            port.text = state.settings!.port.toString();
            key.text = state.settings!.key;
            populated = true;
          }
          if (!historyReady && state.settings != null) {
            historyReady = true;
            lastHandledHistoryId = state.history.isEmpty
                ? null
                : state.history.first.id;
          } else if (historyReady && state.history.isNotEmpty) {
            final latest = state.history.first;
            if (latest.id != lastHandledHistoryId) {
              lastHandledHistoryId = latest.id;
              if (latest.needsSelection) {
                unawaited(closePreview());
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => selectedIndex = 1);
                });
              } else if (latest.openedPath != null &&
                  (state.settings?.openInApp ?? true)) {
                unawaited(showPreview(latest.openedPath!));
              } else {
                unawaited(closePreview());
              }
            }
          }
        },
        builder: (context, state) => Row(
          children: [
            if (desktop)
              ListenerNavigation(
                selectedIndex: selectedIndex,
                extended: width >= 1120,
                onSelected: (index) => setState(() => selectedIndex = index),
              ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    color: WmsColors.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 18,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titles[selectedIndex],
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitles[selectedIndex],
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                ListenerConstants.appVersionLabel,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (desktop) ...[
                          const SizedBox(width: 12),
                          const PrinterStatusBadge(),
                        ],
                        if (desktop) const SizedBox(width: 12),
                        if (desktop)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: state.active
                                  ? const Color(0xFFE9F6EB)
                                  : WmsColors.primaryLight,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 9,
                                  color: state.active
                                      ? WmsColors.success
                                      : WmsColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  state.active
                                      ? 'LISTENER AKTIF'
                                      : 'BELUM AKTIF',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: state.active
                                        ? WmsColors.success
                                        : WmsColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: WmsColors.border),
                  Expanded(
                    child: inlinePreviewPath != null && selectedIndex == 1
                        ? Padding(
                            padding: const EdgeInsets.all(18),
                            child: FilePreviewView(
                              path: inlinePreviewPath!,
                              onBack: () =>
                                  setState(() => inlinePreviewPath = null),
                              onOpenExternal: () =>
                                  openPreviewExternal(inlinePreviewPath!),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(28),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1120,
                                ),
                                child: content(state),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: desktop
          ? null
          : BottomNavigationBar(
              backgroundColor: WmsColors.textPrimary,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: WmsColors.primary,
              unselectedItemColor: Colors.white70,
              currentIndex: selectedIndex,
              onTap: (index) => setState(() => selectedIndex = index),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_rounded),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.qr_code_scanner_rounded),
                  label: 'File Scan',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_rounded),
                  label: 'Pengaturan',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.print_outlined),
                  label: 'Print label',
                ),
              ],
            ),
    );
  }
}
