class ScanFileMatch {
  const ScanFileMatch({required this.name, required this.path});

  final String name;
  final String path;

  Map<String, Object?> toJson() => {'name': name, 'path': path};

  factory ScanFileMatch.fromJson(Map<String, dynamic> json) => ScanFileMatch(
    name: json['name'] as String? ?? '',
    path: json['path'] as String? ?? '',
  );
}

class ScanHistoryEntry {
  const ScanHistoryEntry({
    required this.id,
    required this.code,
    required this.scannedAt,
    required this.status,
    required this.message,
    this.matches = const [],
    this.openedPath,
  });

  final String id;
  final String code;
  final DateTime scannedAt;
  final int status;
  final String message;
  final List<ScanFileMatch> matches;
  final String? openedPath;

  bool get needsSelection =>
      matches.length > 1 && openedPath == null && status == 409;

  ScanHistoryEntry copyWith({
    int? status,
    String? message,
    String? openedPath,
  }) => ScanHistoryEntry(
    id: id,
    code: code,
    scannedAt: scannedAt,
    status: status ?? this.status,
    message: message ?? this.message,
    matches: matches,
    openedPath: openedPath ?? this.openedPath,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'code': code,
    'scannedAt': scannedAt.toIso8601String(),
    'status': status,
    'message': message,
    'matches': matches.map((match) => match.toJson()).toList(),
    if (openedPath != null) 'openedPath': openedPath,
  };

  factory ScanHistoryEntry.fromJson(Map<String, dynamic> json) =>
      ScanHistoryEntry(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        scannedAt:
            DateTime.tryParse(json['scannedAt'] as String? ?? '') ??
            DateTime.now(),
        status: json['status'] as int? ?? 500,
        message: json['message'] as String? ?? '',
        matches: (json['matches'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ScanFileMatch.fromJson)
            .toList(),
        openedPath: json['openedPath'] as String?,
      );
}
