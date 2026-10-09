import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/wms_theme.dart';
import '../../../../core/cubit/modules/listener/listener_cubit.dart';
import '../../../../core/models/modules/listener/network_address.dart';
import '../../../components/section_card.dart';

class IpAddressCard extends StatelessWidget {
  const IpAddressCard({super.key, required this.addresses});

  final List<NetworkAddress> addresses;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Alamat IP PC',
    subtitle: 'Alamat untuk aplikasi mobile',
    icon: Icons.wifi_rounded,
    trailing: IconButton(
      tooltip: 'Perbarui IP',
      onPressed: () async {
        try {
          await context.read<ListenerCubit>().refreshAddresses();
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Gagal membaca IP: $error')));
          }
        }
      },
      icon: const Icon(Icons.refresh_rounded),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (addresses.isEmpty) const Text('IP jaringan belum ditemukan.'),
        for (final address in addresses) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: WmsColors.surfaceSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: WmsColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lan_outlined,
                  color: WmsColors.primary,
                  size: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      SelectableText(
                        address.ip,
                        style: const TextStyle(
                          color: WmsColors.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Salin IP',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: address.ip));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('IP ${address.ip} disalin.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 20),
                ),
              ],
            ),
          ),
        ],
        const Text(
          'Gunakan IP Wi-Fi yang sama dengan scanner mobile.',
          style: TextStyle(color: WmsColors.textSecondary, fontSize: 12),
        ),
      ],
    ),
  );
}
