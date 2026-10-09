import 'package:flutter/material.dart';

import '../../../../core/constants/wms_theme.dart';
import '../../../../core/cubit/modules/listener/listener_state.dart';
import '../../../../core/models/modules/listener/scan_history_entry.dart';
import '../../../components/section_card.dart';

class FileScanView extends StatelessWidget {
  const FileScanView({
    super.key,
    required this.state,
    required this.codeController,
    required this.onRun,
    required this.onOpenMatch,
    required this.onReopenHistory,
    required this.onOpenInAppChanged,
    required this.onPreviewFullScreenChanged,
    required this.onTrimScanValueChanged,
  });

  final ListenerState state;
  final TextEditingController codeController;
  final VoidCallback onRun;
  final void Function(String entryId, String path) onOpenMatch;
  final void Function(String entryId) onReopenHistory;
  final ValueChanged<bool> onOpenInAppChanged;
  final ValueChanged<bool> onPreviewFullScreenChanged;
  final ValueChanged<bool> onTrimScanValueChanged;

  String _time(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
  }

  Widget _matches(ScanHistoryEntry entry) {
    if (!entry.needsSelection) {
      if (entry.openedPath != null) {
        return SelectableText(
          entry.openedPath!,
          style: const TextStyle(color: WmsColors.textSecondary, fontSize: 12),
        );
      }
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih file yang ingin dibuka:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final match in entry.matches)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.description_outlined,
              color: WmsColors.primary,
            ),
            title: Text(match.name),
            subtitle: Text(
              match.path,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Icon(
              state.settings?.openInApp ?? true
                  ? Icons.visibility_outlined
                  : Icons.open_in_new_rounded,
            ),
            enabled: state.active && !state.busy,
            onTap: state.active && !state.busy
                ? () => onOpenMatch(entry.id, match.path)
                : null,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final latest = state.history.isEmpty ? null : state.history.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: 'Scan file dari PC',
          subtitle: 'Uji kode QR langsung dari komputer',
          icon: Icons.qr_code_scanner_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Nama file tanpa ekstensi',
                  hintText: 'Contoh: ABC123',
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
                onSubmitted: (_) {
                  if (state.active && !state.busy) onRun();
                },
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: state.active && !state.busy ? onRun : null,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Cari file'),
              ),
              if (!state.active) ...[
                const SizedBox(height: 12),
                const Text(
                  'Aktifkan listener dari Pengaturan sebelum mencoba scan.',
                  style: TextStyle(color: WmsColors.warning, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Trim nilai scan'),
                subtitle: const Text(
                  'Hapus spasi dan karakter tak terlihat di awal atau akhir kode QR.',
                ),
                value: state.settings?.trimScanValue ?? true,
                onChanged: state.settings == null || state.busy
                    ? null
                    : onTrimScanValueChanged,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Buka di aplikasi'),
                subtitle: const Text(
                  'ON: tampil di listener. OFF: buka dengan aplikasi Windows.',
                ),
                value: state.settings?.openInApp ?? true,
                onChanged: state.settings == null || state.busy
                    ? null
                    : onOpenInAppChanged,
              ),
              if (state.settings?.openInApp == true) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Full screen'),
                  subtitle: const Text(
                    'ON: buka popup maksimal. OFF: tampil di jendela utama listener.',
                  ),
                  value: state.settings?.previewFullScreen ?? true,
                  onChanged: state.busy ? null : onPreviewFullScreenChanged,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Baru saja di scan',
          subtitle: state.settings?.openInApp ?? true
              ? 'File tunggal tampil otomatis; hasil ganda menunggu pilihan'
              : 'File tunggal dibuka di Windows; hasil ganda menunggu pilihan',
          icon: Icons.fact_check_outlined,
          child: latest == null
              ? const Text('Belum ada file yang di-scan.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latest.code.isEmpty ? '(kode kosong)' : latest.code,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _time(latest.scannedAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(latest.message),
                    const SizedBox(height: 12),
                    _matches(latest),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Riwayat',
          subtitle: '50 scan terakhir tersimpan di PC ini',
          icon: Icons.history_rounded,
          child: state.history.isEmpty
              ? const Text('Belum ada riwayat scan.')
              : Column(
                  children: [
                    for (final entry in state.history)
                      if (entry.status == 200 && entry.openedPath != null)
                        ListTile(
                          key: ValueKey('history-${entry.id}'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.check_circle_outline,
                            color: WmsColors.success,
                          ),
                          title: Text(
                            entry.code.isEmpty ? '(kode kosong)' : entry.code,
                          ),
                          subtitle: Text(
                            '${_time(entry.scannedAt)} • ${entry.openedPath}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Icon(
                            state.settings?.openInApp ?? true
                                ? Icons.visibility_outlined
                                : Icons.open_in_new_rounded,
                          ),
                          enabled: !state.busy,
                          onTap: state.busy
                              ? null
                              : () => onReopenHistory(entry.id),
                        )
                      else
                        ExpansionTile(
                          key: ValueKey(entry.id),
                          tilePadding: EdgeInsets.zero,
                          leading: Icon(
                            entry.status == 200
                                ? Icons.check_circle_outline
                                : entry.needsSelection
                                ? Icons.list_alt_rounded
                                : Icons.info_outline_rounded,
                            color: entry.status == 200
                                ? WmsColors.success
                                : WmsColors.primary,
                          ),
                          title: Text(
                            entry.code.isEmpty ? '(kode kosong)' : entry.code,
                          ),
                          subtitle: Text(
                            '${_time(entry.scannedAt)} • ${entry.message}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          childrenPadding: const EdgeInsets.only(bottom: 12),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _matches(entry),
                            ),
                          ],
                        ),
                  ],
                ),
        ),
      ],
    );
  }
}
