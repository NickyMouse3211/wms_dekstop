import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/constants/wms_theme.dart';
import '../../../core/services/file_opener_service.dart';
import '../listener/widgets/file_preview_view.dart';

class PreviewWindowApp extends StatefulWidget {
  const PreviewWindowApp({super.key, required this.path});

  final String path;

  @override
  State<PreviewWindowApp> createState() => _PreviewWindowAppState();
}

class _PreviewWindowAppState extends State<PreviewWindowApp> {
  Future<void> _openExternal() async {
    try {
      await FileOpenerService().open(widget.path);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membuka file: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pratinjau file',
    debugShowCheckedModeBanner: false,
    theme: WmsTheme.light,
    home: Scaffold(
      backgroundColor: WmsColors.surface,
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: FilePreviewView(
          path: widget.path,
          onBack: () => windowManager.close(),
          onOpenExternal: _openExternal,
        ),
      ),
    ),
  );
}
