import '../../../models/modules/listener/listener_settings.dart';
import '../../../models/modules/listener/network_address.dart';
import '../../../models/modules/listener/scan_history_entry.dart';

class ListenerState {
  const ListenerState({
    this.settings,
    this.addresses = const [],
    this.history = const [],
    this.status = 'Memuat pengaturan...',
    this.lastResult = 'Belum ada scan',
    this.busy = false,
    this.active = false,
  });

  final ListenerSettings? settings;
  final List<NetworkAddress> addresses;
  final List<ScanHistoryEntry> history;
  final String status;
  final String lastResult;
  final bool busy;
  final bool active;

  ListenerState copyWith({
    ListenerSettings? settings,
    List<NetworkAddress>? addresses,
    List<ScanHistoryEntry>? history,
    String? status,
    String? lastResult,
    bool? busy,
    bool? active,
  }) => ListenerState(
    settings: settings ?? this.settings,
    addresses: addresses ?? this.addresses,
    history: history ?? this.history,
    status: status ?? this.status,
    lastResult: lastResult ?? this.lastResult,
    busy: busy ?? this.busy,
    active: active ?? this.active,
  );
}
