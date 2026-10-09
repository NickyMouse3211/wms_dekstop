import 'dart:io';

abstract final class ListenerValidators {
  static final RegExp _scanPadding = RegExp(
    r'^[\s\u00A0\u200B\uFEFF]+|[\s\u00A0\u200B\uFEFF]+$',
  );

  static String trimScanValue(String value) =>
      value.replaceAll(_scanPadding, '');

  static Future<String?> validateSettings({
    required List<String> folders,
    required String port,
    required String key,
  }) async {
    final number = int.tryParse(port.trim());
    if (number == null || number < 1024 || number > 65535) {
      return 'Port harus antara 1024 dan 65535.';
    }
    final unique = <String>{};
    for (var index = 0; index < folders.length; index++) {
      final path = Directory(folders[index].trim()).absolute.path;
      if (!unique.add(path.toLowerCase())) {
        return 'Folder yang sama dipilih lebih dari sekali.';
      }
      if (!await Directory(path).exists()) {
        return 'Folder ${index + 1} tidak ditemukan.';
      }
    }
    if (key.trim().length < 8) {
      return 'Kunci akses minimal 8 karakter.';
    }
    return null;
  }

  static bool isFileName(String code) {
    if (code.isEmpty ||
        code.length > 150 ||
        code == '.' ||
        code.contains('..')) {
      return false;
    }
    return !RegExp(r'[\\/:*?"<>|\x00-\x1F]').hasMatch(code);
  }
}
