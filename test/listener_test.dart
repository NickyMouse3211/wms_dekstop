import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wms_windows_listener/core/cubit/modules/listener/listener_cubit.dart';
import 'package:wms_windows_listener/core/models/modules/listener/network_address.dart';
import 'package:wms_windows_listener/core/models/modules/listener/scan_history_entry.dart';
import 'package:wms_windows_listener/core/models/modules/listener/listener_settings.dart';
import 'package:wms_windows_listener/core/repository/modules/listener_repository.dart';
import 'package:wms_windows_listener/core/services/file_opener_service.dart';
import 'package:wms_windows_listener/core/services/storage_services.dart';
import 'package:wms_windows_listener/core/services/scan_history_services.dart';
import 'package:wms_windows_listener/core/utils/listener_validators.dart';
import 'package:wms_windows_listener/core/utils/listener_pairing_codec.dart';

class RecordingRepository extends ListenerRepository {
  RecordingRepository(this.saved);

  ListenerSettings saved;
  int starts = 0;
  int stops = 0;

  @override
  Future<ListenerSettings> loadSettings() async => saved;

  @override
  Future<void> saveSettings(ListenerSettings settings) async {
    saved = settings;
  }

  @override
  Future<List<NetworkAddress>> networkAddresses() async => [];

  @override
  Future<List<ScanHistoryEntry>> loadHistory() async => [];

  @override
  Future<void> start(
    ListenerSettings settings, {
    void Function(List<ScanHistoryEntry>)? onHistoryChanged,
  }) async {
    starts++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

class FailingStartRepository extends RecordingRepository {
  FailingStartRepository(super.saved);

  @override
  Future<void> start(
    ListenerSettings settings, {
    void Function(List<ScanHistoryEntry>)? onHistoryChanged,
  }) async {
    throw StateError('Port sudah digunakan');
  }
}

class RecordingOpener extends FileOpenerService {
  final opened = <String>[];

  @override
  Future<void> open(String path) async => opened.add(path);
}

class TestHistory extends ScanHistoryServices {
  TestHistory(this.file);

  final File file;

  @override
  File get historyFile => file;
}

class TestStorage extends StorageServices {
  TestStorage(this.file);

  final File file;

  @override
  File get configFile => file;
}

void main() {
  test(
    'search modes select files without extensions and suffix stops at the best match',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'wms-search-modes-',
      );
      final storage = TestStorage(File('${temporary.path}/config.json'));
      final repository = ListenerRepository(
        storage: storage,
        historyStorage: TestHistory(File('${temporary.path}/history.json')),
      );
      final settings = ListenerSettings(
        folders: [temporary.path],
        port: 0,
        key: 'test-key-12345678',
      );
      try {
        for (final name in [
          '3211-1305.pdf',
          '3211.1305.pdf',
          '32111305.pdf',
          '3211-234241.pdf',
          '32110-234241.pdf',
          '13211-234241.pdf',
          '321-15345.pdf',
          '32 11543563.pdf',
          '321113.pdf',
          '32111305.png',
          '3211130599.exe',
        ]) {
          await File('${temporary.path}/$name').writeAsString('sample');
        }
        Future<Set<String>> search(
          FileSearchMode mode,
          String query, {
          String operator = '-',
        }) async {
          await repository.saveSettings(
            settings.copyWith(
              fileSearchMode: mode,
              fileSearchOperator: operator,
            ),
          );
          await repository.processCode(query);
          return (await repository.loadHistory()).first.matches
              .map((match) => match.name)
              .toSet();
        }

        expect(await search(FileSearchMode.startsWith, '3211'), {
          '3211-1305.pdf',
          '3211-234241.pdf',
        });
        expect(await search(FileSearchMode.startsWith, '3211', operator: '.'), {
          '3211.1305.pdf',
        });
        expect(await search(FileSearchMode.normalizedExact, '32111305'), {
          '3211-1305.pdf',
          '3211.1305.pdf',
          '32111305.pdf',
          '32111305.png',
        });
        expect(
          await search(FileSearchMode.normalizedStart, '3211'),
          containsAll(['321-15345.pdf', '32 11543563.pdf', '3211-234241.pdf']),
        );
        expect(await search(FileSearchMode.trimSuffix, '3211130599'), {
          '32111305.pdf',
          '32111305.png',
        });
        expect((await repository.loadHistory()).first.needsSelection, isTrue);
        await File('${temporary.path}/3211130599.pdf').writeAsString('exact');
        expect(await search(FileSearchMode.trimSuffix, '3211130599'), {
          '3211130599.pdf',
        });
        expect(await search(FileSearchMode.trimSuffix, '999'), isEmpty);
        await search(FileSearchMode.normalizedStart, '---');
        expect((await repository.loadHistory()).first.status, 400);
        await search(FileSearchMode.startsWith, '3211', operator: '');
        expect((await repository.loadHistory()).first.status, 400);
      } finally {
        await repository.stop();
        await temporary.delete(recursive: true);
      }
    },
  );

