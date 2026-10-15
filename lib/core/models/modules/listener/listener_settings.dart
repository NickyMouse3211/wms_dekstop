enum FileSearchMode {
  exact('Exact match'),
  contains('Contains'),
  startsWith('Starts with'),
  normalizedExact('Normalized exact'),
  normalizedStart('Normalized start'),
  trimSuffix('Trim suffix');

  const FileSearchMode(this.label);
  final String label;

  static FileSearchMode fromStored(Object? value) =>
      values.firstWhere((mode) => mode.name == value, orElse: () => exact);
}

class ListenerSettings {
  const ListenerSettings({
    required this.folders,
    required this.port,
    required this.key,
    this.enabled = true,
    this.activatedOnce = false,
    this.openInApp = true,
    this.previewFullScreen = true,
    this.trimScanValue = true,
    this.fileSearchMode = FileSearchMode.exact,
    this.fileSearchOperator = '-',
  });

  final List<String> folders;
  final int port;
  final String key;
  final bool enabled;
  final bool activatedOnce;
  final bool openInApp;
  final bool previewFullScreen;
  final bool trimScanValue;
  final FileSearchMode fileSearchMode;
  final String fileSearchOperator;

  ListenerSettings copyWith({
    bool? enabled,
    bool? activatedOnce,
    bool? openInApp,
    bool? previewFullScreen,
    bool? trimScanValue,
    FileSearchMode? fileSearchMode,
    String? fileSearchOperator,
  }) => ListenerSettings(
    folders: folders,
    port: port,
    key: key,
    enabled: enabled ?? this.enabled,
    activatedOnce: activatedOnce ?? this.activatedOnce,
    openInApp: openInApp ?? this.openInApp,
    previewFullScreen: previewFullScreen ?? this.previewFullScreen,
    trimScanValue: trimScanValue ?? this.trimScanValue,
    fileSearchMode: fileSearchMode ?? this.fileSearchMode,
    fileSearchOperator: fileSearchOperator ?? this.fileSearchOperator,
  );
}
