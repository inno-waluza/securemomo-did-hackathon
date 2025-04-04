// lib/data/repositories/transaction_repository_impl.dart
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_datasource.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionDataSource dataSource;

  TransactionRepositoryImpl(this.dataSource);

  @override
  Future<List<Transaction>> getTransactions() async {
    final transactions = await dataSource.getTransactions();
    return transactions.map((model) => model.toEntity()).toList();
  }

  @override
  Future<void> sendMoney(double amount) async {
    await dataSource.sendMoney(amount);
  }
}