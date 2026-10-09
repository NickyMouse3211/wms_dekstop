import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/modules/listener/listener_settings.dart';
import '../../../models/modules/listener/scan_result.dart';
import '../../../repository/modules/listener_repository.dart';
import '../../../utils/listener_validators.dart';
import 'listener_state.dart';

class ListenerCubit extends Cubit<ListenerState> {
  ListenerCubit(this._repository) : super(const ListenerState());

  final ListenerRepository _repository;

  Future<void> initialize() async {
    try {
      final settings = await _repository.loadSettings();
      final addresses = await _repository.networkAddresses();
      final history = await _repository.loadHistory();
      emit(
        state.copyWith(
          settings: settings,
          addresses: addresses,
          history: history,
          lastResult: history.isEmpty
              ? 'Belum ada scan'
              : history.first.message,
        ),
      );
      if (!settings.enabled) {
        emit(state.copyWith(status: 'Listener dimatikan.'));
      } else {
        await _start(settings);
      }
    } catch (error) {
      emit(state.copyWith(status: 'Gagal memuat: $error'));
    }
  }

  Future<void> refreshAddresses() async {
    final addresses = await _repository.networkAddresses();
    emit(state.copyWith(addresses: addresses));
  }

  Future<String?> saveSettings({
    required List<String> folders,
    required String port,
    required String key,
  }) async {
    final error = await ListenerValidators.validateSettings(
      folders: folders.where((folder) => folder.trim().isNotEmpty).toList(),
      port: port,
      key: key,
    );
    if (error != null) return error;
    final settings = ListenerSettings(
      folders: folders
          .map((folder) => folder.trim())
          .where((folder) => folder.isNotEmpty)
          .toList(),
      port: int.parse(port.trim()),
      key: key.trim(),
      enabled: true,
      activatedOnce: state.settings?.activatedOnce ?? false,
      openInApp: state.settings?.openInApp ?? true,
      previewFullScreen: state.settings?.previewFullScreen ?? true,
      trimScanValue: state.settings?.trimScanValue ?? true,
    );
    emit(state.copyWith(busy: true));
    try {
      await _repository.saveSettings(settings);
      emit(state.copyWith(settings: settings));
      await _start(settings);
      return state.active ? null : state.status;
    } catch (error) {
      return 'Gagal menyimpan: $error';
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  Future<String?> stopListener() async {
    if (!state.active || state.settings == null) return null;
    emit(state.copyWith(busy: true));
    try {
      await _repository.stop();
      final settings = state.settings!.copyWith(enabled: false);
      emit(state.copyWith(active: false, status: 'Listener dimatikan.'));
      await _repository.saveSettings(settings);
      emit(state.copyWith(settings: settings));
      return null;
    } catch (error) {
      return 'Gagal mematikan atau menyimpan status listener: $error';
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  Future<String?> startListener() async {
    final current = state.settings;
    if (current == null || state.busy) return 'Pengaturan belum siap';
    if (state.active) return null;
    emit(state.copyWith(busy: true));
    try {
      final validationError = await ListenerValidators.validateSettings(
        folders: current.folders,
        port: current.port.toString(),
        key: current.key,
      );
      if (validationError != null) return validationError;
      final settings = current.copyWith(enabled: true);
      await _repository.saveSettings(settings);
      emit(state.copyWith(settings: settings));
      await _start(settings);
      return state.active ? null : state.status;
    } catch (error) {
      return 'Gagal mengaktifkan listener: $error';
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  Future<String?> setOpenInApp(bool value) async {
    final current = state.settings;
    if (current == null || state.busy) return 'Pengaturan belum siap';
    final updated = current.copyWith(openInApp: value);
    emit(state.copyWith(busy: true));
    try {
      await _repository.saveSettings(updated);
      emit(state.copyWith(settings: updated));
      return null;
    } catch (error) {
      return 'Gagal menyimpan pilihan buka file: $error';
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  Future<String?> setPreviewFullScreen(bool value) async {
    final current = state.settings;
    if (current == null || state.busy) return 'Pengaturan belum siap';
    final updated = current.copyWith(previewFullScreen: value);
    emit(state.copyWith(busy: true));
    try {
      await _repository.saveSettings(updated);
      emit(state.copyWith(settings: updated));
      return null;
    } catch (error) {
      return 'Gagal menyimpan pilihan full screen: $error';
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  Future<String?> setTrimScanValue(bool value) async {
    final current = state.settings;
    if (current == null || state.busy) return 'Pengaturan belum siap';
    final updated = current.copyWith(trimScanValue: value);
    emit(state.copyWith(busy: true));
    try {
      await _repository.saveSettings(updated);
      emit(state.copyWith(settings: updated));
      return null;
    } catch (error) {
      return 'Gagal menyimpan pilihan trim nilai scan: $error';
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  Future<ScanResult> tryCode(String code) async {
    if (!state.active) return const ScanResult(503, 'Listener belum aktif');
    emit(state.copyWith(busy: true));
    try {
      return await _repository.processCode(code);
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  Future<ScanResult> openMatch(String entryId, String path) async {
    if (!state.active) return const ScanResult(503, 'Listener belum aktif');
    emit(state.copyWith(busy: true));
    try {
      return await _repository.openMatch(entryId, path);
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  Future<ScanResult> reopenHistoryEntry(String entryId) async {
    if (state.busy) return const ScanResult(409, 'Listener sedang memproses');
    emit(state.copyWith(busy: true));
    try {
      return await _repository.reopenHistoryEntry(entryId);
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  Future<void> _start(ListenerSettings settings) async {
    try {
      await _repository.start(
        settings,
        onHistoryChanged: (history) {
          if (!isClosed) {
            emit(
              state.copyWith(
                history: history,
                lastResult: history.isEmpty
                    ? 'Belum ada scan'
                    : history.first.message,
              ),
            );
          }
        },
      );
      var activatedSettings = settings;
      var status = 'Aktif pada port ${settings.port}';
      if (!settings.activatedOnce) {
        activatedSettings = settings.copyWith(activatedOnce: true);
        try {
          await _repository.saveSettings(activatedSettings);
        } catch (error) {
          status = '$status. Riwayat aktivasi belum tersimpan: $error';
        }
      }
      emit(
        state.copyWith(
          settings: activatedSettings,
          active: true,
          status: status,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(active: false, status: 'Listener gagal aktif: $error'),
      );
    }
  }

  @override
  Future<void> close() async {
    await _repository.stop();
    return super.close();
  }
}
