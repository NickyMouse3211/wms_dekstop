import 'dart:io';

import '../../constants/listener_constants.dart';
import '../../models/modules/listener/listener_settings.dart';
import '../../models/modules/listener/network_address.dart';
import '../../models/modules/listener/scan_history_entry.dart';
import '../../models/modules/listener/scan_result.dart';
import '../../services/file_opener_service.dart';
import '../../services/lan_listener_service.dart';
import '../../services/label_print_service.dart';
import '../../services/network_services.dart';
import '../../services/scan_history_services.dart';
import '../../services/storage_services.dart';
import '../../utils/listener_validators.dart';
import '../../utils/file_search_matcher.dart';

class ListenerRepository {
  ListenerRepository({
    StorageServices? storage,
    ScanHistoryServices? historyStorage,
    NetworkServices? network,
    FileOpenerService? opener,
    LanListenerService? server,
  }) : _storage = storage ?? StorageServices(),
       _historyStorage = historyStorage ?? ScanHistoryServices(),
       _network = network ?? NetworkServices(),
       _opener = opener ?? FileOpenerService(),
       _server = server ?? LanListenerService();

  final StorageServices _storage;
  final ScanHistoryServices _historyStorage;
  final NetworkServices _network;
  final FileOpenerService _opener;
  final LanListenerService _server;
  ListenerSettings? _settings;
  void Function(List<ScanHistoryEntry>)? _onHistoryChanged;
  final List<ScanHistoryEntry> _history = [];
  bool _processing = false;

  int? get boundPort => _server.boundPort;

  Future<ListenerSettings> loadSettings() async {
    final settings = await _storage.load();
    _settings = settings;
    return settings;
  }

  Future<void> saveSettings(ListenerSettings settings) async {
    await _storage.save(settings);
    _settings = settings;
  }

  Future<List<NetworkAddress>> networkAddresses() => _network.addresses();

  Future<List<ScanHistoryEntry>> loadHistory() async {
    _history
      ..clear()
      ..addAll(await _historyStorage.load());
    return List.unmodifiable(_history);
  }

  Future<void> start(
    ListenerSettings settings, {
    void Function(List<ScanHistoryEntry>)? onHistoryChanged,
  }) async {
    await _server.stop();
    _settings = settings;
    _onHistoryChanged = onHistoryChanged;
    _server.onPrintLabel = LabelPrintService.instance.printLabel;
    await _server.start(settings, processCode);
  }

  Future<void> stop() => _server.stop();

