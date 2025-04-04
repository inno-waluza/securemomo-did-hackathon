// lib/data/models/transaction_model.dart
import '../../domain/entities/transaction.dart';

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final DateTime date;

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      title: json['title'],
      amount: json['amount'],
      date: DateTime.parse(json['date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  Transaction toEntity() {
    return Transaction(
      id: id,
      title: title,
      amount: amount,
      date: date,
    );
  }
}