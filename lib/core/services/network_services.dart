import 'dart:io';

import '../models/modules/listener/network_address.dart';

class NetworkServices {
  Future<List<NetworkAddress>> addresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    final found = <NetworkAddress>[];
    for (final network in interfaces) {
      for (final address in network.addresses) {
        if (!address.isLoopback && !address.address.startsWith('169.254.')) {
          found.add(NetworkAddress(name: network.name, ip: address.address));
        }
      }
    }
    int rank(String name) {
      final lower = name.toLowerCase();
      if (lower.contains('wi-fi') ||
          lower.contains('wifi') ||
          lower.contains('wlan')) {
        return 0;
      }
      if (lower.contains('ethernet')) return 1;
      return 2;
    }

    found.sort((a, b) {
      final byRank = rank(a.name).compareTo(rank(b.name));
      return byRank != 0 ? byRank : a.name.compareTo(b.name);
    });
    return found;
  }
}