  Future<ScanResult> processCode(String input) async {
    // Mobile sends an empty scan to verify its access key during connection
    // polling. Reject it without replacing the latest result or open preview.
    if (ListenerValidators.trimScanValue(input).isEmpty) {
      return const ScanResult(
        400,
        'Kode QR harus berupa nama file tanpa alamat folder',
      );
    }
    if (_processing) {
      return const ScanResult(409, 'Scan sebelumnya masih diproses');
    }
    _processing = true;
    final code = (_settings?.trimScanValue ?? true)
        ? ListenerValidators.trimScanValue(input)
        : input;
    try {
      if (!ListenerValidators.isFileName(code)) {
        return await _record(
          code,
          const ScanResult(
            400,
            'Kode QR harus berupa nama file tanpa alamat folder',
          ),
        );
      }
      final settings = _settings;
      if (settings == null || settings.folders.isEmpty) {
        return await _record(
          code,
          const ScanResult(503, 'Folder dokumen tidak tersedia'),
        );
      }

      final matcher = FileSearchMatcher(
        mode: settings.fileSearchMode,
        query: code,
        operator: settings.fileSearchOperator,
      );
      final validationError = matcher.validationError;
      if (validationError != null) {
        return await _record(code, ScanResult(400, validationError));
      }
      final matches = <ScanFileMatch>[];
      var bestScore = 0;
      final seenPaths = <String>{};
      var availableFolders = 0;
      for (final folder in settings.folders) {
        final directory = Directory(folder);
        if (!await directory.exists()) continue;
        availableFolders++;
        await for (final entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File) continue;
          final path = entity.absolute.path;
          if (!seenPaths.add(path.toLowerCase())) continue;
          final name = entity.uri.pathSegments.last;
          final lowerName = name.toLowerCase();
          final dot = lowerName.lastIndexOf('.');
          if (dot < 0 ||
              !ListenerConstants.allowedExtensions.contains(
                lowerName.substring(dot),
              )) {
            continue;
          }
          final score = matcher.score(lowerName.substring(0, dot));
          if (score > 0 && score >= bestScore) {
            if (score > bestScore) matches.clear();
            bestScore = score;
            matches.add(ScanFileMatch(name: name, path: path));
          }
        }
      }

      if (availableFolders == 0) {
        return await _record(
          code,
          const ScanResult(503, 'Folder dokumen tidak tersedia'),
        );
      }
      if (matches.isEmpty) {
        return await _record(
          code,
          ScanResult(404, 'File untuk "$code" tidak ditemukan'),
        );
      }
      if (matches.length > 1) {
        return await _record(
          code,
          ScanResult(
            409,
            'Ditemukan ${matches.length} file untuk "$code". Pilih file di Windows File Scan.',
          ),
          matches: matches,
        );
      }

      final match = matches.single;
      if (!await File(match.path).exists()) {
        return await _record(
          code,
          const ScanResult(404, 'File tidak tersedia lagi'),
        );
      }
      if (!settings.openInApp) await _opener.open(match.path);
      return await _record(
        code,
        ScanResult(
          200,
          '${settings.openInApp ? 'Menampilkan' : 'Membuka'} ${match.name}',
          path: match.path,
        ),
        matches: matches,
        openedPath: match.path,
      );
    } catch (error) {
      return await _record(code, ScanResult(500, 'Gagal membuka file: $error'));
    } finally {
      _processing = false;
    }
  }

  Future<ScanResult> openMatch(String entryId, String path) async {
    if (_processing) {
      return const ScanResult(409, 'Scan sebelumnya masih diproses');
    }
    final index = _history.indexWhere((entry) => entry.id == entryId);
    if (index < 0 || !_history[index].needsSelection) {
      return const ScanResult(404, 'Hasil scan tidak tersedia');
    }
    final entry = _history[index];
    final matches = entry.matches.where((match) => match.path == path);
    if (matches.isEmpty) {
      return const ScanResult(400, 'File tidak termasuk hasil scan');
    }
    if (!await File(path).exists()) {
      return const ScanResult(404, 'File tidak tersedia lagi');
    }

    _processing = true;
    try {
      final openInApp = _settings?.openInApp ?? true;
      if (!openInApp) await _opener.open(path);
      final result = ScanResult(
        200,
        '${openInApp ? 'Menampilkan' : 'Membuka'} ${matches.first.name}',
        path: path,
      );
      _history[index] = entry.copyWith(
        status: 200,
        message: result.message,
        openedPath: path,
      );
      await _publishHistory();
      return result;
    } catch (error) {
      return ScanResult(500, 'Gagal membuka file: $error');
    } finally {
      _processing = false;
    }
  }

  Future<ScanResult> reopenHistoryEntry(String entryId) async {
    if (_processing) {
      return const ScanResult(409, 'Scan sebelumnya masih diproses');
    }
    final index = _history.indexWhere((entry) => entry.id == entryId);
    if (index < 0 ||
        _history[index].status != 200 ||
        _history[index].openedPath == null) {
      return const ScanResult(404, 'File riwayat tidak tersedia');
    }
    final path = _history[index].openedPath!;
    if (!await File(path).exists()) {
      return const ScanResult(404, 'File tidak tersedia lagi');
    }

    _processing = true;
    try {
      final openInApp = _settings?.openInApp ?? true;
      if (!openInApp) await _opener.open(path);
      final name = File(path).uri.pathSegments.last;
      return ScanResult(
        200,
        '${openInApp ? 'Menampilkan' : 'Membuka'} $name',
        path: path,
      );
    } catch (error) {
      return ScanResult(500, 'Gagal membuka file: $error');
    } finally {
      _processing = false;
    }
  }

  Future<ScanResult> _record(
    String code,
    ScanResult result, {
    List<ScanFileMatch> matches = const [],
    String? openedPath,
  }) async {
    final now = DateTime.now();
    _history.insert(
      0,
      ScanHistoryEntry(
        id: now.microsecondsSinceEpoch.toString(),
        code: code,
        scannedAt: now,
        status: result.status,
        message: result.message,
        matches: matches,
        openedPath: openedPath,
      ),
    );
    if (_history.length > 50) _history.removeLast();
    await _publishHistory();
    return result;
  }

  Future<void> _publishHistory() async {
    try {
      await _historyStorage.save(_history);
    } catch (_) {
      // Keep scan results available in the UI if local history cannot be saved.
    }
    _onHistoryChanged?.call(List.unmodifiable(_history));
  }
}
