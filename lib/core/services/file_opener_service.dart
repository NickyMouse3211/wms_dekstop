import 'dart:convert';
import 'dart:io';

class FileOpenerService {
  Future<void> open(String path) async {
    // Encode the command so special characters in a file path remain data.
    final escaped = path.replaceAll("'", "''");
    final script = "Start-Process -FilePath '$escaped' -ErrorAction Stop";
    final units = <int>[];
    for (final unit in script.codeUnits) {
      units.addAll([unit & 0xff, unit >> 8]);
    }
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      base64Encode(units),
    ]);
    if (result.exitCode != 0) {
      throw ProcessException(
        'powershell.exe',
        [],
        result.stderr.toString(),
        result.exitCode,
      );
    }
  }
}
