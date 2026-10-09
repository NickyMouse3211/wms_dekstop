import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/constants/wms_theme.dart';

class FilePreviewView extends StatelessWidget {
  const FilePreviewView({
    super.key,
    required this.path,
    required this.onBack,
    required this.onOpenExternal,
  });

  final String path;
  final VoidCallback onBack;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final name = path.split(Platform.pathSeparator).last;
    final extension = name.contains('.')
        ? name.substring(name.lastIndexOf('.')).toLowerCase()
        : '';
    final inline = const {
      '.pdf',
      '.png',
      '.jpg',
      '.jpeg',
      '.txt',
    }.contains(extension);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Tutup pratinjau',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (inline)
              TextButton.icon(
                onPressed: onOpenExternal,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Buka di aplikasi lain'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ColoredBox(
              color: WmsColors.surface,
              child: switch (extension) {
                '.pdf' => PdfViewer.file(
                  path,
                  key: ValueKey(path),
                  params: PdfViewerParams(
                    errorBannerBuilder: (context, error, _, _) {
                      final summary = error.toString().split('\n').first;
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 48),
                              const SizedBox(height: 12),
                              const Text('PDF tidak dapat ditampilkan.'),
                              const SizedBox(height: 8),
                              Text(
                                summary,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: onOpenExternal,
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: const Text('Buka di aplikasi lain'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                '.png' || '.jpg' || '.jpeg' => InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Center(
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, error, _) => Center(
                        child: Text('Gagal menampilkan gambar: $error'),
                      ),
                    ),
                  ),
                ),
                '.txt' => FutureBuilder<String>(
                  key: ValueKey(path),
                  future: File(path).readAsString(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Gagal membaca file: ${snapshot.error}'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: SelectableText(snapshot.data!),
                    );
                  },
                ),
                _ => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.description_outlined, size: 56),
                      const SizedBox(height: 16),
                      const Text(
                        'Pratinjau Office belum tersedia di dalam aplikasi.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: onOpenExternal,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Buka di aplikasi Office'),
                      ),
                    ],
                  ),
                ),
              },
            ),
          ),
        ),
      ],
    );
  }
}
