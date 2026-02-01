import 'package:equatable/equatable.dart';

class Transaction extends Equatable {
  final String id; // Unique ID for editing
  final DateTime date;
  final String description;
  final String category; // "Rubro"
  final double amount; // Display amount (could be USD or UYU depending on context)
  final String currency; // "UYU" or "USD"
  final String sourceAccount; // "Santander Caja Ahorro", "Visa Platinum", etc.
  final String accountNumber;
  final double balance; // Calculated running balance
  
  // New fields for improved multi-currency handling
  final double originalAmount;
  final double amountUYU;
  final double amountUSD;

  Transaction({
    String? id,
    required this.date,
    required this.description,
    required this.category,
    required this.amount,
    required this.currency,
    required this.sourceAccount,
    required this.accountNumber,
    required this.balance, // Keep required, but might default to 0 if not calculated immediately
    this.originalAmount = 0.0,
    this.amountUYU = 0.0,
    this.amountUSD = 0.0,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

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
    double? originalAmount,
    double? amountUYU,
    double? amountUSD,
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
      originalAmount: originalAmount ?? this.originalAmount,
      amountUYU: amountUYU ?? this.amountUYU,
      amountUSD: amountUSD ?? this.amountUSD,
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
      'originalAmount': originalAmount,
      'amountUYU': amountUYU,
      'amountUSD': amountUSD,
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
      balance: json['balance']?.toDouble() ?? 0.0,
      originalAmount: json['originalAmount']?.toDouble() ?? 0.0,
      amountUYU: json['amountUYU']?.toDouble() ?? 0.0,
      amountUSD: json['amountUSD']?.toDouble() ?? 0.0,
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
    originalAmount,
    amountUYU,
    amountUSD,
  ];
}
