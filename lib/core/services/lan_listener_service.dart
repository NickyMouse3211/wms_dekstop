import 'dart:convert';
import 'dart:io';

import '../constants/listener_constants.dart';
import '../models/modules/listener/listener_settings.dart';
import '../models/modules/listener/scan_result.dart';

class LanListenerService {
  HttpServer? _server;
  Future<ScanResult> Function(String text, String type)? onPrintLabel;
  int? get boundPort => _server?.port;

  Future<void> start(
    ListenerSettings settings,
    Future<ScanResult> Function(String code) onScan,
  ) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, settings.port);
    _server!.listen((request) => _handle(request, settings, onScan));
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(
    HttpRequest request,
    ListenerSettings settings,
    Future<ScanResult> Function(String code) onScan,
  ) async {
    ScanResult result;
    if (request.method == 'GET' && request.uri.path == '/health') {
      result = const ScanResult(200, 'WMS Windows Listener aktif');
    } else if (request.method != 'POST' ||
        !['/scan', '/print-label'].contains(request.uri.path)) {
      result = const ScanResult(404, 'Endpoint tidak ditemukan');
    } else if (request.headers.value('X-Listener-Key') != settings.key) {
      result = const ScanResult(401, 'Kunci akses salah');
    } else if (request.headers.contentLength >
        ListenerConstants.maxRequestBytes) {
      result = const ScanResult(413, 'Permintaan terlalu besar');
    } else {
      try {
        final bytes = <int>[];
        await for (final chunk in request) {
          bytes.addAll(chunk);
          if (bytes.length > ListenerConstants.maxRequestBytes) {
            throw const FormatException('Permintaan terlalu besar');
          }
        }
        final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        if (request.uri.path == '/print-label') {
          if (data['text'] is! String ||
              (data['type'] != null && data['type'] is! String)) {
            result = const ScanResult(400, 'Data label tidak valid.');
          } else {
            result =
                await onPrintLabel?.call(
                  data['text'] as String,
                  data['type'] as String? ?? 'qr',
                ) ??
                const ScanResult(503, 'Printer belum tersedia.');
          }
        } else {
          result = await onScan(data['code']?.toString() ?? '');
        }
      } catch (error) {
        result = ScanResult(400, 'Data scan tidak valid: $error');
      }
    }
    request.response.statusCode = result.status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(result.toJson()));
    await request.response.close();
  }
}
