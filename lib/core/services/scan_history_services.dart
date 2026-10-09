import 'dart:convert';
import 'dart:io';

import '../models/modules/listener/scan_history_entry.dart';

class ScanHistoryServices {
  File get historyFile {
    final base = Platform.environment['APPDATA'] ?? Directory.current.path;
    return File(
      '$base${Platform.pathSeparator}WmsWindowsListener${Platform.pathSeparator}history.json',
    );
  }

  Future<List<ScanHistoryEntry>> load() async {
    final file = historyFile;
    if (!await file.exists()) return [];
    try {
      final data = jsonDecode(await file.readAsString()) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map(ScanHistoryEntry.fromJson)
          .take(50)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<ScanHistoryEntry> entries) async {
    final file = historyFile;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(entries.take(50).map((entry) => entry.toJson()).toList()),
    );
  }
}
