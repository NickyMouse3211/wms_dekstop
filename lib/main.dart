import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:window_manager/window_manager.dart';

import 'core/constants/wms_theme.dart';
import 'core/cubit/modules/listener/listener_cubit.dart';
import 'core/repository/modules/listener_repository.dart';
import 'presentation/pages/listener/listener_page.dart';
import 'presentation/pages/preview/preview_window_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Pdfrx.pdfiumModulePath = File(
    '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}pdfium.dll',
  ).path;
  final currentWindow = await WindowController.fromCurrentEngine();
  Map<String, dynamic>? arguments;
  try {
    arguments = jsonDecode(currentWindow.arguments) as Map<String, dynamic>;
  } catch (_) {}
  final previewPath = arguments != null && arguments['type'] == 'preview'
      ? arguments['path'] as String?
      : null;
  if (previewPath != null && previewPath.isNotEmpty) {
    await windowManager.ensureInitialized();
    await currentWindow.setWindowMethodHandler((call) async {
      if (call.method == 'closePreview') {
        scheduleMicrotask(() => windowManager.close());
        return true;
      }
      throw MissingPluginException('Unknown preview command: ${call.method}');
    });
    final fileName = File(previewPath).uri.pathSegments.last;
    unawaited(
      windowManager.waitUntilReadyToShow(
        WindowOptions(
          size: const Size(1100, 750),
          center: true,
          skipTaskbar: false,
          title: 'WMS Preview - $fileName',
        ),
        () async {
          await windowManager.maximize();
          await windowManager.show();
          await windowManager.focus();
        },
      ),
    );
    runApp(PreviewWindowApp(path: previewPath));
    return;
  }
  runApp(const ListenerApp());
}

class ListenerApp extends StatelessWidget {
  const ListenerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'WMS Windows Listener',
    debugShowCheckedModeBanner: false,
    theme: WmsTheme.light,
    home: BlocProvider(
      create: (_) => ListenerCubit(ListenerRepository()),
      child: const ListenerPage(),
    ),
  );
}
