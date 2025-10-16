import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<StatefulWidget> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  Barcode? result;
  String token = 'mYxyCBM4KnjX0ZyMEYCG5Mb8k2S';
  bool loading = false;

  Future<void> doPayment(int id, int amount) async {
    print(id);
    print(amount);

    if (!loading) {
      setState(() {
        loading = true;
      });
    }

    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    var request = http.Request(
      'PATCH',
      Uri.parse('https://qr.contrapoetra.com/rest/payments/$id'),
    );
    request.body = json.encode({
      "status": "paid",
    });
    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      print(await response.stream.bytesToString());
      Navigator.pop(context, amount);
    } else {
      print('Response not 200: ${response.reasonPhrase}');
    }
  }

  // Reassemble handles camera pause/resume when hot reloading
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Code Scanner')),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderColor: Colors.blue,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: MediaQuery.of(context).size.width * 0.8,
              ),
            ),
          ),

          Expanded(
            flex: 1,
            child: Center(
              child: (result != null)
                  ? Column(
                    children: [
                      Text(
                        'Scanned: ${result!.code}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          doPayment(int.parse(result!.code.toString().split(':::')[0]), int.parse(result!.code.toString().split(':::')[1]));
                        },
                        child: const Text('Copy'),
                      )
                    ]
                  )
                  : const Text(
                      'Scan a QR code',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
            ),
          )
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;

    controller.scannedDataStream.listen((scanData) {
      setState(() {
        result = scanData;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }
}
