// lib/injection_container.dart
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:pamomo_wallet/presentation/bloc/transaction_bloc.dart';
import 'data/datasources/transaction_datasource.dart';
import 'data/datasources/transaction_datasource_impl.dart';
import 'data/repositories/transaction_repository_impl.dart';
import 'domain/repositories/transaction_repository.dart';
import 'domain/usecases/get_transaction.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // External
  sl.registerLazySingleton(() => Dio());

  // Data Sources
  sl.registerLazySingleton<TransactionDataSource>(
        () => TransactionDataSourceImpl(dio: sl()),
  );

  // Repositories
  sl.registerLazySingleton<TransactionRepository>(
        () => TransactionRepositoryImpl(sl()),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetTransactions(sl()));

  // BLoC
  sl.registerFactory(() => TransactionBloc(sl()));
}
