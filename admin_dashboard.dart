import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:smart_car_parking/services/user_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isPaused = false;

  (String, DateTime)? last;

  void _logEntryOrExit(String qrData) async {
    controller!.pauseCamera();
    log('message: $qrData');
    var now = DateTime.now();
    if (last != null &&
        last!.$1 == qrData &&
        now.difference(last!.$2).inSeconds < 10) {
      controller!.resumeCamera();
      return;
    }
    last = (qrData, now);
    var messanger = ScaffoldMessenger.of(context);
    var user = await UserService.getUserOnce(qrData);
    var res = await user.toggleUsing();
    messanger.showSnackBar(
      SnackBar(
        content: Text(res.$2),
        backgroundColor: res.$1 ? Colors.red : null,
      ),
    );
    controller!.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              flex: 4,
              child: isPaused
                  ? SizedBox.shrink()
                  : QRView(
                      key: qrKey,
                      onQRViewCreated: (QRViewController controller) {
                        this.controller = controller;
                        controller.scannedDataStream.listen((scanData) {
                          _logEntryOrExit(scanData.code!);
                        });
                      },
                    ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (isPaused) {
                      controller?.resumeCamera();
                    } else {
                      controller?.pauseCamera();
                    }
                    setState(() {
                      isPaused = !isPaused;
                    });
                  },
                  child: Text(isPaused ? 'Resume Scanner' : 'Pause Scanner'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
