import 'package:equatable/equatable.dart';

enum TransactionType { income, expense, transfer }

class Transaction extends Equatable {
  final String id;
  final String accountId;
  final String? categoryId; // Puede ser nulo si es una transferencia o aún no clasificado
  final double amount;
  final DateTime date;
  final String description;
  final TransactionType type;
  final bool isPending; // Para movimientos agendados o no confirmados
  
  // Para transferencias
  final String? toAccountId;

  const Transaction({
    required this.id,
    required this.accountId,
    this.categoryId,
    required this.amount,
    required this.date,
    required this.description,
    required this.type,
    this.isPending = false,
    this.toAccountId,
  });

  @override
  List<Object?> get props => [
        id,
        accountId,
        categoryId,
        amount,
        date,
        description,
        type,
        isPending,
        toAccountId
      ];

  factory Transaction.fromMap(Map<String, dynamic> map, String id) {
    return Transaction(
      id: id,
      accountId: map['accountId'] ?? '',
      categoryId: map['categoryId'],
      amount: (map['amount'] ?? 0).toDouble(),
      date: map['date'] != null 
          ? DateTime.parse(map['date']) 
          : DateTime.now(), // Asumiendo formato ISO8601 o Timestamp convertido antes
      description: map['description'] ?? '',
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      isPending: map['isPending'] ?? false,
      toAccountId: map['toAccountId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'categoryId': categoryId,
      'amount': amount,
      'date': date.toIso8601String(),
      'description': description,
      'type': type.name,
      'isPending': isPending,
      'toAccountId': toAccountId,
    };
  }
}
