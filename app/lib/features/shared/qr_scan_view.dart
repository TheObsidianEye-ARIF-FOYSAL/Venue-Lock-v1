import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Camera-based QR scanner shared by the admin and volunteer scan screens.
/// Debounces detections so a code held in frame for multiple camera frames
/// only fires [onDetect] once every couple of seconds.
class QrScanView extends StatefulWidget {
  final void Function(String code) onDetect;

  const QrScanView({super.key, required this.onDetect});

  @override
  State<QrScanView> createState() => _QrScanViewState();
}

class _QrScanViewState extends State<QrScanView> {
  final _controller = MobileScannerController();
  DateTime _lastDetection = DateTime.fromMillisecondsSinceEpoch(0);

  void _handleDetect(BarcodeCapture capture) {
    final now = DateTime.now();
    if (now.difference(_lastDetection) < const Duration(seconds: 2)) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _lastDetection = now;
        widget.onDetect(raw);
        break;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(controller: _controller, onDetect: _handleDetect);
  }
}
