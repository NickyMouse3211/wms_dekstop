import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../models/modules/listener/printer_connection_status.dart';
import '../../../services/label_print_service.dart';

class PrinterStatusCubit extends Cubit<PrinterConnectionStatus> {
  PrinterStatusCubit({LabelPrintService? service})
    : _service = service ?? LabelPrintService.instance,
      super(
        const PrinterConnectionStatus(
          PrinterAvailability.checking,
          'Memeriksa printer...',
        ),
      );
  final LabelPrintService _service;
  Timer? _timer;
  bool _started = false;

  void start() {
    if (isClosed || _started) return;
    _started = true;
    _refresh();
  }

  Future<void> _refresh() async {
    PrinterConnectionStatus result;
    try {
      result = await _service.printerStatus();
    } catch (_) {
      result = const PrinterConnectionStatus(
        PrinterAvailability.unknown,
        'Status printer tidak dapat dibaca.',
      );
    }
    if (isClosed) return;
    if (state.availability != result.availability ||
        state.message != result.message) {
      emit(result);
    }
    _timer = Timer(const Duration(seconds: 5), _refresh);
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
