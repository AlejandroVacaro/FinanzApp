import 'package:equatable/equatable.dart';

class Transaction extends Equatable {
  final String id; // Unique ID for editing
  final DateTime date;
  final String description;
  final String category; // "Rubro"
  final double amount; // Negative for expense, Positive for income
  final String currency; // "UYU" or "USD"
  final String sourceAccount; // "Santander Caja Ahorro", "Visa Platinum", etc.
  final String accountNumber;
  final double balance; // Calculated running balance

  Transaction({ // Removed const to allow uuid generation if needed, or keep const and require ID
    String? id,
    required this.date,
    required this.description,
    required this.category,
    required this.amount,
    required this.currency,
    required this.sourceAccount,
    required this.accountNumber,
    required this.balance,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(); // Simple ID generation for now to avoid UUID dep issues if not installed yet. Or user approved UUID? 
  // I requested UUID but it is waiting. 
  // I will use a timestamp/random string for now to avoid blocking.

  Transaction copyWith({
    String? id,
    DateTime? date,
    String? description,
    String? category,
    double? amount,
    String? currency,
    String? sourceAccount,
    String? accountNumber,
    double? balance,
  }) {
    return Transaction(
      id: id ?? this.id,
      date: date ?? this.date,
      description: description ?? this.description,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      sourceAccount: sourceAccount ?? this.sourceAccount,
      accountNumber: accountNumber ?? this.accountNumber,
      balance: balance ?? this.balance,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'description': description,
      'category': category,
      'amount': amount,
      'currency': currency,
      'sourceAccount': sourceAccount,
      'accountNumber': accountNumber,
      'balance': balance,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      date: DateTime.parse(json['date']),
      description: json['description'],
      category: json['category'],
      amount: json['amount'].toDouble(),
      currency: json['currency'],
      sourceAccount: json['sourceAccount'],
      accountNumber: json['accountNumber'],
      balance: json['balance'].toDouble(),
    );
  }

  @override
      List<Object?> get props => [
        id,
        date,
        description,
        category,
        amount,
        currency,
        sourceAccount,
        accountNumber,
        balance,
      ];
}
