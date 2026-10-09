import 'dart:convert';

import '../models/modules/listener/listener_settings.dart';

abstract final class ListenerPairingCodec {
  static const type = 'wms_windows_listener';
  static const version = 1;

  static String encode({
    required String ip,
    required ListenerSettings settings,
  }) => jsonEncode({
    'type': type,
    'version': version,
    'ip': ip,
    'port': settings.port,
    'key': settings.key,
  });
}