  test(
    'operator typing is serialized and settings save retains search choices',
    () async {
      final repository = RecordingRepository(
        const ListenerSettings(
          folders: [],
          port: 8765,
          key: 'test-key-12345678',
          enabled: false,
        ),
      );
      final cubit = ListenerCubit(repository);
      try {
        await cubit.initialize();
        expect(
          await cubit.setFileSearchMode(FileSearchMode.startsWith),
          isNull,
        );
        expect(
          await Future.wait([
            cubit.setFileSearchOperator(''),
            cubit.setFileSearchOperator('-'),
            cubit.setFileSearchOperator('--'),
          ]),
          everyElement(isNull),
        );
        expect(repository.saved.fileSearchOperator, '--');
        expect(cubit.state.busy, isFalse);
        expect(
          await cubit.saveSettings(
            folders: [],
            port: '8766',
            key: 'test-key-12345678',
          ),
          isNull,
        );
        expect(repository.saved.fileSearchMode, FileSearchMode.startsWith);
        expect(repository.saved.fileSearchOperator, '--');
      } finally {
        await cubit.close();
      }
    },
  );

  test(
    'settings survive restart and migrate the original single folder',
    () async {
      final temporary = await Directory.systemTemp.createTemp('wms-settings-');
      final storage = TestStorage(
        File('${temporary.path}${Platform.pathSeparator}config.json'),
      );
      try {
        final initial = await storage.load();
        expect(initial.folders, isEmpty);
        expect(initial.enabled, isFalse);
        expect(initial.activatedOnce, isFalse);
        expect(initial.openInApp, isTrue);
        expect(initial.previewFullScreen, isTrue);
        expect(initial.trimScanValue, isTrue);
        expect(initial.fileSearchMode, FileSearchMode.exact);
        expect(initial.key.length, 8);
        expect(RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(initial.key), isTrue);
        expect(
          await ListenerValidators.validateSettings(
            folders: [temporary.path],
            port: '8765',
            key: initial.key,
          ),
          isNull,
        );
        expect((await storage.load()).key, initial.key);

        final saved = ListenerSettings(
          folders: ['C:\\Documents', 'D:\\Archive'],
          port: 9876,
          key: 'another-test-key-123456',
        );
        await storage.save(saved);
        final reloaded = await TestStorage(storage.file).load();
        expect(reloaded.folders, saved.folders);
        expect(reloaded.port, saved.port);
        expect(reloaded.key, saved.key);
        final pairing =
            jsonDecode(
                  ListenerPairingCodec.encode(
                    ip: '192.168.1.20',
                    settings: saved,
                  ),
                )
                as Map<String, dynamic>;
        expect(pairing['type'], 'wms_windows_listener');
        expect(pairing['version'], 1);
        expect(pairing['ip'], '192.168.1.20');
        expect(pairing['port'], 9876);
        expect(pairing['key'], saved.key);
        expect(reloaded.enabled, isTrue);
        expect(reloaded.activatedOnce, isFalse);
        await storage.save(
          saved.copyWith(
            enabled: false,
            openInApp: false,
            previewFullScreen: false,
            trimScanValue: false,
          ),
        );
        expect((await storage.load()).enabled, isFalse);
        expect((await storage.load()).openInApp, isFalse);
        expect((await storage.load()).previewFullScreen, isFalse);
        expect((await storage.load()).trimScanValue, isFalse);

        await storage.file.writeAsString(
          jsonEncode({
            'folder': 'E:\\Legacy',
            'port': 8765,
            'key': 'legacy-test-key-123456',
          }),
        );
        final migrated = await storage.load();
        expect(migrated.folders, ['E:\\Legacy']);
        expect(migrated.key, 'legacy-test-key-123456');
        expect(migrated.enabled, isTrue);
        expect(migrated.activatedOnce, isTrue);
        expect(migrated.openInApp, isTrue);
        expect(migrated.previewFullScreen, isTrue);
        expect(migrated.trimScanValue, isTrue);
        expect(migrated.fileSearchMode, FileSearchMode.exact);
        expect(migrated.fileSearchOperator, '-');
        for (final mode in FileSearchMode.values) {
          await storage.save(
            migrated.copyWith(fileSearchMode: mode, fileSearchOperator: '--'),
          );
          expect((await TestStorage(storage.file).load()).fileSearchMode, mode);
          expect(
            (await TestStorage(storage.file).load()).fileSearchOperator,
            '--',
          );
        }
        final unknownMode =
            jsonDecode(await storage.file.readAsString())
                as Map<String, dynamic>;
        unknownMode['fileSearchMode'] = 'unknown';
        await storage.file.writeAsString(jsonEncode(unknownMode));
        expect((await storage.load()).fileSearchMode, FileSearchMode.exact);
        await storage.file.writeAsString(
          jsonEncode({
            'folders': ['E:\\Legacy'],
            'port': 8765,
            'key': 'legacy-test-key-123456',
            'enabled': false,
          }),
        );
        final previouslyStopped = await storage.load();
        expect(previouslyStopped.enabled, isFalse);
        expect(previouslyStopped.activatedOnce, isTrue);
      } finally {
        await temporary.delete(recursive: true);
      }
    },
  );

