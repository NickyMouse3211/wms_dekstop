// Run after a Windows build:
// dart scripts/check_pdfium_isolation.dart build/windows/x64/runner/Release
// Exercises native PDF lifetimes without sending anything to a printer.
import 'dart:ffi';
import 'dart:io';

import 'package:pdf/widgets.dart' as pw;

class PdfiumProbe {
  PdfiumProbe(String path) : library = DynamicLibrary.open(path);
  final DynamicLibrary library;
  late final init = library.lookupFunction<Void Function(), void Function()>(
    'FPDF_InitLibrary',
  );
  late final destroy = library.lookupFunction<Void Function(), void Function()>(
    'FPDF_DestroyLibrary',
  );
  late final load = library
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, UintPtr, Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>, int, Pointer<Void>)
      >('FPDF_LoadMemDocument64');
  late final close = library
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('FPDF_CloseDocument');
  late final loadPage = library
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Int32),
        Pointer<Void> Function(Pointer<Void>, int)
      >('FPDF_LoadPage');
  late final closePage = library
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('FPDF_ClosePage');
  late final bitmapCreate = library
      .lookupFunction<
        Pointer<Void> Function(Int32, Int32, Int32),
        Pointer<Void> Function(int, int, int)
      >('FPDFBitmap_Create');
  late final bitmapDestroy = library
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('FPDFBitmap_Destroy');
  late final render = library
      .lookupFunction<
        Void Function(
          Pointer<Void>,
          Pointer<Void>,
          Int32,
          Int32,
          Int32,
          Int32,
          Int32,
          Int32,
        ),
        void Function(
          Pointer<Void>,
          Pointer<Void>,
          int,
          int,
          int,
          int,
          int,
          int,
        )
      >('FPDF_RenderPageBitmap');

  void renderPage(Pointer<Void> page) {
    final bitmap = bitmapCreate(64, 64, 1);
    if (bitmap == nullptr) throw StateError('Cannot allocate PDF bitmap');
    try {
      render(bitmap, page, 0, 0, 64, 64, 0, 0);
    } finally {
      bitmapDestroy(bitmap);
    }
  }
}

Future<void> main(List<String> args) async {
  if (!Platform.isWindows || args.length != 1) {
    throw ArgumentError('Supply a Windows build bundle directory.');
  }
  final bundle = Directory(args.single).absolute.path;
  final viewer = PdfiumProbe('$bundle/pdfium_viewer.dll');
  final printer = PdfiumProbe('$bundle/pdfium.dll');
  if (viewer.library.handle == printer.library.handle) {
    throw StateError('Viewer and printer must load different native modules.');
  }
  final document = pw.Document()
    ..addPage(pw.Page(build: (_) => pw.Text('WMS preview / print regression')));
  final bytes = await document.save();
  final kernel = DynamicLibrary.open('kernel32.dll');
  final heap = kernel
      .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
        'GetProcessHeap',
      )();
  final allocate = kernel
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Uint32, UintPtr),
        Pointer<Void> Function(Pointer<Void>, int, int)
      >('HeapAlloc');
  final free = kernel
      .lookupFunction<
        Int32 Function(Pointer<Void>, Uint32, Pointer<Void>),
        int Function(Pointer<Void>, int, Pointer<Void>)
      >('HeapFree');
  final data = allocate(heap, 0, bytes.length);
  if (data == nullptr) throw StateError('Cannot allocate PDF data');
  data.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
  viewer.init();
  final previewDocument = viewer.load(data, bytes.length, nullptr);
  if (previewDocument == nullptr) throw StateError('Cannot open preview PDF');
  final previewPage = viewer.loadPage(previewDocument, 0);
  if (previewPage == nullptr) throw StateError('Cannot open preview page');
  try {
    viewer.renderPage(previewPage);
    for (var job = 0; job < 3; job++) {
      printer.init();
      final printDocument = printer.load(data, bytes.length, nullptr);
      if (printDocument == nullptr) throw StateError('Cannot open print PDF');
      final printPage = printer.loadPage(printDocument, 0);
      if (printPage == nullptr) throw StateError('Cannot open print page');
      printer.renderPage(printPage);
      printer.closePage(printPage);
      printer.close(printDocument);
      printer.destroy();
      // Keep the original preview handles alive across printing teardown.
      viewer.renderPage(previewPage);
    }
    stdout.writeln(
      'PASS: preview still renders after three print-library lifecycles. No print jobs submitted.',
    );
  } finally {
    viewer.closePage(previewPage);
    viewer.close(previewDocument);
    viewer.destroy();
    free(heap, 0, data);
  }
}
