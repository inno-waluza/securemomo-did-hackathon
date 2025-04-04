import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';

class TransactionHistoryPage extends StatefulWidget {
  final String email;

  const TransactionHistoryPage({Key? key, required this.email}) : super(key: key);

  @override
  _TransactionHistoryPageState createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  late Future<List<dynamic>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = fetchTransactionHistory();
  }

  Future<List<dynamic>> fetchTransactionHistory() async {
    final url = '${ApiConstants.trsfHistoryUrl}?email=${widget.email}';
    try {
      final response = await Dio().get(url);
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      } else {
        throw Exception('Failed to load transactions');
      }
    } catch (e) {
      throw Exception('Failed to load transactions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final transactions = snapshot.data!;
            if (transactions.isEmpty) {
              return const Center(child: Text('No transactions found'));
            }
            return ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    title: Text('Transaction ID: ${transaction['trans_id']}'),
                    subtitle: Text(
                      'From: ${transaction['sender']}\nTo: ${transaction['receiver']}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Amount: ${transaction['amount']}'),
                        Text('Fee: ${transaction['transaction_fee']}'),
                      ],
                    ),
                  ),
                );
              },
            );
          } else {
            return const Center(child: Text('No data'));
          }
        },
      ),
    );
  }
}
