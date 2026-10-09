import 'package:flutter/material.dart';
import '../../../../core/services/label_print_service.dart';
import '../../../components/section_card.dart';

class PrintLabelView extends StatefulWidget {
  const PrintLabelView({super.key});
  @override
  State<PrintLabelView> createState() => _PrintLabelViewState();
}

class _PrintLabelViewState extends State<PrintLabelView> {
  final _text = TextEditingController();
  String _type = 'qr';
  bool _busy = false;
  String? _message;

  Future<void> _print() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await LabelPrintService.instance.printLabel(
      _text.text,
      _type,
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _message = result.message;
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Print label',
    icon: Icons.print_outlined,
    subtitle:
        'Cetak teks beserta QR atau barcode. Pilih printer dan ukuran label di Pengaturan.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _text,
          enabled: !_busy,
          maxLength: 200,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Teks label',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'qr',
              label: Text('QR'),
              icon: Icon(Icons.qr_code),
            ),
            ButtonSegment(
              value: 'barcode',
              label: Text('Barcode'),
              icon: Icon(Icons.view_week_outlined),
            ),
          ],
          selected: {_type},
          onSelectionChanged: _busy
              ? null
              : (value) => setState(() => _type = value.single),
        ),
        const SizedBox(height: 10),
        if (_type == 'barcode')
          const Text('Code 128: maksimal 40 karakter ASCII, satu baris.'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _print,
          icon: const Icon(Icons.print_outlined),
          label: Text(_busy ? 'Mengirim...' : 'Print label'),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(_message!),
          ),
      ],
    ),
  );
}
