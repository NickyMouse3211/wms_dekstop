import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/wms_theme.dart';
import '../../../../core/cubit/modules/listener/listener_state.dart';
import '../../../../core/services/access_key_service.dart';
import '../../../components/section_card.dart';
import 'pairing_qr_card.dart';
import 'printer_settings_card.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.state,
    required this.folderControllers,
    required this.portController,
    required this.keyController,
    required this.onAddFolder,
    required this.onRemoveFolder,
    required this.onSave,
    required this.onStop,
  });

  final ListenerState state;
  final List<TextEditingController> folderControllers;
  final TextEditingController portController;
  final TextEditingController keyController;
  final VoidCallback onAddFolder;
  final ValueChanged<int> onRemoveFolder;
  final VoidCallback onSave;
  final VoidCallback onStop;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool showKey = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionCard(
        title: 'Folder dokumen',
        collapsible: true,
        subtitle:
            'Lokasi pencarian File Scan. Opsional jika hanya mencetak label.',
        icon: Icons.folder_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (
              var index = 0;
              index < widget.folderControllers.length;
              index++
            ) ...[
              Padding(
                key: ValueKey(widget.folderControllers[index]),
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${index + 1}.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: widget.folderControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Folder ${index + 1}',
                          hintText: r'D:\Dokumen\WMS',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Pilih folder ${index + 1}',
                      onPressed: () async {
                        final chosen = await getDirectoryPath(
                          confirmButtonText: 'Pilih folder',
                        );
                        if (chosen != null) {
                          widget.folderControllers[index].text = chosen;
                        }
                      },
                      icon: const Icon(Icons.folder_open_outlined),
                    ),
                    IconButton(
                      tooltip: 'Hapus folder ${index + 1}',
                      onPressed: () => widget.onRemoveFolder(index),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ],
            OutlinedButton.icon(
              onPressed: widget.onAddFolder,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah folder'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pencarian meliputi semua folder dalam daftar dan seluruh subfoldernya. QR berisi nama file atau nama tanpa ekstensi.',
              style: TextStyle(color: WmsColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Koneksi LAN',
        collapsible: true,
        subtitle: 'Pengaturan komunikasi antara mobile dan PC',
        icon: Icons.router_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 230,
              child: TextField(
                controller: widget.portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Port listener'),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: widget.keyController,
              obscureText: !showKey,
              decoration: InputDecoration(
                labelText: 'Kunci akses',
                helperText:
                    'Masukkan kunci ini pada konfigurasi aplikasi mobile.',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: showKey
                          ? 'Sembunyikan kunci'
                          : 'Tampilkan kunci',
                      onPressed: () => setState(() => showKey = !showKey),
                      icon: Icon(
                        showKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Salin kunci',
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: widget.keyController.text),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kunci akses disalin.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: widget.state.busy
                  ? null
                  : () {
                      widget.keyController.text = AccessKeyService.generate();
                      setState(() => showKey = true);
                    },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Buat kunci 8 karakter'),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kunci baru berlaku setelah disimpan dan listener diaktifkan.',
              style: TextStyle(color: WmsColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      PairingQrCard(state: widget.state, collapsible: true),
      const SizedBox(height: 16),
      const PrinterSettingsCard(),
      const SizedBox(height: 24),
      Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: widget.state.busy ? null : widget.onSave,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              widget.state.active
                  ? 'Simpan dan aktifkan ulang'
                  : 'Simpan dan aktifkan',
            ),
          ),
          if (widget.state.active)
            OutlinedButton.icon(
              onPressed: widget.state.busy ? null : widget.onStop,
              icon: const Icon(Icons.power_settings_new_rounded),
              label: const Text('Matikan'),
            ),
        ],
      ),
    ],
  );
}
