import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'qr.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(fontFamily: 'Montserrat'),
      routes: {'/': (context) => Home()},
    );
  }
}

class Home extends StatefulWidget {
  Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int balance = 0;
  String token = 'mYxyCBM4KnjX0ZyMEYCG5Mb8k2S';
  String kv = 'payments';
  String currentPaymentQR = '';
  String currentPaymentToken = '';
  String currentPaymentStatus = '';
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      balance = prefs.getInt('balance') ?? 100000;
    });
  }

  TextEditingController amountController = TextEditingController();

  Future<void> setPayment(int amount) async {
    if (!loading) {
      setState(() {
        loading = true;
      });
    }

    int id = DateTime.now().microsecondsSinceEpoch;
    var headers = {
      // 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    var request = http.Request(
      'POST',
      Uri.parse('https://qr.contrapoetra.com/rest/payments'),
    );
    request.body = json.encode({
      "id": "$id",
      "amount": amount,
      "status": "pending",
    });
    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      print(await response.stream.bytesToString());
    } else {
      print('Response not 200: ${response.reasonPhrase}');
    }

    setState(() {
      currentPaymentToken = '${id.toString()}:::${amount.toString()}';
      currentPaymentQR =
          'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=$currentPaymentToken';
      loading = false;
    });
    print(currentPaymentQR);
  }

  Future<void> checkPayment() async {
    if (!loading) {
      setState(() {
        loading = true;
      });
    }

    var headers = {
      // 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    var request = http.Request(
      'GET',
      Uri.parse(
        'https://qr.contrapoetra.com/rest/payments/${currentPaymentToken.split(':::')[0]}',
      ),
    );
    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      String responseString = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseString);
      currentPaymentStatus = jsonResponse['results'][0]['status'];
      if (currentPaymentStatus == "paid") {
        currentPaymentQR = '';
        balance += int.parse(currentPaymentToken.split(':::')[1]);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setInt('balance', balance);
      }
      amountController.text = '';
      setState(() {
        loading = false;
      });
    } else {
      print('Response not 200: ${response.reasonPhrase}');
      setState(() {
        loading = false;
      });
    }
  }

  String balanceToCurrency(int balance) {
    String input = balance.toString();
    int chunkSize = 3;

    List<String> parts = [];
    for (int i = input.length; i > 0; i -= chunkSize) {
      int start = (i - chunkSize) < 0 ? 0 : i - chunkSize;
      parts.insert(0, input.substring(start, i)); // insert at start
    }

    return 'Rp' + parts.join('.');
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard', style: TextStyle(fontSize: 36))),
      body: Center(
        child: Column(
          children: [
            SizedBox(height: 50),
            Container(
              width: screenWidth * 0.8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [Text('Balance', style: TextStyle(fontSize: 24))],
              ),
            ),
            Container(
              width: screenWidth * 0.8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    balanceToCurrency(balance),
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(child: Container()),
            Container(
              width: MediaQuery.of(context).size.width * 0.8,
              child: loading
                  ? CircularProgressIndicator()
                  : (currentPaymentQR.isNotEmpty
                        ? Column(
                            children: [
                              Image.network(currentPaymentQR),
                              SizedBox(height: 10),
                              ElevatedButton(
                                child: Text('Check'),
                                onPressed: () {
                                  checkPayment();
                                },
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              TextFormField(
                                controller: amountController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Request amount',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              SizedBox(height: 10),
                              ElevatedButton(
                                child: Text('Receive via QRIS'),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: () {
                                  setPayment(int.parse(amountController.text));
                                },
                              ),
                            ],
                          )),
            ),
            Expanded(child: Container()),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => QRScannerPage()),
                ).then((result) {
                  if (result != null) {
                    setState(() {
                      print('Received: $result');
                      balance -= int.parse(result.toString());
                    });
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(200, 70),
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Send via QRIS',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.normal),
              ),
            ),
            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
