import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/constants/wms_theme.dart';
import '../../../../core/cubit/modules/listener/listener_cubit.dart';
import '../../../../core/cubit/modules/listener/listener_state.dart';
import '../../../../core/models/modules/listener/network_address.dart';
import '../../../../core/utils/listener_pairing_codec.dart';
import '../../../components/section_card.dart';

class PairingQrCard extends StatefulWidget {
  const PairingQrCard({
    super.key,
    required this.state,
    this.collapsible = false,
  });

  final ListenerState state;
  final bool collapsible;

  @override
  State<PairingQrCard> createState() => _PairingQrCardState();
}

class _PairingQrCardState extends State<PairingQrCard> {
  String? selectedIp;

  @override
  Widget build(BuildContext context) {
    final addresses = <NetworkAddress>[];
    final seen = <String>{};
    for (final address in widget.state.addresses) {
      if (seen.add(address.ip)) addresses.add(address);
    }
    final ip = seen.contains(selectedIp)
        ? selectedIp
        : addresses.isEmpty
        ? null
        : addresses.first.ip;
    final settings = widget.state.settings;

    return SectionCard(
      title: 'Hubungkan mobile dengan QR',
      collapsible: widget.collapsible,
      subtitle: 'Pindai dari Desktop > Setting pada aplikasi mobile',
      icon: Icons.qr_code_2_rounded,
      trailing: IconButton(
        tooltip: 'Perbarui alamat IP',
        onPressed: () => context.read<ListenerCubit>().refreshAddresses(),
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: !widget.state.active || settings == null
          ? const Text('Aktifkan listener untuk menampilkan QR koneksi.')
          : ip == null
          ? const Text('Alamat IP PC belum ditemukan.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih alamat IP PC yang satu jaringan dengan mobile:',
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: ip,
                  isExpanded: true,
                  items: [
                    for (final address in addresses)
                      DropdownMenuItem(
                        value: address.ip,
                        child: Text('${address.name} — ${address.ip}'),
                      ),
                  ],
                  onChanged: (value) => setState(() => selectedIp = value),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: WmsColors.border),
                    ),
                    child: QrImageView(
                      data: ListenerPairingCodec.encode(
                        ip: ip,
                        settings: settings,
                      ),
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(child: Text('IP $ip • Port ${settings.port}')),
                const SizedBox(height: 8),
                const Text(
                  'QR berisi kunci akses. Tampilkan hanya kepada pengguna yang boleh terhubung.',
                  style: TextStyle(
                    color: WmsColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    );
  }
}
