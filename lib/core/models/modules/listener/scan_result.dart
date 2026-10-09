class ScanResult {
  const ScanResult(this.status, this.message, {this.path});

  final int status;
  final String message;
  final String? path;

  bool get ok => status == 200;

  Map<String, Object?> toJson() => {
    'ok': ok,
    'message': message,
    if (path != null) 'path': path,
  };
}