  test('Matikan persists and prevents automatic startup', () async {
    final folder = await Directory.systemTemp.createTemp('wms-toggle-test-');
    final repository = RecordingRepository(
      ListenerSettings(
        folders: [folder.path],
        port: 8765,
        key: 'test-key-123456789',
      ),
    );
    final cubit = ListenerCubit(repository);
    try {
      await cubit.initialize();
      expect(cubit.state.active, isTrue);
      expect(cubit.state.settings?.activatedOnce, isTrue);
      expect(repository.saved.activatedOnce, isTrue);
      expect(repository.starts, 1);

      expect(await cubit.stopListener(), isNull);
      expect(cubit.state.active, isFalse);
      expect(repository.saved.enabled, isFalse);
      expect(repository.saved.activatedOnce, isTrue);
      expect(repository.stops, 1);

      final restarted = ListenerCubit(repository);
      try {
        await restarted.initialize();
        expect(restarted.state.active, isFalse);
        expect(restarted.state.settings?.activatedOnce, isTrue);
        expect(repository.starts, 1);
        expect(await restarted.startListener(), isNull);
        expect(restarted.state.active, isTrue);
        expect(repository.saved.enabled, isTrue);
        expect(repository.starts, 2);
      } finally {
        await restarted.close();
      }
    } finally {
      await cubit.close();
      await folder.delete(recursive: true);
    }
  });

  test('failed first start does not reveal the Dashboard switch', () async {
    final folder = await Directory.systemTemp.createTemp('wms-failed-start-');
    final repository = FailingStartRepository(
      const ListenerSettings(
        folders: [],
        port: 8765,
        key: 'test-key-123456789',
        enabled: false,
      ),
    );
    final cubit = ListenerCubit(repository);
    try {
      await cubit.initialize();
      expect(
        await cubit.saveSettings(
          folders: [folder.path],
          port: '8765',
          key: 'test-key-123456789',
        ),
        contains('Port sudah digunakan'),
      );
      expect(cubit.state.active, isFalse);
      expect(cubit.state.settings?.activatedOnce, isFalse);
      expect(repository.saved.activatedOnce, isFalse);
    } finally {
      await cubit.close();
      await folder.delete(recursive: true);
    }
  });

