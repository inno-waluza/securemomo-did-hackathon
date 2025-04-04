import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'verify_transaction_page.dart';

class DepositMoneyPage extends StatefulWidget {
  const DepositMoneyPage({Key? key}) : super(key: key);

  @override
  _DepositMoneyPageState createState() => _DepositMoneyPageState();
}

class _DepositMoneyPageState extends State<DepositMoneyPage> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  String _error = "";
  String _success = "";
  String? checkoutUrl;
  late final WebViewController _webViewController;

  @override
  void initState() {
    super.initState();

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.contains('payment-success')) {
              final uri = Uri.parse(request.url);
              final txRef = uri.queryParameters['tx_ref'] ?? '';
              if (txRef.isNotEmpty) {
                _handlePaymentSuccess(txRef);
              }
              return NavigationDecision.prevent;
            } else if (request.url.contains('payment-cancelled')) {
              setState(() {
                checkoutUrl = null;
                _error = "Payment was cancelled";
              });
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
  }

  Future<void> _handlePaymentSuccess(String txRef) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('recipientEmail') ?? '';

    if (email.isEmpty) {
      setState(() {
        checkoutUrl = null;
        _error = "User information missing";
      });
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => VerifyTransactionPage(txRef: txRef),
      ),
    );
  }

  Future<void> _handleDeposit() async {
    setState(() {
      _isLoading = true;
      _error = "";
      _success = "";
    });

    final String recipient = _recipientController.text.trim();
    final String amountStr = _amountController.text.trim();

    if (recipient.isEmpty || amountStr.isEmpty) {
      setState(() {
        _error = "Please fill in all fields";
        _isLoading = false;
      });
      return;
    }

    final double? amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      setState(() {
        _error = "Please enter a valid amount";
        _isLoading = false;
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('recipientEmail', recipient);
      await prefs.setString('depositAmount', amount.toString());

      final txRef = 'tx_${DateTime.now().millisecondsSinceEpoch}';

      final Dio dio = Dio();
      final response = await dio.post(
        'https://api.paychangu.com/payment',
        data: {
          "currency": "MWK",
          "amount": amount.toString(),
          "callback_url": "https://pamomo.local/payment-success?tx_ref=$txRef",
          "return_url": "https://pamomo.local/payment-cancelled",
        },
        options: Options(
          headers: {
            "accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": "Bearer SEC-TEST-nqbbmKfBLjAN7F4XExoJqpJ0ut1rBV5T",
          },
        ),
      );

      final result = response.data;
      if (result["status"] == "success" && result["data"]?["checkout_url"] != null) {
        final String url = result["data"]["checkout_url"].toString();
        setState(() {
          checkoutUrl = url;
        });
        _webViewController.loadRequest(Uri.parse(url));
      } else {
        setState(() {
          _error = "Transaction initiation failed. Please try again.";
        });
      }
    } catch (err) {
      setState(() {
        _error = "An error occurred. Please try again.";
      });
      debugPrint("Error initiating payment: $err");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (checkoutUrl != null) {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            // Wave header for payment page
            ClipPath(
              clipper: WaveClipper(),
              child: Container(
                height: 200,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 60,
                      left: 20,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            checkoutUrl = null;
                          });
                        },
                      ),
                    ),
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Text(
                          'Complete Payment',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: WebViewWidget(
                controller: _webViewController,
                gestureRecognizers: {
                  Factory<VerticalDragGestureRecognizer>(
                        () => VerticalDragGestureRecognizer(),
                  ),
                  Factory<HorizontalDragGestureRecognizer>(
                        () => HorizontalDragGestureRecognizer(),
                  ),
                },
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background wave
          ClipPath(
            clipper: WaveClipper(),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.25,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.purple.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App bar with transparent background
                  AppBar(
                    title: const Text(
                      'Deposit Money',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: Colors.white),
                  ),

                  const SizedBox(height: 40),

                  // Form container
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _recipientController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: "Recipient's Email",
                            labelStyle: TextStyle(color: Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.blue),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),

                        const SizedBox(height: 20),

                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: "Amount (MWK)",
                            labelStyle: TextStyle(color: Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.blue),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            prefixText: "MWK ",
                            prefixStyle: const TextStyle(color: Colors.black),
                          ),
                        ),

                        const SizedBox(height: 20),

                        if (_error.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error,
                                    style: TextStyle(color: Colors.red[800]),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (_success.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.green),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _success,
                                    style: TextStyle(color: Colors.green[800]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Deposit button with gradient
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [Colors.blue, Colors.purple],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleDeposit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        'DEPOSIT MONEY',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reusing the same WaveClipper from SendMoneyPage for consistency
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.8);

    final firstControlPoint = Offset(size.width * 0.25, size.height);
    final firstEndPoint = Offset(size.width * 0.5, size.height * 0.8);
    path.quadraticBezierTo(
      firstControlPoint.dx, firstControlPoint.dy,
      firstEndPoint.dx, firstEndPoint.dy,
    );

    final secondControlPoint = Offset(size.width * 0.75, size.height * 0.6);
    final secondEndPoint = Offset(size.width, size.height * 0.9);
    path.quadraticBezierTo(
      secondControlPoint.dx, secondControlPoint.dy,
      secondEndPoint.dx, secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}