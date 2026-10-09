import 'package:flutter/material.dart';

import '../../../../core/constants/listener_constants.dart';
import '../../../../core/constants/wms_theme.dart';
import '../../../../core/cubit/modules/listener/listener_state.dart';
import '../../../components/section_card.dart';
import 'ip_address_card.dart';
import 'pairing_qr_card.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.state,
    required this.onTest,
    required this.onSettings,
    required this.onServiceChanged,
  });

  final ListenerState state;
  final VoidCallback onTest;
  final VoidCallback onSettings;
  final ValueChanged<bool> onServiceChanged;

  @override
  Widget build(BuildContext context) {
    final statusCard = SectionCard(
      title: 'Status listener',
      subtitle: 'Koneksi masuk dari aplikasi mobile',
      icon: Icons.sensors_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                state.active
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                color: state.active ? WmsColors.success : WmsColors.warning,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.active ? 'Siap menerima scan' : 'Listener tidak aktif',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(state.status, style: Theme.of(context).textTheme.bodySmall),
          if (state.settings?.activatedOnce == true) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Layanan listener'),
              subtitle: Text(state.active ? 'Aktif' : 'Mati'),
              value: state.active,
              onChanged: state.busy ? null : onServiceChanged,
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Chip(
                avatar: const Icon(Icons.lan_outlined, size: 17),
                label: Text(
                  'Port ${state.settings?.port ?? ListenerConstants.defaultPort}',
                ),
              ),
              FilledButton.icon(
                onPressed: state.active ? onTest : onSettings,
                icon: Icon(
                  state.active ? Icons.qr_code_scanner : Icons.settings,
                ),
                label: Text(state.active ? 'File Scan' : 'Buka Pengaturan'),
              ),
            ],
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: WmsColors.textPrimary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: WmsColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WMS Windows Listener',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Terima kode QR dari mobile dan tampilkan dokumen lokal di PC.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              return Column(
                children: [
                  statusCard,
                  const SizedBox(height: 16),
                  IpAddressCard(addresses: state.addresses),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: statusCard),
                const SizedBox(width: 16),
                Expanded(child: IpAddressCard(addresses: state.addresses)),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        PairingQrCard(state: state),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Scan terakhir',
          subtitle: 'Hasil terbaru yang diterima listener',
          icon: Icons.history_rounded,
          child: Row(
            children: [
              const Icon(Icons.description_outlined, color: WmsColors.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(state.lastResult)),
            ],
          ),
        ),
      ],
    );
  }
}
