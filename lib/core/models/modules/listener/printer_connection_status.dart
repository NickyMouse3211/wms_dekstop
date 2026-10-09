enum PrinterAvailability {
  checking,
  ready,
  submitted,
  offline,
  notConfigured,
  unknown,
}

class PrinterConnectionStatus {
  const PrinterConnectionStatus(this.availability, this.message);
  final PrinterAvailability availability;
  final String message;
  bool get ready =>
      availability == PrinterAvailability.ready ||
      availability == PrinterAvailability.submitted;
}
