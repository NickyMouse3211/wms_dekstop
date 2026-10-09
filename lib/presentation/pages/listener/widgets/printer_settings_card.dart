import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../../core/services/label_print_service.dart';
import '../../../components/section_card.dart';

class PrinterSettingsCard extends StatefulWidget {
  const PrinterSettingsCard({super.key});
  @override
  State<PrinterSettingsCard> createState() => _PrinterSettingsCardState();
}

class _PrinterSettingsCardState extends State<PrinterSettingsCard> {
  final _qrWidth = TextEditingController(text: '60');
  final _qrHeight = TextEditingController(text: '40');
  final _barcodeWidth = TextEditingController(text: '60');
  final _barcodeHeight = TextEditingController(text: '40');
  final _qrMargins = List.generate(4, (_) => TextEditingController(text: '0'));
  final _barcodeMargins = List.generate(
    4,
    (_) => TextEditingController(text: '0'),
  );
  List<Printer> _printers = [];
  String? _url;
  String? _message;
  bool _busy = true;
  bool _loaded = false;
  bool _qrPrintText = true;
  bool _barcodePrintText = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final settings = await LabelPrintService.instance.load();
      final printers = await LabelPrintService.instance.printers();
      if (!mounted) return;
      setState(() {
        _printers = printers;
        if (!_loaded) {
          _qrWidth.text = settings.qrWidth.toString();
          _qrHeight.text = settings.qrHeight.toString();
          _barcodeWidth.text = settings.barcodeWidth.toString();
          _barcodeHeight.text = settings.barcodeHeight.toString();
          _qrPrintText = settings.qrPrintText;
          _barcodePrintText = settings.barcodePrintText;
          _loadMargins(_qrMargins, settings.qrMargins);
          _loadMargins(_barcodeMargins, settings.barcodeMargins);
          _url = settings.url.isEmpty ? null : settings.url;
          _loaded = true;
        }
        _message = printers.isEmpty
            ? 'Tidak ada printer. Tambahkan printer USB atau jaringan di Windows Settings.'
            : null;
        if (_url != null && !printers.any((printer) => printer.url == _url)) {
          _url = null;
          _message = 'Printer tersimpan tidak tersedia. Pilih kembali printer.';
        }
      });
    } catch (error) {
      if (mounted) setState(() => _message = 'Gagal memuat printer: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final selected = _printers.where((printer) => printer.url == _url);
      if (selected.isEmpty) throw const FormatException('Pilih printer.');
      await LabelPrintService.instance.save(
        LabelPrinterSettings(
          url: selected.first.url,
          name: selected.first.name,
          qrWidth: double.tryParse(_qrWidth.text) ?? 0,
          qrHeight: double.tryParse(_qrHeight.text) ?? 0,
          barcodeWidth: double.tryParse(_barcodeWidth.text) ?? 0,
          barcodeHeight: double.tryParse(_barcodeHeight.text) ?? 0,
          qrPrintText: _qrPrintText,
          barcodePrintText: _barcodePrintText,
          qrMargins: _readMargins(_qrMargins),
          barcodeMargins: _readMargins(_barcodeMargins),
        ),
      );
      if (mounted) {
        setState(() => _message = 'Printer dan ukuran label disimpan.');
      }
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _qrWidth.dispose();
    _qrHeight.dispose();
    _barcodeWidth.dispose();
    _barcodeHeight.dispose();
    for (final controller in [..._qrMargins, ..._barcodeMargins]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadMargins(
    List<TextEditingController> controllers,
    LabelMargins margins,
  ) {
    final values = [margins.left, margins.right, margins.top, margins.bottom];
    for (var index = 0; index < controllers.length; index++) {
      controllers[index].text = values[index].toString();
    }
  }

  LabelMargins _readMargins(List<TextEditingController> controllers) {
    final values = controllers
        .map(
          (controller) =>
              double.tryParse(controller.text.trim().replaceAll(',', '.')) ??
              double.nan,
        )
        .toList();
    return LabelMargins(
      left: values[0],
      right: values[1],
      top: values[2],
      bottom: values[3],
    );
  }

  Widget _marginFields(
    String type,
    List<TextEditingController> controllers,
  ) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var index = 0; index < controllers.length; index++)
          SizedBox(
            width: 160,
            child: TextField(
              controller: controllers[index],
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText:
                    'Margin ${['kiri', 'kanan', 'atas', 'bawah'][index]} $type',
                suffixText: 'mm',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _sizeFields(
    String type,
    TextEditingController width,
    TextEditingController height,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Ukuran label $type',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: width,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Lebar $type (mm)',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: height,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Tinggi $type (mm)',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Koneksi printer label',
    collapsible: true,
    icon: Icons.print_outlined,
    subtitle:
        'USB atau jaringan: instal printer di Windows, lalu pilih di sini. Samakan ukuran label dengan kertas printer.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(_url),
          initialValue: _url,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Printer Windows',
            border: OutlineInputBorder(),
          ),
          items: _printers
              .map(
                (p) => DropdownMenuItem(
                  value: p.url,
                  child: Text(p.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: _busy ? null : (value) => setState(() => _url = value),
        ),
        const SizedBox(height: 14),
        _sizeFields('QR', _qrWidth, _qrHeight),
        _marginFields('QR', _qrMargins),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Print with text — QR'),
          subtitle: const Text('Cetak teks di bawah QR.'),
          value: _qrPrintText,
          onChanged: _busy
              ? null
              : (value) => setState(() => _qrPrintText = value),
        ),
        const SizedBox(height: 16),
        _sizeFields('Barcode', _barcodeWidth, _barcodeHeight),
        _marginFields('Barcode', _barcodeMargins),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Print with text — Barcode'),
          subtitle: const Text('Cetak teks di bawah barcode.'),
          value: _barcodePrintText,
          onChanged: _busy
              ? null
              : (value) => setState(() => _barcodePrintText = value),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh printer'),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Simpan printer'),
            ),
          ],
        ),
        if (_busy) const Text('Memuat / menyimpan printer...'),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_message!),
          ),
      ],
    ),
  );
}
