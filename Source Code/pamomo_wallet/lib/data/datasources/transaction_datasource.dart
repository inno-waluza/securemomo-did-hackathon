// lib/data/datasources/transaction_data_source.dart
import '../models/transaction_model.dart';

abstract class TransactionDataSource {
  Future<List<TransactionModel>> getTransactions();
  Future<void> sendMoney(double amount);
}