  test(
    'external mode opens only selected files and can switch back to preview',
    () async {
      final temporary = await Directory.systemTemp.createTemp('wms-open-mode-');
      final first = await Directory(
        '${temporary.path}${Platform.pathSeparator}a',
      ).create();
      final second = await Directory(
        '${temporary.path}${Platform.pathSeparator}b',
      ).create();
      await File(
        '${first.path}${Platform.pathSeparator}SPEC.pdf',
      ).writeAsString('sample');
      final opener = RecordingOpener();
      final storage = TestStorage(
        File('${temporary.path}${Platform.pathSeparator}config.json'),
      );
      final repository = ListenerRepository(
        storage: storage,
        opener: opener,
        historyStorage: TestHistory(
          File('${temporary.path}${Platform.pathSeparator}history.json'),
        ),
      );
      final settings = ListenerSettings(
        folders: [first.path, second.path],
        port: 0,
        key: 'test-key-123456789',
        openInApp: false,
      );
      try {
        await repository.start(settings);
        expect((await repository.processCode('SPEC')).status, 200);
        expect(opener.opened, hasLength(1));
        expect(
          (await repository.loadHistory()).first.message,
          startsWith('Membuka'),
        );

        await File(
          '${second.path}${Platform.pathSeparator}SPEC.png',
        ).writeAsString('sample');
        expect((await repository.processCode('SPEC')).status, 409);
        expect(opener.opened, hasLength(1));
        final choice = (await repository.loadHistory()).first;
        expect(
          (await repository.openMatch(
            choice.id,
            choice.matches.last.path,
          )).status,
          200,
        );
        expect(opener.opened, hasLength(2));

        await repository.saveSettings(settings.copyWith(openInApp: true));
        expect((await storage.load()).openInApp, isTrue);
        await File(
          '${first.path}${Platform.pathSeparator}NEXT.pdf',
        ).writeAsString('sample');
        expect((await repository.processCode('NEXT')).status, 200);
        expect(opener.opened, hasLength(2));
        expect(
          (await repository.loadHistory()).first.message,
          startsWith('Menampilkan'),
        );
        final successfulEntry = (await repository.loadHistory()).first;
        expect(
          (await repository.reopenHistoryEntry(successfulEntry.id)).status,
          200,
        );
        expect(opener.opened, hasLength(2));

        await repository.saveSettings(settings.copyWith(openInApp: false));
        expect(
          (await repository.reopenHistoryEntry(successfulEntry.id)).status,
          200,
        );
        expect(opener.opened, hasLength(3));
        await File(successfulEntry.openedPath!).delete();
        expect(
          (await repository.reopenHistoryEntry(successfulEntry.id)).status,
          404,
        );
        expect(opener.opened, hasLength(3));
      } finally {
        await repository.stop();
        await temporary.delete(recursive: true);
      }
    },
  );

  test(
    'LAN API searches listed folders and children and rejects distinct duplicates',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'wms-listener-test-',
      );
      final first = await Directory(
        '${temporary.path}${Platform.pathSeparator}first',
      ).create();
      final second = await Directory(
        '${temporary.path}${Platform.pathSeparator}second',
      ).create();
      final child = await Directory(
        '${second.path}${Platform.pathSeparator}child',
      ).create();
      final repository = ListenerRepository(
        storage: TestStorage(
          File('${temporary.path}${Platform.pathSeparator}config.json'),
        ),
        historyStorage: TestHistory(
          File('${temporary.path}${Platform.pathSeparator}history.json'),
        ),
      );
      final settings = ListenerSettings(
        folders: [first.path, second.path],
        port: 0,
        key: 'test-key-123456789',
      );
      await repository.start(settings);
      final client = HttpClient();
      try {
        Future<int> send(String code, {bool authorized = true}) async {
          final request = await client.post(
            '127.0.0.1',
            repository.boundPort!,
            '/scan',
          );
          if (authorized) {
            request.headers.set('X-Listener-Key', 'test-key-123456789');
          }
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode({'code': code}));
          final response = await request.close();
          await response.drain<void>();
          return response.statusCode;
        }

