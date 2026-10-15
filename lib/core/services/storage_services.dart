import 'dart:convert';
import 'dart:io';

import '../constants/listener_constants.dart';
import '../models/modules/listener/listener_settings.dart';
import 'access_key_service.dart';

class StorageServices {
  File get configFile {
    final base = Platform.environment['APPDATA'] ?? Directory.current.path;
    return File(
      '$base${Platform.pathSeparator}WmsWindowsListener${Platform.pathSeparator}config.json',
    );
  }

  Future<ListenerSettings> load() async {
    final file = configFile;
    if (!await file.exists()) {
      final settings = ListenerSettings(
        folders: const [],
        port: ListenerConstants.defaultPort,
        key: AccessKeyService.generate(),
        enabled: false,
      );
      await save(settings);
      return settings;
    }
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final storedFolders = data['folders'];
    final folders = storedFolders is List
        ? storedFolders.whereType<String>().toList()
        : <String>[
            if (data['folder'] is String &&
                (data['folder'] as String).isNotEmpty)
              data['folder'] as String,
          ];
    return ListenerSettings(
      folders: folders,
      port: data['port'] as int? ?? ListenerConstants.defaultPort,
      key: data['key'] as String? ?? AccessKeyService.generate(),
      enabled: data['enabled'] as bool? ?? folders.isNotEmpty,
      activatedOnce: data['activatedOnce'] as bool? ?? folders.isNotEmpty,
      openInApp: data['openInApp'] as bool? ?? true,
      previewFullScreen: data['previewFullScreen'] as bool? ?? true,
      trimScanValue: data['trimScanValue'] as bool? ?? true,
      fileSearchMode: FileSearchMode.fromStored(data['fileSearchMode']),
      fileSearchOperator: data['fileSearchOperator'] as String? ?? '-',
    );
  }

  Future<void> save(ListenerSettings settings) async {
    final file = configFile;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'folders': settings.folders,
        'port': settings.port,
        'key': settings.key,
        'enabled': settings.enabled,
        'activatedOnce': settings.activatedOnce,
        'openInApp': settings.openInApp,
        'previewFullScreen': settings.previewFullScreen,
        'trimScanValue': settings.trimScanValue,
        'fileSearchMode': settings.fileSearchMode.name,
        'fileSearchOperator': settings.fileSearchOperator,
      }),
    );
  }
}
