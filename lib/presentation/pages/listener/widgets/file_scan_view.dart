import 'package:flutter/material.dart';

import '../../../../core/constants/wms_theme.dart';
import '../../../../core/cubit/modules/listener/listener_state.dart';
import '../../../../core/models/modules/listener/scan_history_entry.dart';
import '../../../../core/models/modules/listener/listener_settings.dart';
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
    required this.onFileSearchModeChanged,
    required this.onFileSearchOperatorChanged,
  });

  final ListenerState state;
  final TextEditingController codeController;
  final VoidCallback onRun;
  final void Function(String entryId, String path) onOpenMatch;
  final void Function(String entryId) onReopenHistory;
  final ValueChanged<bool> onOpenInAppChanged;
  final ValueChanged<bool> onPreviewFullScreenChanged;
  final ValueChanged<bool> onTrimScanValueChanged;
  final ValueChanged<FileSearchMode> onFileSearchModeChanged;
  final Future<String?> Function(String) onFileSearchOperatorChanged;

  Widget _modeLabel(FileSearchMode mode) {
    final (color, speed) = switch (mode) {
      FileSearchMode.exact => (Colors.green, 'Paling cepat'),
      FileSearchMode.contains => (Colors.lightGreen, 'Cepat'),
      FileSearchMode.startsWith => (Colors.lime.shade700, 'Cepat–sedang'),
      FileSearchMode.normalizedExact => (Colors.orange, 'Lebih lambat'),
      FileSearchMode.normalizedStart => (Colors.red, 'Paling lambat'),
      FileSearchMode.trimSuffix => (Colors.amber.shade700, 'Sedang'),
    };
    final note = switch (mode) {
      FileSearchMode.exact =>
        'Cari nama yang sama persis dengan input Anda, tanpa ekstensi.\n'
            'Contoh: 3211 menemukan 3211.pdf, bukan 3211-1305.pdf.',
      FileSearchMode.contains =>
        'Cari teks Anda di bagian mana pun dalam nama file.\n'
            'Contoh: 3211 menemukan ABC3211.pdf dan 3211-1305.pdf.',
      FileSearchMode.startsWith =>
        'Isi Operator dengan pemisah nama file, misalnya -.\n'
            'Input harus sama persis dengan bagian sebelum pemisah pertama.\n'
            'Contoh: 3211 dengan - menemukan 3211-234241.pdf, '
            'bukan 13211-234241.pdf atau 32110-234241.pdf.',
      FileSearchMode.normalizedExact =>
        'Cari nama yang sama setelah tanda pemisah seperti spasi, - dan . diabaikan.\n'
            'Contoh: 32111305 menemukan 3211-1305.pdf, 3211.1305.pdf dan 32111305.pdf.',
      FileSearchMode.normalizedStart =>
        'Cari nama yang diawali input Anda setelah tanda pemisah diabaikan.\n'
            'Contoh: 3211 menemukan 3211-123421.pdf, 321-15345.pdf dan 32 11543563.pdf.',
      FileSearchMode.trimSuffix =>
        'Cari nama yang sama persis terlebih dahulu. Jika tidak ada, hapus '
            'karakter terakhir input satu per satu sampai ada hasil.\n'
            'Contoh: 321113051 dapat menemukan 32111305.pdf. '
            'Pencarian berhenti pada hasil pertama yang ditemukan; input tidak dikosongkan.',
    };
    return Tooltip(
      message:
          '$note\nSemua pilihan mengabaikan huruf besar/kecil dan ekstensi file.\nEstimasi kecepatan: $speed.',
      waitDuration: const Duration(milliseconds: 400),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 10,
            color: color,
            semanticLabel: 'Estimasi: $speed',
          ),
          const SizedBox(width: 8),
          Text(mode.label),
        ],
      ),
    );
  }

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<FileSearchMode>(
                      key: ValueKey((
                        state.settings?.fileSearchMode,
                        state.busy,
                      )),
                      initialValue:
                          state.settings?.fileSearchMode ??
                          FileSearchMode.exact,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Metode pencarian',
                      ),
                      items: [
                        for (final mode in FileSearchMode.values)
                          DropdownMenuItem(
                            value: mode,
                            child: _modeLabel(mode),
                          ),
                      ],
                      onChanged: state.settings == null || state.busy
                          ? null
                          : (value) {
                              if (value != null) onFileSearchModeChanged(value);
                            },
                    ),
                  ),
                  if (state.settings?.fileSearchMode ==
                      FileSearchMode.startsWith) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 110,
                      child: _SearchOperatorField(
                        value: state.settings!.fileSearchOperator,
                        onChanged: onFileSearchOperatorChanged,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(switch (state.settings?.fileSearchMode ??
                  FileSearchMode.exact) {
                FileSearchMode.exact =>
                  'Nama harus sama persis tanpa ekstensi.',
                FileSearchMode.contains =>
                  'Nama mengandung teks yang dicari (tidak peka huruf besar/kecil).',
                FileSearchMode.startsWith =>
                  'Segmen pertama sebelum operator harus sama persis dengan input.',
                FileSearchMode.normalizedExact =>
                  'Abaikan pemisah; seluruh huruf dan angka harus sama.',
                FileSearchMode.normalizedStart =>
                  'Abaikan pemisah; huruf dan angka diawali input.',
                FileSearchMode.trimSuffix =>
                  'Cari exact, lalu hapus karakter akhir input satu per satu sampai ditemukan.',
              }, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                'Tanpa ekstensi • PC dan Mobile • Tersimpan otomatis\n'
                'Estimasi kecepatan: hijau tercepat → merah paling lambat.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
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

class _SearchOperatorField extends StatefulWidget {
  const _SearchOperatorField({required this.value, required this.onChanged});
  final String value;
  final Future<String?> Function(String) onChanged;

  @override
  State<_SearchOperatorField> createState() => _SearchOperatorFieldState();
}

class _SearchOperatorFieldState extends State<_SearchOperatorField> {
  late final _controller = TextEditingController(text: widget.value);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    key: const ValueKey('file-search-operator'),
    controller: _controller,
    decoration: InputDecoration(
      labelText: 'Operator',
      hintText: '-',
      errorText: _error ?? (_controller.text.isEmpty ? 'Wajib diisi' : null),
      errorMaxLines: 3,
    ),
    onChanged: (value) async {
      setState(() => _error = null);
      final error = await widget.onChanged(value);
      if (!mounted || _controller.text != value) return;
      setState(() {
        _error = error;
        if (error != null) _controller.text = widget.value;
      });
    },
  );
}
