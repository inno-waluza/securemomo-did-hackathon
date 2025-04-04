import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pamomo_wallet/presentation/pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerifyTransactionPage extends StatefulWidget {
  final String txRef;
  const VerifyTransactionPage({Key? key, required this.txRef}) : super(key: key);

  @override
  _VerifyTransactionPageState createState() => _VerifyTransactionPageState();
}

class _VerifyTransactionPageState extends State<VerifyTransactionPage> {
  String _statusMessage = "Verifying Payment...";
  bool _isLoading = true;
  double? _transactionAmount;

  @override
  void initState() {
    super.initState();
    _verifyPayment();
  }

  Future<void> _verifyPayment() async {
    final prefs = await SharedPreferences.getInstance();
    final String email = prefs.getString('recipientEmail') ?? "";
    final String? depositAmountStr = prefs.getString('depositAmount');

    if (email.isEmpty || depositAmountStr == null) {
      setState(() {
        _statusMessage = "Missing payment information.";
        _isLoading = false;
      });
      return;
    }

    try {
      // First verify with payment gateway
      final dio = Dio();
      final response = await dio.get(
        'https://api.paychangu.com/verify-payment/${widget.txRef}',
        options: Options(
          headers: {
            "accept": "application/json",
            "Authorization": "Bearer SEC-TEST-nqbbmKfBLjAN7F4XExoJqpJ0ut1rBV5T",
          },
        ),
      );

      final result = response.data;
      if (result["status"] == "success" && result["data"]["status"] == "success") {
        final double amountPaid = double.parse(result["data"]["amount"].toString());
        final double deductedAmount = amountPaid * 0.97;

        setState(() {
          _transactionAmount = deductedAmount;
          _statusMessage = "Payment Verified. Processing deposit...";
        });

        // Send to your local Django server
        await _sendPaymentDetails(email, deductedAmount);

        // Clear saved data
        await prefs.remove('recipientEmail');
        await prefs.remove('depositAmount');

        setState(() {
          _statusMessage = "Deposit Successful!";
          _isLoading = false;
        });

      } else {
        setState(() {
          _statusMessage = "Payment verification failed.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error verifying payment. Please try again.";
        _isLoading = false;
      });
      debugPrint("Error during payment verification: $e");
    }
  }

  Future<void> _sendPaymentDetails(String email, double amount) async {
    try {
      // Adjust this URL to your local Django server
      final response = await Dio().post(
        'http://10.0.2.2:8000/api/v1/dpst/', // For Android emulator
        // 'http://localhost:8000/api/v1/dpst/', // For iOS simulator or physical device
        data: {
          "email": email,
          "amount": amount.toStringAsFixed(2),
          "tx_ref": widget.txRef,
        },
        options: Options(headers: {"Content-Type": "application/json"}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("Payment processed successfully");
      } else {
        debugPrint("Deposit failed with status: ${response.statusCode}");
        throw Exception("Deposit failed");
      }
    } catch (e) {
      debugPrint("Error sending payment details: $e");
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Verification")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
              ],
              Text(
                _statusMessage,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              if (_transactionAmount != null) ...[
                const SizedBox(height: 20),
                Text(
                  "Amount: MWK ${_transactionAmount!.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (!_isLoading) ...[
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => HomePage()),
                          (route) => false,
                    );
                  },
                  child: const Text("Back to Home"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}