        expect(await send('ABC123', authorized: false), 401);
        expect(await send('../secret.pdf'), 400);
        expect(await send('ABC123'), 404);
        await File(
          '${child.path}${Platform.pathSeparator}ABC123.pdf',
        ).writeAsString('sample');
        expect(await send('ABC123'), 200);
        expect(await send('ABC123.pdf'), 404);
        expect(await send('ABC'), 404);
        for (final mode in FileSearchMode.values.where(
          (mode) => mode != FileSearchMode.startsWith,
        )) {
          await repository.saveSettings(
            settings.copyWith(fileSearchMode: mode),
          );
          final query = switch (mode) {
            FileSearchMode.exact => 'abc123',
            FileSearchMode.contains => 'bc12',
            FileSearchMode.startsWith => throw StateError('tested separately'),
            FileSearchMode.normalizedExact => 'a-b.c123',
            FileSearchMode.normalizedStart => 'a-b.c',
            FileSearchMode.trimSuffix => 'abc12399',
          };
          expect(await send(query), 200, reason: mode.name);
          expect(
            await send('pdf'),
            404,
            reason: '${mode.name} ignores extension',
          );
          if (mode != FileSearchMode.trimSuffix) {
            expect(await send('ABC123.pdf'), 404);
          }
        }
        await repository.saveSettings(
          settings.copyWith(fileSearchMode: FileSearchMode.startsWith),
        );
        expect(await send('123'), 404);
        await repository.saveSettings(
          settings.copyWith(fileSearchMode: FileSearchMode.exact),
        );
        expect(await send('ABC'), 404);
        await repository.saveSettings(settings);
        expect(await send('  ABC123  '), 200);
        expect(await send('\u00A0ABC123\u200B  '), 200);
        await repository.saveSettings(settings.copyWith(trimScanValue: false));
        expect(await send('  ABC123  '), 404);
        expect(await send('\u00A0ABC123\u200B  '), 404);
        expect(await send('ABC123'), 200);
        await repository.saveSettings(settings);
        expect(
          (await repository.loadHistory()).first.openedPath,
          endsWith('ABC123.pdf'),
        );
        await File(
          '${first.path}${Platform.pathSeparator}ABC123.png',
        ).writeAsString('sample');
        expect(await send('ABC123'), 409);
        final history = await repository.loadHistory();
        expect(history.first.matches.length, 2);
        expect(history.first.needsSelection, isTrue);
        // Periodic Mobile authorization probes must not replace the pending
        // two-file choice or create extra history entries.
        for (final blank in ['', '  ', '\u00A0\u200B']) {
          expect(await send(blank), 400);
          final afterProbe = await repository.loadHistory();
          expect(afterProbe.length, history.length);
          expect(afterProbe.first.id, history.first.id);
          expect(afterProbe.first.code, 'ABC123');
          expect(afterProbe.first.matches.length, 2);
          expect(afterProbe.first.needsSelection, isTrue);
        }
        expect(await send('', authorized: false), 401);
        expect(
          (await repository.openMatch(
            history.first.id,
            history.first.matches.first.path,
          )).status,
          200,
        );
        expect((await repository.loadHistory()).first.openedPath, isNotNull);
        final opened = (await repository.loadHistory()).first;
        expect(await send(''), 400);
        expect((await repository.loadHistory()).first.id, opened.id);
        expect(
          (await repository.loadHistory()).first.openedPath,
          opened.openedPath,
        );
      } finally {
        client.close(force: true);
        await repository.stop();
        await temporary.delete(recursive: true);
      }
    },
  );

  test(
    'overlapping selected folders do not count the same file twice',
    () async {
      final temporary = await Directory.systemTemp.createTemp('wms-overlap-');
      final child = await Directory(
        '${temporary.path}${Platform.pathSeparator}child',
      ).create();
      await File(
        '${child.path}${Platform.pathSeparator}ONLY.pdf',
      ).writeAsString('sample');
      final repository = ListenerRepository(
        historyStorage: TestHistory(
          File('${temporary.path}${Platform.pathSeparator}history.json'),
        ),
      );
      try {
        await repository.start(
          ListenerSettings(
            folders: [temporary.path, child.path],
            port: 0,
            key: 'test-key-123456789',
          ),
        );
        expect((await repository.processCode('ONLY')).status, 200);
        final history = await repository.loadHistory();
        expect(history.first.matches.length, 1);
        expect(history.first.openedPath, isNotNull);
      } finally {
        await repository.stop();
        await temporary.delete(recursive: true);
      }
    },
  );
}
