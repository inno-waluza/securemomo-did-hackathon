// lib/presentation/bloc/transaction_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:pamomo_wallet/presentation/bloc/transaction_event.dart';
import 'package:pamomo_wallet/presentation/bloc/transaction_state.dart';
import '../../domain/usecases/get_transaction.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final GetTransactions getTransactions;

  TransactionBloc(this.getTransactions) : super(TransactionInitial()) {
    on<LoadTransactions>(_onLoadTransactions);
  }

  Future<void> _onLoadTransactions(
      LoadTransactions event,
      Emitter<TransactionState> emit,
      ) async {
    emit(TransactionLoading());
    try {
      final transactions = await getTransactions();
      emit(TransactionLoaded(transactions));
    } catch (e) {
      emit(TransactionError(e.toString()));
    }
  }
}