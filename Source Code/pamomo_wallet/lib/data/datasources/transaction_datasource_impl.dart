// lib/data/datasources/transaction_data_source_impl.dart
import 'package:dio/dio.dart'; // For API calls
import 'package:pamomo_wallet/data/datasources/transaction_datasource.dart';
import '../../domain/entities/transaction.dart';
import '../models/transaction_model.dart';

class TransactionDataSourceImpl implements TransactionDataSource {
  final Dio dio;

  TransactionDataSourceImpl({required this.dio});

  @override
  Future<List<TransactionModel>> getTransactions() async {
    // Simulate an API call to fetch transactions
    final response = await dio.get('https://api.example.com/transactions');

    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => TransactionModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load transactions');
    }
  }

  @override
  Future<void> sendMoney(double amount) async {
    // Simulate an API call to send money
    final response = await dio.post(
      'https://api.example.com/send-money',
      data: {'amount': amount},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send money');
    }
  }
}