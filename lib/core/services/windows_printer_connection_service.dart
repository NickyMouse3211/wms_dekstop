import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/modules/listener/printer_connection_status.dart';

/// Read-only device check, separate from the spooler's cached queue status.
class WindowsPrinterConnectionService {
  Future<PrinterConnectionStatus> check(String printerName) async {
    if (!Platform.isWindows) {
      return const PrinterConnectionStatus(
        PrinterAvailability.unknown,
        'Pemeriksaan koneksi fisik hanya tersedia di Windows.',
      );
    }
    Process? process;
    try {
      final root = Platform.environment['SystemRoot'] ?? r'C:\Windows';
      // Printer names are data, never interpolated into executable PowerShell.
      final encoded = base64Encode(
        script.codeUnits.expand((unit) => [unit & 255, unit >> 8]).toList(),
      );
      process = await Process.start(
        '$root\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
        [
          '-NoLogo',
          '-NoProfile',
          '-NonInteractive',
          '-WindowStyle',
          'Hidden',
          '-EncodedCommand',
          encoded,
        ],
        environment: {'WMS_STATUS_PRINTER': printerName},
      );
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.drain<void>();
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 8),
      );
      await errors;
      if (exitCode != 0) throw StateError('Printer query failed');
      return fromObservation(jsonDecode(await output) as Map<String, dynamic>);
    } catch (_) {
      return const PrinterConnectionStatus(
        PrinterAvailability.unknown,
        'Koneksi fisik printer belum dapat dipastikan. Periksa kabel, daya, dan driver printer.',
      );
    } finally {
      process?.kill();
    }
  }

  static PrinterConnectionStatus fromObservation(Map<String, dynamic> data) {
    return switch (data['state']) {
      'connected' => const PrinterConnectionStatus(
        PrinterAvailability.ready,
        'Perangkat USB printer terdeteksi pada port yang dipilih. Status kertas tetap bergantung pada driver.',
      ),
      'offline' => const PrinterConnectionStatus(
        PrinterAvailability.offline,
        'Printer tidak terhubung atau Windows melaporkan printer offline. Periksa daya dan kabel USB.',
      ),
      'placeholder' => const PrinterConnectionStatus(
        PrinterAvailability.unknown,
        'Windows mendeteksi port USB tetapi melaporkan "No Printer Attached". Printer siap belum dapat dikonfirmasi; periksa daya dan driver.',
      ),
      _ => const PrinterConnectionStatus(
        PrinterAvailability.unknown,
        'Antrean printer tersedia, tetapi koneksi fisik belum dapat dikonfirmasi untuk port/driver ini.',
      ),
    };
  }

  static const script = r'''
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$printer = Get-CimInstance Win32_Printer | Where-Object { $_.Name -eq $env:WMS_STATUS_PRINTER } | Select-Object -First 1
if ($null -eq $printer -or $printer.WorkOffline -or $printer.PrinterStatus -eq 7) {
  @{state='offline'} | ConvertTo-Json -Compress
  exit
}
$port = [string]$printer.PortName
if ($port -notmatch '^USB\d+$') {
  @{state='unknown'} | ConvertTo-Json -Compress
  exit
}
$mapping = Get-ItemProperty -LiteralPath ('HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors\USB Monitor\Ports\' + $port)
$deviceId = [string]$mapping.'Device Id'
if ([string]::IsNullOrWhiteSpace($deviceId)) {
  @{state='unknown'} | ConvertTo-Json -Compress
  exit
}
$present = @(Get-PnpDevice -PresentOnly)
$physical = @($present | Where-Object { $_.InstanceId -eq $deviceId })
if ($physical.Count -eq 0) {
  @{state='offline'} | ConvertTo-Json -Compress
  exit
}
$portDevices = @($present | Where-Object {
  $_.InstanceId.StartsWith('USBPRINT\', [StringComparison]::OrdinalIgnoreCase) -and
  $_.InstanceId.EndsWith(('&' + $port), [StringComparison]::OrdinalIgnoreCase)
})
if ($portDevices.Count -eq 0) {
  @{state='unknown'} | ConvertTo-Json -Compress
  exit
}
if (@($portDevices | Where-Object { $_.InstanceId -like 'USBPRINT\UNKNOWNPRINTER\*' }).Count -gt 0) {
  @{state='placeholder'} | ConvertTo-Json -Compress
  exit
}
if (@($physical | Where-Object { $_.Status -ne 'OK' }).Count -gt 0 -or
    @($portDevices | Where-Object { $_.Status -ne 'OK' }).Count -gt 0) {
  @{state='offline'} | ConvertTo-Json -Compress
  exit
}
@{state='connected'} | ConvertTo-Json -Compress
''';
}
