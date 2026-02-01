import 'package:equatable/equatable.dart';

enum AccountType { bank, cash, wallet, investment, creditCard }

class Account extends Equatable {
  final String id;
  final String name;
  final AccountType type;
  final String currency; // 'USD', 'EUR', 'ARS', etc.
  final double initialBalance;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    this.initialBalance = 0.0,
  });

  @override
  List<Object?> get props => [id, name, type, currency, initialBalance];

  factory Account.fromMap(Map<String, dynamic> map, String id) {
    return Account(
      id: id,
      name: map['name'] ?? 'Nueva Cuenta',
      type: AccountType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AccountType.bank,
      ),
      currency: map['currency'] ?? 'USD',
      initialBalance: (map['initialBalance'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.name,
      'currency': currency,
      'initialBalance': initialBalance,
    };
  }
}
