import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/wms_theme.dart';
import '../../../../core/cubit/modules/listener/printer_status_cubit.dart';
import '../../../../core/models/modules/listener/printer_connection_status.dart';
import '../../../../core/services/label_print_service.dart';

class PrinterStatusBadge extends StatelessWidget {
  const PrinterStatusBadge({super.key, this.service});
  final LabelPrintService? service;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PrinterStatusCubit(service: service)..start(),
    child: BlocBuilder<PrinterStatusCubit, PrinterConnectionStatus>(
      builder: (context, status) {
        final color = status.ready ? WmsColors.success : WmsColors.textLight;
        final label = switch (status.availability) {
          PrinterAvailability.ready => 'PRINTER SIAP',
          PrinterAvailability.submitted => 'PRINTER DIKONFIRMASI',
          PrinterAvailability.offline => 'PRINTER OFFLINE',
          PrinterAvailability.notConfigured => 'PRINTER BELUM DIATUR',
          PrinterAvailability.unknown => 'STATUS BELUM TERVERIFIKASI',
          PrinterAvailability.checking => 'MEMERIKSA PRINTER',
        };
        return Tooltip(
          message: status.availability == PrinterAvailability.unknown
              ? [status.message, 'Silakan coba print pertama untuk memverifikasi status.'].join('\n')
              : status.message,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: status.ready
                  ? const Color(0xFFE9F6EB)
                  : WmsColors.surfaceSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.print_outlined, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
