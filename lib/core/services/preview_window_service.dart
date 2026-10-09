import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';

abstract class PreviewWindowService {
  Future<void> show(String path);
  Future<void> close();
}

class DesktopPreviewWindowService implements PreviewWindowService {
  WindowController? _current;
  Future<void> _pending = Future.value();

  Future<void> _closeCurrent() async {
    final current = _current;
    _current = null;
    if (current == null) return;
    try {
      final windows = await WindowController.getAll();
      if (!windows.any((window) => window.windowId == current.windowId)) return;
      await current.invokeMethod<void>('closePreview');
    } catch (_) {
      // A window closed by the user can disappear during the request.
      try {
        await current.hide();
      } catch (_) {}
    }
  }

  Future<void> _schedule(Future<void> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then(
      (_) {},
      onError: (Object error, StackTrace trace) {},
    );
    return result;
  }

  @override
  Future<void> close() => _schedule(_closeCurrent);

  @override
  Future<void> show(String path) => _schedule(() async {
    await _closeCurrent();
    _current = await WindowController.create(
      WindowConfiguration(
        arguments: jsonEncode({'type': 'preview', 'path': path}),
      ),
    );
  });
}
