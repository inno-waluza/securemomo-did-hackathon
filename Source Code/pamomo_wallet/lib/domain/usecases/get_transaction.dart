// lib/domain/usecases/get_transactions.dart
import '../entities/transaction.dart';
import '../repositories/transaction_repository.dart';

class GetTransactions {
  final TransactionRepository repository;

  GetTransactions(this.repository);

  Future<List<Transaction>> call() async {
    return await repository.getTransactions();
  }
}